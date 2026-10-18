import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../conversation/conversation_controller.dart';
import '../../conversation/conversation_state.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../widgets/frame.dart';

/// Texto honesto sobre o que foi descartado e o que o app não controla (8, tela 5).
const endLimits =
    'O app não grava a conversa no celular. Ele não consegue apagar prints, '
    'fotos ou cópias que alguém tenha feito, nem o que o teclado ou outros '
    'apps guardaram.';

(String, String) endTexts(ConversationState s) => switch (s) {
  Ended(reason: EndReason.left) => (
    'Você saiu da conversa',
    'As mensagens foram descartadas deste aparelho. A conversa continua para '
        'quem ficou e deixa de existir no servidor quando a última pessoa sair.',
  ),
  Ended(reason: EndReason.expired) => (
    'A chave expirou',
    'Ninguém entrou em 10 minutos, então a chave deixou de valer. '
        'Gere outra para começar.',
  ),
  Ended(reason: EndReason.connectionLost) => (
    'A conexão foi encerrada',
    'Não foi possível reconectar a tempo, então você saiu da conversa. '
        'As mensagens foram descartadas deste aparelho.',
  ),
  Ended(reason: EndReason.backgrounded) => (
    'A conversa foi encerrada',
    'O app ficou mais de 1 minuto em segundo plano, então você saiu. '
        'As mensagens foram descartadas deste aparelho.',
  ),
  Failed(kind: FailureKind.unavailable) => (
    'Ainda não dá para conversar',
    'Esta versão de teste ainda não tem a conexão com o servidor nem a '
        'criptografia. Elas chegam depois da revisão de segurança.',
  ),
  Failed(kind: FailureKind.network) => (
    'Sem conexão',
    'Não foi possível falar com o servidor. Confira a internet e tente de novo.',
  ),
  _ => ('', ''),
};

class EndScreen extends ConsumerWidget {
  const EndScreen({super.key, required this.state});
  final ConversationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.nColors;
    final (title, body) = endTexts(state);
    return ScreenFrame(
      actions: [
        FilledButton(
          onPressed: ref.read(conversationProvider.notifier).reset,
          child: const Text('Voltar ao início'),
        ),
      ],
      children: [
        const SizedBox(height: NenuresSpace.s8 * 2),
        ExcludeSemantics(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.line, width: 2),
            ),
          ),
        ),
        const SizedBox(height: NenuresSpace.s4),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(title, style: t.titleLarge),
        ),
        const SizedBox(height: NenuresSpace.s2),
        Text(body, style: t.bodyMedium!.copyWith(color: c.inkMuted)),
        if (state is Ended) ...[
          const SizedBox(height: NenuresSpace.s3),
          Text(endLimits, style: context.nText.caption),
        ],
      ],
    );
  }
}
