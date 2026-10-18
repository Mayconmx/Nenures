import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../src/rust/api/error.dart';
import '../src/rust/api/invite.dart';
import '../src/rust/api/session.dart';
import 'invite.dart';
import 'transport.dart';

/// Transporte real: WebSocket com o servidor (docs/protocolo.md) e MLS na
/// biblioteca nenures_core (Rust). Segredos e estado do grupo ficam no Rust;
/// aqui só passam bytes cifrados e texto já decifrado.
///
/// Regras:
/// - mensagens do servidor são processadas uma por vez, na ordem de chegada;
/// - o membro designado (menor folha online) aceita entradas, confirma saídas
///   e remove quem caiu; os outros só processam os commits;
/// - um commit próprio pendente por vez; se outro vencer a época, o próprio é
///   descartado e o trabalho é tentado de novo.
class RealTransport implements ConversationTransport {
  RealTransport(
    this.server, {
    this.resumeWindow = const Duration(seconds: 60),
    this.retryEvery = const Duration(seconds: 2),
    this.replyTimeout = const Duration(seconds: 40),
  }) {
    final local =
        server.host == 'localhost' ||
        server.host == '10.0.2.2' ||
        (InternetAddress.tryParse(server.host)?.isLoopback ?? false);
    if (server.scheme != 'wss' && !(server.scheme == 'ws' && local)) {
      throw ArgumentError('o servidor precisa usar wss:// (ws:// só local)');
    }
  }

  final Uri server;
  final Duration resumeWindow;
  final Duration retryEvery;
  final Duration replyTimeout;

  final _events = StreamController<TransportEvent>.broadcast();

  Session? _session;
  WebSocket? _ws;
  StreamSubscription<dynamic>? _sub;
  Future<void> _queue = Future.value();

  Uint8List? _room;
  int? _member;
  String? _token;
  int _lastSeq = 0;
  int _members = 0;
  bool _closing = false;

  _Waiter? _waiter;
  _OwnCommit? _pending;
  final _offline = <int>{};
  final _gone = <int>{};
  final _joinRequests = <int, Uint8List>{};

  @override
  Stream<TransportEvent> get events => _events.stream;

  // ------------------------------------------------------------- operações

  @override
  Future<Invite> createRoom() async {
    _reset();
    final List<String> words;
    final Session s;
    try {
      words = await generateInviteWords();
      s = await Session.create(words: words);
    } on CoreError {
      throw const TransportException(TransportFailure.unavailable);
    }
    _session = s;
    _room = s.roomId();
    await _connect();
    final reply = await _request(
      {'t': 'create', 'room': base64Encode(_room!)},
      const {'created'},
    );
    _checkError(reply);
    _member = reply['member'] as int;
    _token = reply['token'] as String;
    _members = 1;
    _send({'t': 'leaf', 'leaf': s.view().ownLeaf});
    return Invite(words);
  }

  @override
  Future<int> joinRoom(Invite invite) async {
    _reset();
    try {
      checkInviteWords(words: invite.words);
    } on CoreError {
      throw const JoinException(JoinFailure.invalidWords);
    }
    final Session s;
    final Uint8List req;
    try {
      s = await Session.prepareJoin(words: invite.words);
      req = await s.joinRequest();
    } on CoreError {
      throw const TransportException(TransportFailure.unavailable);
    }
    _session = s;
    _room = s.roomId();
    await _connect();
    final reply = await _request(
      {'t': 'join', 'room': base64Encode(_room!), 'req': base64Encode(req)},
      const {'welcome'},
    );
    if (reply['t'] == 'error') {
      await _shutdown();
      throw JoinException(switch (reply['code']) {
        'not_found' => JoinFailure.notFound,
        'locked' => JoinFailure.locked,
        'full' => JoinFailure.full,
        'timeout' => JoinFailure.noAnswer,
        _ => JoinFailure.tryLater,
      });
    }
    final GroupView view;
    try {
      view = await s.acceptWelcome(
        welcome: base64Decode(reply['data'] as String),
      );
    } on CoreError {
      await _shutdown();
      throw const TransportException(TransportFailure.network);
    }
    _member = reply['member'] as int;
    _token = reply['token'] as String;
    _members = view.members;
    _send({'t': 'leaf', 'leaf': view.ownLeaf});
    return view.members;
  }

  @override
  Future<void> send(String text) async {
    final s = _session;
    if (s == null || _ws == null) {
      throw const TransportException(TransportFailure.network);
    }
    final Uint8List ct;
    try {
      ct = await s.encryptText(text: text);
    } on CoreError {
      throw const TransportException(TransportFailure.network);
    }
    _send({'t': 'msg', 'data': base64Encode(ct)});
  }

  @override
  Future<void> leave() async {
    if (_closing) return;
    _closing = true;
    final s = _session;
    try {
      if (s != null && s.view().active && _ws != null) {
        // Saída autenticada pelo MLS; quem for designado faz o commit (P6).
        final p = await s.leave();
        _send({'t': 'proposal', 'data': base64Encode(p)});
      }
      _send({'t': 'leave'});
    } on Object {
      // Sair é melhor esforço: o servidor remove a conexão de qualquer forma.
    }
    await _shutdown();
  }

