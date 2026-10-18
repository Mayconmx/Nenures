import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../conversation/conversation_controller.dart';
import '../../conversation/conversation_state.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../widgets/frame.dart';
import '../widgets/key_widgets.dart';

/// "Sua chave". Aberta logo depois de gerar e, no chat, pelo botão "Chave".
class KeyScreen extends ConsumerWidget {
  const KeyScreen({super.key, required this.state});
  final InConversation state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final ctrl = ref.read(conversationProvider.notifier);
    final waitingAlone = state.phase == ConversationPhase.waiting;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ctrl.openChat();
      },
      child: ScreenFrame(
        actions: [
          FilledButton(
            onPressed: ctrl.openChat,
            child: const Text('Abrir conversa'),
          ),
          if (waitingAlone && state.isCreator)
            TextButton(
              onPressed: ctrl.cancelKey,
              child: const Text('Cancelar'),
            ),
        ],
        children: [
          const SizedBox(height: NenuresSpace.s6),
          Semantics(
            header: true,
            child: Text('Sua chave', style: t.titleLarge),
          ),
          const SizedBox(height: NenuresSpace.s2),
          Text(
            'Mostre o QR code ou passe as palavras para quem vai conversar '
            'com você. Quem tiver a chave pode entrar enquanto a conversa existir.',
            style: t.bodyMedium!.copyWith(color: context.nColors.inkMuted),
          ),
          const SizedBox(height: NenuresSpace.s4),
          KeyCard(invite: state.invite, expiresAt: state.expiresAt),
        ],
      ),
    );
  }
}
