import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'conversation_state.dart';
import 'invite.dart';
import 'transport.dart';

/// Transporte usado pelo app. No build de hoje é [UnavailableTransport];
/// os testes substituem por um transporte falso.
final transportProvider = Provider<ConversationTransport>(
  (ref) => UnavailableTransport(),
);

final conversationProvider =
    NotifierProvider<ConversationController, ConversationState>(
      ConversationController.new,
    );

/// Motivos pelos quais a entrada com chave não aconteceu.
enum JoinError {
  empty,
  wrongWordCount,
  invalidCharacters,
  notFound,
  full,
  locked,
  unavailable,
  network,
}

/// Textos dos avisos de sistema no chat.
abstract final class SystemText {
  static const created =
      'Conversa aberta. Esperando alguém entrar com a chave.';
  static const youJoined = 'Você entrou na conversa.';
  static const interrupted = 'Conexão perdida. Tentando reconectar…';
  static const restored = 'Conexão restabelecida.';
  static const sendFailed = 'Não foi possível enviar a última mensagem.';
  static String joined(int n) => 'Alguém entrou · $n pessoas';
  static String left(int n) => n == 1
      ? 'A outra pessoa saiu. Só você está aqui.'
      : 'Alguém saiu · $n pessoas';
}

class ConversationController extends Notifier<ConversationState> {
  StreamSubscription<TransportEvent>? _sub;
  Timer? _expiryTimer;
  Timer? _backgroundTimer;
  int _nextId = 0;

  ConversationTransport get _transport => ref.read(transportProvider);

  @override
  ConversationState build() {
    ref.onDispose(_cancelAll);
    return const Idle();
  }

  // ---------------------------------------------------------------- criar

  Future<void> createRoom() async {
    if (state is! Idle) return;
    state = const CreatingRoom();
    try {
      final invite = await _transport.createRoom();
      _listen();
      _expiryTimer = Timer(NenuresLimits.keyLifetime, _onLocalExpiry);
      state = InConversation(
        invite: invite,
        phase: ConversationPhase.waiting,
        participants: 1,
        items: [_system(SystemText.created)],
        isCreator: true,
        expiresAt: clock.now().add(NenuresLimits.keyLifetime),
        showingKey: true,
      );
    } on TransportException catch (e) {
      state = Failed(_failureKind(e.failure));
    }
  }

  /// Cancelar na tela "Sua chave" antes de abrir a conversa: volta ao início.
  Future<void> cancelKey() async {
    final s = state;
    if (s is! InConversation || s.phase != ConversationPhase.waiting) return;
    await _shutdown();
    state = const Idle();
  }

  void openChat() => _update((s) => s.copyWith(showingKey: false));
  void showKey() => _update((s) => s.copyWith(showingKey: true));

  // ---------------------------------------------------------------- entrar

  /// Retorna null se entrou; senão, o motivo.
  Future<JoinError?> join(String rawWords) async {
    if (state is! Idle) return null;
    final words = normalizeInviteWords(rawWords);
    switch (checkInviteFormat(words)) {
      case InviteFormatError.empty:
        return JoinError.empty;
      case InviteFormatError.wrongWordCount:
        return JoinError.wrongWordCount;
      case InviteFormatError.invalidCharacters:
        return JoinError.invalidCharacters;
      case null:
        break;
    }
    final invite = Invite(words);
    state = const Joining();
    try {
      final count = await _transport.joinRoom(invite);
      _listen();
      state = InConversation(
        invite: invite,
        phase: ConversationPhase.connected,
        participants: count,
        items: [_system(SystemText.youJoined)],
        isCreator: false,
      );
      return null;
    } on JoinException catch (e) {
      state = const Idle();
      return switch (e.failure) {
        JoinFailure.notFound => JoinError.notFound,
        JoinFailure.full => JoinError.full,
        JoinFailure.locked => JoinError.locked,
      };
    } on TransportException catch (e) {
      state = const Idle();
      return e.failure == TransportFailure.unavailable
          ? JoinError.unavailable
          : JoinError.network;
    }
  }

  // ---------------------------------------------------------------- conversar

