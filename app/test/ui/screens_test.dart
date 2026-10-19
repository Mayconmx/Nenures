import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/conversation/transport.dart';
import 'package:nenures/platform/sensitive_clipboard.dart';
import 'package:nenures/ui/screens/about_screen.dart';
import 'package:nenures/ui/screens/end_screen.dart';

import '../support/harness.dart';

void main() {
  group('Início', () {
    testWidgets('título, três fatos e as duas ações', (t) async {
      await pumpApp(t);
      expect(find.text('Fale. Depois, a conversa acaba.'), findsOneWidget);
      expect(find.text('10m'), findsOneWidget);
      expect(
        find.text('o servidor recebe as mensagens cifradas'),
        findsOneWidget,
      );
      expect(find.text('cadastro: sem nome, número ou e-mail'), findsOneWidget);
      expect(find.text('Gerar chave'), findsOneWidget);
      expect(find.text('Entrar com chave'), findsOneWidget);
    });

    testWidgets('Sobre explica que não há notificações (P10)', (t) async {
      await pumpApp(t);
      await tapOn(t, find.text('Sobre'));
      await t.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.textContaining('não envia notificações'), findsOneWidget);
      expect(find.textContaining('endereço IP'), findsOneWidget);
      await tapOn(t, find.byTooltip('Voltar'));
      await t.pumpAndSettle();
      expect(find.text('Gerar chave'), findsOneWidget);
    });
  });

  group('Sua chave', () {
    testWidgets('mostra QR, 8 palavras e a validade', (t) async {
      await pumpApp(t);
      await tapOn(t, find.text('Gerar chave'));
      await t.pump();
      expect(find.text('Sua chave'), findsOneWidget);
      expect(find.bySemanticsLabel('QR code da chave'), findsOneWidget);
      expect(
        find.text('abacate abelha abismo absinto acervo achado aceno acesso'),
        findsOneWidget,
      );
      expect(find.text('expira em 10:00'), findsOneWidget);
    });

    testWidgets('copiar exige confirmação; cancelar não copia', (t) async {
      final copied = captureClipboard(t);
      await pumpApp(t);
      await tapOn(t, find.text('Gerar chave'));
      await t.pump();

      await tapOn(t, find.text('Copiar chave'));
      await t.pumpAndSettle();
      expect(find.text('Copiar a chave?'), findsOneWidget);
      expect(find.textContaining('Quem tiver estas palavras'), findsOneWidget);
      await t.tap(find.text('Cancelar').last);
      await t.pumpAndSettle();
      expect(copied, isEmpty);

      await tapOn(t, find.text('Copiar chave'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Copiar'));
      await t.pumpAndSettle();
      expect(copied, [
        'abacate abelha abismo absinto acervo achado aceno acesso',
      ]);
      expect(find.text('Chave copiada.'), findsOneWidget);
      // D13: depois de 1 minuto o app pede a limpeza ao código nativo.
      await t.pump(SensitiveClipboard.clearAfter);
      await t.pump();
      expect(clearRequests(t), 1);
    });

    testWidgets('Cancelar volta ao início e sai da sala', (t) async {
      final fake = await pumpApp(t);
      await tapOn(t, find.text('Gerar chave'));
      await t.pump();
      await tapOn(t, find.text('Cancelar'));
      await t.pump();
      expect(find.text('Gerar chave'), findsOneWidget);
      expect(fake.leaveCalls, 1);
    });

    testWidgets('a chave expira em 10 minutos sem ninguém (P3)', (t) async {
      await pumpApp(t);
      await tapOn(t, find.text('Gerar chave'));
      await t.pump();
      await t.pump(const Duration(minutes: 10));
      await t.pump();
      expect(find.text('A chave expirou'), findsOneWidget);
    });
  });

  group('Entrar com chave', () {
    Future<void> openJoin(WidgetTester t) async {
      await tapOn(t, find.text('Entrar com chave'));
      await t.pumpAndSettle();
    }

    testWidgets('campo sem correção, sugestões nem aprendizado', (t) async {
      await pumpApp(t);
      await openJoin(t);
      final field = t.widget<TextField>(find.byType(TextField));
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.keyboardType, TextInputType.visiblePassword);
    });

    testWidgets('contagem errada mostra erro claro', (t) async {
      await pumpApp(t);
      await openJoin(t);
      await t.enterText(find.byType(TextField), 'lua vento');
      await tapOn(t, find.text('Entrar'));
      expect(
        find.text('A chave tem 8 palavras separadas por espaço.'),
        findsOneWidget,
      );
    });

    testWidgets('chave inexistente ou expirada', (t) async {
      final fake = await pumpApp(t);
      fake.joinResult = const JoinException(JoinFailure.notFound);
      await openJoin(t);
      await t.enterText(
        find.byType(TextField),
        'abacate abelha abismo absinto acervo achado aceno acesso',
      );
      await tapOn(t, find.text('Entrar'));
      await t.pump();
      expect(find.textContaining('não encontrada ou expirada'), findsOneWidget);
    });

    testWidgets('chave válida abre o chat com a contagem validada', (t) async {
      await pumpApp(t);
      await openJoin(t);
      await t.enterText(
        find.byType(TextField),
        'Abacate abelha abismo absinto acervo achado aceno acesso',
      );
      await tapOn(t, find.text('Entrar'));
      await t.pumpAndSettle();
      expect(find.text('2 pessoas aqui'), findsOneWidget);
      expect(find.text('Você entrou na conversa.'), findsOneWidget);
    });
  });

  group('Chat', () {
    testWidgets('envia, recebe e anuncia a presença', (t) async {
      final fake = await pumpChat(t);
      expect(find.text('2 pessoas aqui'), findsOneWidget);
      expect(find.bySemanticsLabel('2 pessoas na conversa'), findsOneWidget);

      await t.enterText(find.byType(TextField), 'oi');
      await tapOn(t, find.byTooltip('Enviar'));
      await t.pump();
      expect(fake.sent, ['oi']);
      expect(find.text('oi'), findsOneWidget);

      fake.receive('olá');
      fake.someoneJoins(3);
      await t.pump();
      expect(find.text('olá'), findsOneWidget);
      expect(find.text('Alguém entrou · 3 pessoas'), findsOneWidget);
      expect(find.text('3 pessoas aqui'), findsOneWidget);
    });

    testWidgets('URLs não viram links (3.2)', (t) async {
      final fake = await pumpChat(t);
      fake.receive('veja https://exemplo.com');
      await t.pump();
      for (final rich in t.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          if (span is TextSpan) expect(span.recognizer, isNull);
          return true;
        });
      }
      expect(
        find.byType(GestureDetector).evaluate().where((e) {
          final w = e.widget as GestureDetector;
          return w.onTap != null &&
              find
                  .descendant(
                    of: find.byWidget(w),
                    matching: find.textContaining('https://'),
                  )
                  .evaluate()
                  .isNotEmpty;
        }),
        isEmpty,
      );
    });

    testWidgets('Encerrar: dois toques; desarma em 3 s', (t) async {
      final fake = await pumpChat(t);
      await tapOn(t, find.text('Encerrar'));
      expect(find.text('Tocar de novo para sair'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Encerrar'), findsOneWidget);
      expect(fake.leaveCalls, 0);

      await tapOn(t, find.text('Encerrar'));
      await tapOn(t, find.text('Tocar de novo para sair'));
      await t.pump();
      expect(find.text('Você saiu da conversa'), findsOneWidget);
      expect(find.text(endLimits), findsOneWidget);
      expect(fake.leaveCalls, 1);

      await tapOn(t, find.text('Voltar ao início'));
      expect(find.text('Gerar chave'), findsOneWidget);
    });

    testWidgets('voltar do sistema não sai da conversa', (t) async {
      final fake = await pumpChat(t);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.text('2 pessoas aqui'), findsOneWidget);
      expect(fake.leaveCalls, 0);
    });

    testWidgets('reconectando: aviso e envio bloqueado', (t) async {
      final fake = await pumpChat(t);
      fake.emit(const ConnectionInterrupted());
      await t.pump();
      expect(find.textContaining('Tentando voltar'), findsOneWidget);
      final send = t.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Enviar'),
          matching: find.byType(IconButton),
        ),
      );
      expect(send.onPressed, isNull);
      fake.emit(const ConnectionRestored());
      await t.pump();
      expect(find.textContaining('Tentando voltar'), findsNothing);
    });

    testWidgets('sessão perdida leva à tela de conexão encerrada', (t) async {
      final fake = await pumpChat(t);
      fake.emit(const SessionLost());
      await t.pump();
      await t.pump();
      expect(find.text('A conexão foi encerrada'), findsOneWidget);
    });

    testWidgets('mostrar a chave a partir do chat', (t) async {
      await pumpChat(t);
      await tapOn(t, find.byTooltip('Mais opções'));
      await t.pumpAndSettle();
      await t.tap(find.text('Mostrar chave'));
      await t.pumpAndSettle();
      expect(find.text('Sua chave'), findsOneWidget);
      // Depois que alguém entrou não há validade nem "Cancelar" (P4).
      expect(find.textContaining('expira em'), findsNothing);
      expect(find.text('Cancelar'), findsNothing);
      await tapOn(t, find.text('Abrir conversa'));
      expect(find.text('2 pessoas aqui'), findsOneWidget);
    });

    testWidgets('trancar entrada pede confirmação e não tem volta (D7)', (
      t,
    ) async {
      final fake = await pumpChat(t);
      Future<void> openMenu() async {
        await tapOn(t, find.byTooltip('Mais opções'));
        await t.pumpAndSettle();
      }

      await openMenu();
      await t.tap(find.text('Trancar entrada'));
      await t.pumpAndSettle();
      expect(find.text('Trancar a entrada?'), findsOneWidget);
      await t.tap(find.text('Cancelar').last);
      await t.pumpAndSettle();
      expect(fake.lockCalls, 0);

      await openMenu();
      await t.tap(find.text('Trancar entrada'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Trancar'));
      await t.pumpAndSettle();
      expect(fake.lockCalls, 1);
      expect(find.textContaining('Você trancou a entrada'), findsOneWidget);

      await openMenu();
      final item = t.widget<PopupMenuItem<Object?>>(
        find.ancestor(
          of: find.text('Entrada trancada'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
        ),
      );
      expect(item.enabled, isFalse);
      await t.tap(find.text('Mostrar chave'));
      await t.pumpAndSettle();
      expect(find.textContaining('não abre mais a conversa'), findsOneWidget);
    });
  });
}
