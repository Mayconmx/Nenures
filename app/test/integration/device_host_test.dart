// Teste manual com aparelho/emulador: o PC cria a conversa e espera o app
// entrar (por exemplo, lendo o QR). Uso:
//   NENURES_HOST_OUT=/caminho/payload.txt flutter test test/integration/device_host_test.dart
// Grava o conteúdo do QR em NENURES_HOST_OUT. Sem a variável, o teste é pulado.
@TestOn('vm')
@Timeout(Duration(minutes: 10))
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/conversation/real_transport.dart';
import 'package:nenures/conversation/transport.dart';
import 'package:nenures/src/rust/frb_generated.dart';

import '../rust/bridge_test.dart' show hostLibrary;

void main() {
  final out = Platform.environment['NENURES_HOST_OUT'];

  test('PC cria a conversa e espera o aparelho entrar', () async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(hostLibrary()));
    final t = RealTransport(Uri.parse('ws://127.0.0.1:8080/v1'));
    final joined = Completer<int>();
    final sub = t.events.listen((e) {
      if (e is PresenceChanged && e.count >= 2 && !joined.isCompleted) {
        joined.complete(e.count);
      }
    });
    final invite = await t.createRoom();
    File(out!).writeAsStringSync(invite.qrPayload);
    stdout.writeln('CRIADA');
    final n = await joined.future.timeout(const Duration(minutes: 9));
    stdout.writeln('ENTROU: $n pessoas');
    await t.send('o QR funcionou');
    await Future<void>.delayed(const Duration(seconds: 5));
    await t.leave();
    await sub.cancel();
  }, skip: out == null ? 'defina NENURES_HOST_OUT' : false);
}
