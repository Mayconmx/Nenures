// Teste manual com aparelho/emulador: o PC entra na conversa criada no app.
// Uso (servidor local em 127.0.0.1:8080, app apontando para ws://10.0.2.2:8080/v1):
//   NENURES_DEVICE_WORDS="palavra1 ... palavra8" flutter test test/integration/device_join_test.dart
// Sem a variável, o teste é pulado.
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
import 'package:nenures/src/rust/frb_generated.dart';

import '../rust/bridge_test.dart' show hostLibrary;

void main() {
  final words = Platform.environment['NENURES_DEVICE_WORDS'];

  test('PC entra na conversa do aparelho, envia e recebe', () async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(hostLibrary()));
    final t = RealTransport(Uri.parse('ws://127.0.0.1:8080/v1'));
    final received = Completer<String>();
    final sub = t.events.listen((e) {
      if (e is MessageReceived && !received.isCompleted) {
        received.complete(e.text);
      }
    });
    final n = await t.joinRoom(Invite(words!.split(' ')));
    stdout.writeln('ENTROU: $n pessoas');
    await t.send('olá do PC');
    stdout.writeln('ENVIOU');
    final reply = await received.future.timeout(const Duration(seconds: 90));
    stdout.writeln('RECEBEU: $reply');
    await Future<void>.delayed(const Duration(seconds: 3));
    await t.leave();
    await sub.cancel();
  }, skip: words == null ? 'defina NENURES_DEVICE_WORDS' : false);
}