  /// Envia [text]. Retorna false se não foi possível enviar.
  Future<bool> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty ||
        trimmed.characters.length > NenuresLimits.messageMaxChars) {
      return false;
    }
    final s = state;
    if (s is! InConversation || s.phase == ConversationPhase.reconnecting) {
      return false;
    }
    try {
      await _transport.send(trimmed);
    } on TransportException {
      _add(_system(SystemText.sendFailed));
      return false;
    }
    _add(ChatItem(_nextId++, ChatItemKind.mine, trimmed));
    return true;
  }

  /// Encerrar (dois toques na interface).
  Future<void> leave() => _finish(EndReason.left);

  /// Volta ao início a partir de Ended ou Failed.
  void reset() {
    if (state is Ended || state is Failed) state = const Idle();
  }

  // ---------------------------------------------------------------- ciclo de vida

  /// paused / hidden: começa a contar 60 s (P7).
  void onBackground() {
    if (state is! InConversation || _backgroundTimer != null) return;
    _backgroundTimer = Timer(
      NenuresLimits.backgroundLimit,
      () => unawaited(_finish(EndReason.backgrounded)),
    );
  }

  /// resumed antes do limite: cancela o encerramento.
  void onForeground() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  /// detached: tenta sair na hora. O sistema não garante entregar este evento.
  void onDetached() => unawaited(_finish(EndReason.left));

  // ---------------------------------------------------------------- interno

  void _listen() {
    unawaited(_sub?.cancel());
    _sub = _transport.events.listen(_onEvent);
  }

  void _onEvent(TransportEvent e) {
    final s = state;
    if (s is! InConversation) return;
    switch (e) {
      case PresenceChanged(:final count, :final change):
        var next = s.copyWith(participants: count);
        if (s.phase == ConversationPhase.waiting && count > 1) {
          _expiryTimer?.cancel();
          next = next.copyWith(
            phase: ConversationPhase.connected,
            clearExpiry: true,
          );
        }
        final text = change == PresenceChange.joined
            ? SystemText.joined(count)
            : SystemText.left(count);
        state = next.copyWith(items: [...s.items, _system(text)]);
      case MessageReceived(:final text):
        _add(ChatItem(_nextId++, ChatItemKind.theirs, text));
      case ConnectionInterrupted():
        state = s.copyWith(
          phase: ConversationPhase.reconnecting,
          items: [...s.items, _system(SystemText.interrupted)],
        );
      case ConnectionRestored():
        state = s.copyWith(
          phase: s.expiresAt != null
              ? ConversationPhase.waiting
              : ConversationPhase.connected,
          items: [...s.items, _system(SystemText.restored)],
        );
      case SessionLost():
        unawaited(_finish(EndReason.connectionLost));
      case RoomExpired():
        unawaited(_finish(EndReason.expired));
    }
  }

  void _onLocalExpiry() {
    final s = state;
    if (s is InConversation && s.phase != ConversationPhase.connected) {
      if (s.participants <= 1) unawaited(_finish(EndReason.expired));
    }
  }

  Future<void> _finish(EndReason reason) async {
    if (state is! InConversation) return;
    await _shutdown();
    state = Ended(reason);
  }

  /// Sai da sessão e descarta tudo o que é local. As mensagens só existem
  /// dentro do estado; ao trocar o estado, a lista deixa de ser referenciada.
  Future<void> _shutdown() async {
    state = const Ending();
    _cancelTimers();
    try {
      await _transport.leave().timeout(const Duration(seconds: 3));
    } on Object {
      // Sair é melhor esforço: o servidor remove a conexão de qualquer forma.
    }
    // O cancelamento vale na hora; não é preciso esperar o Future.
    unawaited(_sub?.cancel());
    _sub = null;
  }

  void _cancelTimers() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  void _cancelAll() {
    _cancelTimers();
    unawaited(_sub?.cancel());
  }

  void _update(InConversation Function(InConversation) f) {
    final s = state;
    if (s is InConversation) state = f(s);
  }

  void _add(ChatItem item) =>
      _update((s) => s.copyWith(items: [...s.items, item]));

  ChatItem _system(String text) =>
      ChatItem(_nextId++, ChatItemKind.system, text);

  static FailureKind _failureKind(TransportFailure f) => switch (f) {
    TransportFailure.unavailable => FailureKind.unavailable,
    TransportFailure.network => FailureKind.network,
  };
}
