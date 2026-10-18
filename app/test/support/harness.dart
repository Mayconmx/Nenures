import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/app.dart';
import 'package:nenures/conversation/conversation_controller.dart';

import 'fake_transport.dart';

bool _fontsLoaded = false;

/// Carrega as fontes reais do app. Sem isso os testes usam a fonte "Ahem"
/// (cada letra é um quadrado), bem mais larga, e o layout não corresponde ao
/// do aparelho.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await load('BricolageGrotesque', ['BricolageGrotesque-Variable.ttf']);
  await load('IBMPlexSans', ['IBMPlexSans-Variable.ttf']);
  await load('IBMPlexMono', [
    'IBMPlexMono-Regular.ttf',
    'IBMPlexMono-Medium.ttf',
  ]);
  await load('NenuresSymbols', ['NenuresSymbols.ttf']);
  _fontsLoaded = true;
}

/// Monta o app inteiro com o transporte falso, num celular de 360 x 760 dp.
Future<FakeConversationTransport> pumpApp(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  FakeConversationTransport? fake,
}) async {
  await t.runAsync(loadAppFonts);
  final transport = fake ?? FakeConversationTransport();
  t.view.physicalSize = const Size(360 * 3, 760 * 3);
  t.view.devicePixelRatio = 3;
  t.platformDispatcher.platformBrightnessTestValue = brightness;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  addTearDown(transport.close);
  await t.pumpWidget(
    ProviderScope(
      overrides: [transportProvider.overrideWithValue(transport)],
      child: const NenuresApp(),
    ),
  );
  return transport;
}

/// Rola até o alvo (necessário com fonte grande) e toca.
Future<void> tapOn(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
}

/// Do início até o chat com outra pessoa já presente.
Future<FakeConversationTransport> pumpChat(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  final fake = await pumpApp(t, brightness: brightness, textScale: textScale);
  await tapOn(t, find.text('Gerar chave'));
  await t.pump();
  await tapOn(t, find.text('Abrir conversa'));
  fake.someoneJoins(2);
  await t.pump();
  return fake;
}

/// Simula o canal nativo de cópia sensível (o caminho usado no Android) e
/// devolve o que foi copiado por ele.
List<String> captureClipboard(WidgetTester t) {
  const channel = MethodChannel('nenures/clipboard');
  final copied = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    if (call.method == 'copySensitive') {
      copied.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  return copied;
}

/// Verifica as diretrizes de acessibilidade do Flutter na tela atual.
Future<void> expectAccessible(WidgetTester t) async {
  await expectLater(t, meetsGuideline(androidTapTargetGuideline));
  await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(t, meetsGuideline(textContrastGuideline));
}
