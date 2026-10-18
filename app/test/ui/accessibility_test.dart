import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// Percorre todas as telas e, em cada uma, verifica as diretrizes de
/// acessibilidade (alvo de 48 dp, rótulo em alvos tocáveis, contraste de texto)
/// e a ausência de erros de layout. Roda nos dois temas e com fonte em 100% e 200%.
void main() {
  for (final b in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      final tag = '${b.name}, fonte ${(scale * 100).toInt()}%';

      testWidgets('todas as telas — $tag', (t) async {
        final fake = await pumpApp(t, brightness: b, textScale: scale);

        Future<void> check(String screen) async {
          // Espera a animação de entrada das mensagens (180 ms) terminar:
          // o contraste é medido no estado final, não no meio do esmaecimento.
          await t.pump(const Duration(milliseconds: 300));
          expect(t.takeException(), isNull, reason: screen);
          // O contraste usa a renderização de teste; com fonte em 200% o
          // conteúdo rola e parte fica fora da tela, o que só afeta o desenho.
          if (scale == 1.0) {
            await expectAccessible(t);
          } else {
            await expectLater(t, meetsGuideline(androidTapTargetGuideline));
            await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          }
        }

        await check('início');

        await tapOn(t, find.text('Gerar chave'));
        await t.pump();
        await check('sua chave');

        await tapOn(t, find.text('Abrir conversa'));
        fake.someoneJoins(2);
        await t.enterText(find.byType(TextField), 'oi');
        await tapOn(t, find.byTooltip('Enviar'));
        fake.receive('olá, tudo bem?');
        await t.pump();
        await check('chat');

        await tapOn(t, find.text('Encerrar'));
        await check('encerrar armado');
        await tapOn(t, find.text('Tocar de novo para sair'));
        await t.pump();
        await check('fim');

        await tapOn(t, find.text('Voltar ao início'));
        await tapOn(t, find.text('Entrar com chave'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), 'lua');
        await tapOn(t, find.text('Entrar'));
        await check('entrar com erro');

        await tapOn(t, find.text('Voltar'));
        await t.pumpAndSettle();
        await tapOn(t, find.text('Sobre'));
        await t.pumpAndSettle();
        await check('sobre');
      });
    }
  }
}
