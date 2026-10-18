// Ponta a ponta: servidor Go real + transporte real + biblioteca Rust real.
// Requer: Go no PATH e `cargo build --release` em rust/.
@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/conversation/invite.dart';
import 'package:nenures/conversation/real_transport.dart';
import 'package:nenures/conversation/transport.dart';
import 'package:nenures/src/rust/api/invite.dart';
import 'package:nenures/src/rust/frb_generated.dart';

import '../rust/bridge_test.dart' show hostLibrary;

class TestServer {
  TestServer._(this.port, this._binary);
  final int port;
  final String _binary;
  Process? _proc;

  static Future<TestServer> build() async {
    final out =
        '${Directory.systemTemp.path}/nenures-test-server'
        '${Platform.isWindows ? '.exe' : ''}';
    final r = await Process.run('go', [
      'build',
      '-o',
      out,
      './cmd/nenures-server',
    ], workingDirectory: '../server');
    if (r.exitCode != 0) fail('go build falhou: ${r.stderr}');
    final sock = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = sock.port;
    await sock.close();
    return TestServer._(port, out);
  }

  Uri get uri => Uri.parse('ws://127.0.0.1:$port/v1');

  Future<void> start() async {
    _proc = await Process.start(
      _binary,
      [],
      environment: {'NENURES_ADDR': '127.0.0.1:$port'},
    );
    unawaited(_proc!.stdout.drain<void>());
    unawaited(_proc!.stderr.drain<void>());
    final client = HttpClient();
    for (var i = 0; i < 100; i++) {
      try {
        final req = await client.get('127.0.0.1', port, '/healthz');
        final res = await req.close();
        await res.drain<void>();
        if (res.statusCode == 200) return;
      } on SocketException {
        // ainda subindo
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('servidor não subiu');
  }

  Future<void> stop() async {
    _proc?.kill();
    await _proc?.exitCode;
    _proc = null;
  }
}

/// Coleta os eventos de um transporte para inspeção.
class Probe {
  Probe(this.t) {
    _sub = t.events.listen(events.add);
  }
  final RealTransport t;
  final events = <TransportEvent>[];
  late final StreamSubscription<TransportEvent> _sub;

  Future<T> next<T extends TransportEvent>({
    bool Function(T)? where,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final i = events.indexWhere((e) => e is T && (where?.call(e) ?? true));
      if (i >= 0) return events.removeAt(i) as T;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('não chegou ${T.toString()}; eventos: $events');
  }

  Future<void> close() => _sub.cancel();
}

RealTransport client(TestServer s) => RealTransport(
  s.uri,
  resumeWindow: const Duration(seconds: 3),
  retryEvery: const Duration(milliseconds: 200),
  replyTimeout: const Duration(seconds: 15),
);

void main() {
  late TestServer server;

  setUpAll(() async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(hostLibrary()));
    server = await TestServer.build();
    await server.start();
  });

  tearDownAll(() async {
    await server.stop();
    RustLib.dispose();
  });

  test(
    'duas pessoas conversam; uma terceira entra; contadores batem',
    () async {
      final a = client(server), b = client(server), c = client(server);
      final pa = Probe(a), pb = Probe(b), pc = Probe(c);

      final invite = await a.createRoom();
      expect(invite.words, hasLength(8));

      expect(await b.joinRoom(invite), 2);
      expect((await pa.next<PresenceChanged>()).count, 2);

      await b.send('oi, tudo bem?');
      expect((await pa.next<MessageReceived>()).text, 'oi, tudo bem?');
      await a.send('tudo! 🌱');
      expect((await pb.next<MessageReceived>()).text, 'tudo! 🌱');

      expect(await c.joinRoom(invite), 3);
      expect((await pa.next<PresenceChanged>()).count, 3);
      expect((await pb.next<PresenceChanged>()).count, 3);

      await c.send('cheguei');
      expect((await pa.next<MessageReceived>()).text, 'cheguei');
      expect((await pb.next<MessageReceived>()).text, 'cheguei');

      // Encerrar: c sai; quem fica vê o contador cair (P6).
      await c.leave();
      expect(
        (await pa.next<PresenceChanged>(where: (e) => e.count == 2)).change,
        PresenceChange.left,
      );
      expect(
        (await pb.next<PresenceChanged>(where: (e) => e.count == 2)).count,
        2,
      );

      await b.send('ainda aqui');
      expect((await pa.next<MessageReceived>()).text, 'ainda aqui');

      await a.leave();
      expect(
        (await pb.next<PresenceChanged>(where: (e) => e.count == 1)).count,
        1,
      );
      await b.leave();

      // Sem ninguém, a sala some (P8): a chave não abre mais nada.
      final d = client(server);
      await expectLater(
        d.joinRoom(invite),
        throwsA(
          isA<JoinException>().having(
            (e) => e.failure,
            'failure',
            JoinFailure.notFound,
          ),
        ),
      );
      for (final p in [pa, pb, pc]) {
        await p.close();
      }
    },
  );

  test('chave de outra conversa e palavras fora da lista', () async {
    final a = client(server);
    await a.createRoom();
    final outra = Invite(await generateInviteWords());
    await expectLater(
      client(server).joinRoom(outra),
      throwsA(
        isA<JoinException>().having(
          (e) => e.failure,
          'failure',
          JoinFailure.notFound,
        ),
      ),
    );
    await expectLater(
      client(server).joinRoom(
        Invite(const [
          'abacate',
          'abelha',
          'abismo',
          'absinto',
          'acervo',
          'achado',
          'aceno',
          'zzzzz',
        ]),
      ),
      throwsA(
        isA<JoinException>().having(
          (e) => e.failure,
          'failure',
          JoinFailure.invalidWords,
        ),
      ),
    );
    await a.leave();
  });

  test('servidor reiniciado: tenta reconectar e encerra a sessão', () async {
    final a = client(server), b = client(server);
    final pa = Probe(a), pb = Probe(b);
    final invite = await a.createRoom();
    await b.joinRoom(invite);
    await pa.next<PresenceChanged>();

    await server.stop();
    await pa.next<ConnectionInterrupted>();
    await pb.next<ConnectionInterrupted>();
    await server.start(); // salas em memória se perderam (reinício apaga tudo)

    await pa.next<SessionLost>();
    await pb.next<SessionLost>();
    await pa.close();
    await pb.close();
  });
}
