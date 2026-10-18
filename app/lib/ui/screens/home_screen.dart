import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../conversation/conversation_controller.dart';
import '../../conversation/conversation_state.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../widgets/frame.dart';
import 'about_screen.dart';
import 'join_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final creating = ref.watch(conversationProvider) is CreatingRoom;
    return ScreenFrame(
      top: Row(
        children: [
          const Wordmark(),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
            child: Text('Sobre', style: context.nText.caption),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: creating
              ? null
              : () => ref.read(conversationProvider.notifier).createRoom(),
          child: Text(creating ? 'Gerando chave…' : 'Gerar chave'),
        ),
        OutlinedButton(
          onPressed: creating
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const JoinScreen()),
                ),
          child: const Text('Entrar com chave'),
        ),
      ],
      children: [
        const SizedBox(height: NenuresSpace.s8),
        Semantics(
          header: true,
          child: Text('Fale. Depois, a conversa acaba.', style: t.displayLarge),
        ),
        const SizedBox(height: NenuresSpace.s3),
        Text(
          'Sem cadastro, sem nome, sem foto. Uma chave abre a conversa e, '
          'quando a última pessoa sai, ela deixa de existir no servidor.',
          style: t.bodyMedium!.copyWith(color: context.nColors.inkMuted),
        ),
        const SizedBox(height: NenuresSpace.s6),
        const _Fact('10m', 'a chave expira se ninguém entrar'),
        const _Fact('E2E', 'o servidor recebe as mensagens cifradas'),
        const _Fact('0', 'cadastro: sem nome, número ou e-mail'),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.value, this.text);
  final String value;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: NenuresSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // Cresce com a fonte do sistema para "10m" não quebrar em 200%.
            width: MediaQuery.textScalerOf(context).scale(44),
            child: Text(
              value,
              style: context.nText.key.copyWith(
                fontSize: 14,
                height: 20 / 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: t.bodyMedium!.copyWith(color: context.nColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
