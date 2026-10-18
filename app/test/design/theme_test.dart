import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/design/nenures_icons.dart';
import 'package:nenures/design/theme.dart';
import 'package:nenures/design/tokens.dart';

void main() {
  for (final b in Brightness.values) {
    test('tema ${b.name} tem as extensões e as cores certas', () {
      final t = buildNenuresTheme(b);
      final p = b == Brightness.light
          ? NenuresPalette.light
          : NenuresPalette.dark;
      expect(t.extension<NenuresColors>(), isNotNull);
      expect(t.extension<NenuresText>(), isNotNull);
      expect(t.colorScheme.primary, p.accent);
      expect(t.scaffoldBackgroundColor, p.surface000);
      expect(t.textTheme.displayLarge!.fontFamily, NenuresFonts.display);
      expect(t.extension<NenuresText>()!.key.fontFamily, NenuresFonts.mono);
      final border =
          t.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.color, p.lineStrong);
    });
  }

  testWidgets('botões têm alvo de toque de pelo menos 48 dp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildNenuresTheme(Brightness.light),
        home: Scaffold(
          body: Column(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Gerar chave')),
              OutlinedButton(onPressed: () {}, child: const Text('Entrar')),
              TextButton(onPressed: () {}, child: const Text('Voltar')),
              IconButton(
                onPressed: () {},
                icon: const Icon(NenuresIcons.close),
                tooltip: 'Fechar',
              ),
            ],
          ),
        ),
      ),
    );
    for (final type in [FilledButton, OutlinedButton, TextButton, IconButton]) {
      final size = tester.getSize(find.byType(type));
      expect(
        size.height,
        greaterThanOrEqualTo(NenuresSize.touchMin),
        reason: '$type',
      );
      expect(
        size.width,
        greaterThanOrEqualTo(NenuresSize.touchMin),
        reason: '$type',
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  test('fontes estão empacotadas como assets', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final f in [
      'assets/fonts/BricolageGrotesque-Variable.ttf',
      'assets/fonts/IBMPlexSans-Variable.ttf',
      'assets/fonts/IBMPlexMono-Regular.ttf',
      'assets/fonts/IBMPlexMono-Medium.ttf',
      'assets/fonts/NenuresSymbols.ttf',
    ]) {
      final data = await rootBundle.load(f);
      expect(data.lengthInBytes, greaterThan(1000), reason: f);
    }
  });
}