  // ------------------------------------------------------------- conexão

  Future<void> _connect() async {
    try {
      final ws = await WebSocket.connect(server.toString())
          .timeout(const Duration(seconds: 10));
      ws.pingInterval = const Duration(seconds: 20);
      _ws = ws;
      _sub = ws.listen(
        _onFrame,
        onDone: () => _onClosed(ws),
        onError: (Object _) => _onClosed(ws),
        cancelOnError: true,
      );
    } on Object {
      throw const TransportException(TransportFailure.network);
    }
  }

  void _send(Map<String, Object?> m) {
    final ws = _ws;
    if (ws == null) {
      throw const TransportException(TransportFailure.network);
    }
    ws.add(jsonEncode(m));
  }

  Future<Map<String, Object?>> _request(
    Map<String, Object?> m,
    Set<String> expected,
  ) async {
    final w = _Waiter(expected);
    _waiter = w;
    _send(m);
    try {
      return await w.completer.future.timeout(replyTimeout);
    } on TimeoutException {
      await _shutdown();
      throw const TransportException(TransportFailure.network);
    } finally {
      if (identical(_waiter, w)) _waiter = null;
    }
  }

  void _checkError(Map<String, Object?> reply) {
    if (reply['t'] == 'error') {
      unawaited(_shutdown());
      throw TransportException(
        reply['code'] == 'rate_limited' || reply['code'] == 'busy'
            ? TransportFailure.unavailable
            : TransportFailure.network,
      );
    }
  }

  void _onFrame(dynamic data) {
    if (data is! String) return;
    final Map<String, Object?> m;
    try {
      m = (jsonDecode(data) as Map).cast<String, Object?>();
    } on Object {
      return;
    }
    final seq = m['seq'];
    if (seq is int && seq > _lastSeq) _lastSeq = seq;

    final w = _waiter;
    if (w != null && (w.expected.contains(m['t']) || m['t'] == 'error')) {
      _waiter = null;
      w.completer.complete(m);
      return;
    }
    // Processamento estritamente em ordem.
    _queue = _queue.then((_) => _handle(m)).catchError((Object _) {});
  }

  void _onClosed(WebSocket ws) {
    if (!identical(ws, _ws)) return;
    _ws = null;
    unawaited(_sub?.cancel());
    _sub = null;
    final w = _waiter;
    if (w != null) {
      _waiter = null;
      w.completer.complete({'t': 'error', 'code': 'closed'});
    }
    if (_closing || _member == null) return;
    unawaited(_reconnect());
  }

  /// D9: tenta retomar por até [resumeWindow]; se não der, a sessão acabou.
  Future<void> _reconnect() async {
    _events.add(const ConnectionInterrupted());
    final deadline = DateTime.now().add(resumeWindow);
    while (!_closing && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(retryEvery);
      if (_closing) return;
      try {
        await _connect();
        final reply = await _request(
          {
            't': 'resume',
            'room': base64Encode(_room!),
            'member': _member,
            'token': _token,
            'last': _lastSeq,
          },
          const {'resumed'},
        );
        if (reply['t'] == 'resumed') {
          _events.add(const ConnectionRestored());
          return;
        }
        if (reply['code'] == 'bad_token') break;
      } on TransportException {
        // Tenta de novo até o prazo.
      }
    }
    if (_closing) return;
    _events.add(const SessionLost());
    await _shutdown();
  }

  // ------------------------------------------------------------- protocolo

  Future<void> _handle(Map<String, Object?> m) async {
    final s = _session;
    if (s == null || _closing) return;
    switch (m['t']) {
      case 'join_request':
        _joinRequests[m['from'] as int] = base64Decode(m['req'] as String);
      case 'commit':
        await _onOtherCommit(s, base64Decode(m['data'] as String));
      case 'commit_ok':
        await _onCommitOk(s);
      case 'commit_rejected':
        await _onCommitRejected(s);
      case 'proposal':
        await _process(s, base64Decode(m['data'] as String));
      case 'msg':
        await _process(s, base64Decode(m['data'] as String));
      case 'away':
        _offline.add(m['leaf'] as int);
      case 'back':
        _offline.remove(m['leaf'] as int);
      case 'gone':
        final leaf = m['leaf'] as int;
        _offline.remove(leaf);
        _gone.add(leaf);
      case 'expired':
        _events.add(const RoomExpired());
        await _shutdown();
        return;
      case 'error':
        // Commit com Welcome para quem já desistiu: o servidor não aceitou.
        if (_pending != null && m['code'] == 'not_found') {
          final joinFrom = _pending!.joinFrom;
          if (joinFrom != null) _joinRequests.remove(joinFrom);
          await _discardPending(s);
        }
    }
    await _work(s);
  }

