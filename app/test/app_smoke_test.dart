import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/app.dart';

void main() {
  testWidgets('o app abre na tela de início', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NenuresApp()));
    expect(find.text('Fale. Depois, a conversa acaba.'), findsOneWidget);
    expect(find.text('Gerar chave'), findsOneWidget);
    expect(find.text('Entrar com chave'), findsOneWidget);
  });

  testWidgets(
    'sem protocolo aprovado, gerar chave mostra que não está disponível',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: NenuresApp()));
      await tester.tap(find.text('Gerar chave'));
      await tester.pumpAndSettle();
      expect(find.text('Ainda não dá para conversar'), findsOneWidget);
      await tester.tap(find.text('Voltar ao início'));
      await tester.pumpAndSettle();
      expect(find.text('Gerar chave'), findsOneWidget);
    },
  );
}
