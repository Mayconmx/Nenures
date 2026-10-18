// Testa a ponte Dart <-> Rust com a biblioteca nativa compilada para o PC.
// Antes: (cd rust && cargo build --release)
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/src/rust/api/error.dart';
import 'package:nenures/src/rust/api/invite.dart';
import 'package:nenures/src/rust/api/session.dart';
import 'package:nenures/src/rust/frb_generated.dart';

String hostLibrary() {
  const dir = 'rust/target/release';
  if (Platform.isWindows) return '$dir/nenures_core.dll';
  if (Platform.isMacOS) return '$dir/libnenures_core.dylib';
  return '$dir/libnenures_core.so';
}

void main() {
  setUpAll(() async {
    final path = hostLibrary();
    if (!File(path).existsSync()) {
      fail(
        'biblioteca nativa ausente em $path: rode `cargo build --release` em rust/',
      );
    }
    await RustLib.init(externalLibrary: ExternalLibrary.open(path));
  });

  tearDownAll(RustLib.dispose);

  test('gera convites de 8 palavras válidos e diferentes', () async {
    final a = await generateInviteWords();
    final b = await generateInviteWords();
    expect(a, hasLength(8));
    expect(a, isNot(b));
    expect(checkInviteWords(words: a), a);
  });

  test('aceita prefixos de 4 letras e recusa palavras fora da lista', () async {
    final w = await generateInviteWords();
    expect(checkInviteWords(words: [for (final x in w) x.substring(0, 4)]), w);
    expect(
      () => checkInviteWords(words: ['lua', 'vento']),
      throwsA(CoreError.invalidInvite),
    );
  });

  test('duas sessões conversam pela ponte', () async {
    final words = await generateInviteWords();
    final alice = await Session.create(words: words);
    final bob = await Session.prepareJoin(words: words);
    expect(alice.roomId(), bob.roomId());

    final req = await bob.joinRequest();
    final add = await alice.handleJoinRequest(request: req);
    final viewA = await alice.confirmOwnCommit();
    final viewB = await bob.acceptWelcome(welcome: add.welcome);
    expect(viewA.members, 2);
    expect(viewB.members, 2);
    expect(viewA.epoch, viewB.epoch);

    final ct = await bob.encryptText(text: 'oi, alice');
    expect(String.fromCharCodes(ct).contains('oi, alice'), isFalse);
    final got = await alice.process(message: ct);
    expect(got.kind, IncomingKind.text);
    expect(got.text, 'oi, alice');

    await expectLater(
      alice.encryptText(text: 'a' * 1001),
      throwsA(CoreError.tooLong),
    );
    await alice.close();
    await expectLater(
      alice.encryptText(text: 'oi'),
      throwsA(CoreError.notReady),
    );
  });

  test('pedido de quem não tem o convite é recusado', () async {
    final alice = await Session.create(words: await generateInviteWords());
    final intruso = await Session.prepareJoin(
      words: await generateInviteWords(),
    );
    await expectLater(
      alice.handleJoinRequest(request: await intruso.joinRequest()),
      throwsA(CoreError.wrongInvite),
    );
    expect(alice.view().members, 1);
  });
}