  Future<void> _process(Session s, Uint8List data) async {
    final Incoming inc;
    try {
      inc = await s.process(message: data);
    } on CoreError {
      return; // adulterada, repetida ou de outra época: descartada (T4, T5)
    }
    switch (inc.kind) {
      case IncomingKind.text:
        _events.add(MessageReceived(inc.text!));
      case IncomingKind.lock:
        break; // "Trancar entrada" na interface: Fase 6 (D7)
      case IncomingKind.proposal:
        break; // o commit sai em _work, se este aparelho for o designado
      case IncomingKind.commit:
        _presence(inc.view);
      case IncomingKind.removedSelf:
        _events.add(const SessionLost());
        await _shutdown();
    }
  }

  Future<void> _onOtherCommit(Session s, Uint8List data) async {
    if (_pending != null) {
      // Chegou o commit de outra pessoa nesta época: o nosso perdeu.
      await _discardPending(s);
    }
    await _process(s, data);
  }

  Future<void> _onCommitOk(Session s) async {
    final p = _pending;
    if (p == null) return;
    _pending = null;
    final GroupView view;
    try {
      view = await s.confirmOwnCommit();
    } on CoreError {
      _events.add(const SessionLost());
      await _shutdown();
      return;
    }
    if (p.joinFrom != null) _joinRequests.remove(p.joinFrom);
    if (p.removedLeaf != null) _gone.remove(p.removedLeaf);
    _presence(view);
  }

  Future<void> _onCommitRejected(Session s) async {
    if (_pending != null) await _discardPending(s);
  }

  Future<void> _discardPending(Session s) async {
    _pending = null;
    try {
      await s.discardOwnCommit();
    } on CoreError {
      // Nada pendente na biblioteca: já descartado.
    }
  }

  bool _designated(GroupView v) {
    final online = [
      for (final l in v.leaves)
        if (!_offline.contains(l) && !_gone.contains(l)) l,
    ];
    if (online.isEmpty) return false;
    online.sort();
    return online.first == v.ownLeaf;
  }

  /// Trabalho do membro designado: remover quem saiu, confirmar saídas,
  /// aceitar entradas. Um commit por vez.
  Future<void> _work(Session s) async {
    if (_pending != null || _closing || _ws == null) return;
    final v = s.view();
    if (!v.active || !_designated(v)) return;
    final epoch = v.epoch.toInt();

    // 1. Quem não voltou a tempo (o servidor avisou `gone`).
    for (final leaf in _gone.toList()) {
      if (!v.leaves.contains(leaf)) {
        _gone.remove(leaf);
        continue;
      }
      try {
        final c = await s.removeLeaf(leaf: leaf);
        _pending = _OwnCommit(removedLeaf: leaf);
        _send({'t': 'commit', 'epoch': epoch, 'data': base64Encode(c)});
      } on CoreError {
        _gone.remove(leaf);
      }
      return;
    }

    // 2. Saídas por Encerrar (propostas guardadas).
    try {
      final c = await s.commitPending();
      if (c != null) {
        _pending = const _OwnCommit();
        _send({'t': 'commit', 'epoch': epoch, 'data': base64Encode(c)});
        return;
      }
    } on CoreError {
      return;
    }

    // 3. Pedidos de entrada.
    for (final entry in _joinRequests.entries.toList()) {
      try {
        final add = await s.handleJoinRequest(request: entry.value);
        _pending = _OwnCommit(joinFrom: entry.key);
        _send({
          't': 'commit',
          'epoch': epoch,
          'data': base64Encode(add.commit),
          'welcome': base64Encode(add.welcome),
          'to': entry.key,
        });
        return;
      } on CoreError {
        // Sem o convite, adulterado ou repetido: ignora o pedido (T1, T6).
        _joinRequests.remove(entry.key);
      }
    }
  }

  void _presence(GroupView v) {
    final n = v.members;
    if (n == _members) return;
    final change = n > _members ? PresenceChange.joined : PresenceChange.left;
    _members = n;
    _events.add(PresenceChanged(n, change));
  }

  // ------------------------------------------------------------- encerramento

  void _reset() {
    _closing = false;
    _session = null;
    _room = null;
    _member = null;
    _token = null;
    _lastSeq = 0;
    _members = 0;
    _pending = null;
    _waiter = null;
    _offline.clear();
    _gone.clear();
    _joinRequests.clear();
    _queue = Future.value();
  }

  Future<void> _shutdown() async {
    _closing = true;
    final ws = _ws;
    _ws = null;
    await _sub?.cancel();
    _sub = null;
    if (ws != null) await ws.close(WebSocketStatus.normalClosure);
    final s = _session;
    _session = null;
    if (s != null) {
      try {
        await s.close();
      } on Object {
        // já fechada
      }
      s.dispose();
    }
    _joinRequests.clear();
  }
}

class _Waiter {
  _Waiter(this.expected);
  final Set<String> expected;
  final completer = Completer<Map<String, Object?>>();
}

class _OwnCommit {
  const _OwnCommit({this.joinFrom, this.removedLeaf});
  final int? joinFrom;
  final int? removedLeaf;
}
