import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../conversation/conversation_controller.dart';
import '../../conversation/conversation_state.dart';
import '../../design/nenures_icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../widgets/chat_widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.state});
  final InConversation state;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _field = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _field.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await ref.read(conversationProvider.notifier).send(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _field.clear();
  }

  /// D7: trancar não tem volta, então pede confirmação.
  Future<void> _confirmLock(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trancar a entrada?'),
        content: const Text(
          'Ninguém novo vai conseguir entrar nesta conversa, nem com a chave. '
          'Quem já está aqui continua. Não dá para desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trancar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(conversationProvider.notifier).lockEntry();
    }
  }

  @override
  void dispose() {
    _field.clear();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final ctrl = ref.read(conversationProvider.notifier);
    final reconnecting = s.phase == ConversationPhase.reconnecting;
    final items = s.items.reversed.toList(growable: false);

    return PopScope(
      // Voltar não sai da conversa por acidente; sair é sempre pelo Encerrar.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: NenuresSize.maxContent,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NenuresSpace.s4,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: NenuresSpace.s2,
                        bottom: NenuresSpace.s2,
                      ),
                      child: PresenceBar(
                        count: s.participants,
                        // Wrap: com fonte grande, o Encerrar armado desce
                        // para a linha de baixo em vez de transbordar.
                        trailing: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _ChatMenu(
                              locked: s.locked,
                              onShowKey: ctrl.showKey,
                              onLock: () => _confirmLock(context),
                            ),
                            EndButton(onConfirmed: ctrl.leave),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    if (reconnecting) const _ReconnectingBanner(),
                    Expanded(
                      child: ListView.separated(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          vertical: NenuresSpace.s3,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) => MessageBubble(
                          key: ValueKey(items[i].id),
                          item: items[i],
                        ),
                      ),
                    ),
                    _Composer(
                      controller: _field,
                      enabled: !reconnecting && !_sending,
                      onSend: _send,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.nColors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: NenuresSpace.s2),
        padding: const EdgeInsets.all(NenuresSpace.s3),
        decoration: BoxDecoration(
          color: c.surfaceSunk,
          borderRadius: BorderRadius.circular(NenuresRadius.md),
        ),
        child: Row(
          children: [
            Icon(NenuresIcons.wifiOff, color: c.warn, size: 20),
            const SizedBox(width: NenuresSpace.s2),
            Expanded(
              child: Text(
                'Sem conexão. Tentando voltar por até 1 minuto.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: NenuresSpace.s2,
        bottom: NenuresSpace.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 5,
              maxLength: NenuresLimits.messageMaxChars,
              buildCounter:
                  (_, {required currentLength, required isFocused, maxLength}) {
                    // Contador só perto do limite, para não poluir a tela.
                    if (currentLength < NenuresLimits.messageMaxChars - 100) {
                      return null;
                    }
                    return Text(
                      '$currentLength/$maxLength',
                      style: context.nText.caption,
                    );
                  },
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(fontSize: 16),
              textCapitalization: TextCapitalization.sentences,
              enableIMEPersonalizedLearning: false,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(hintText: 'Mensagem'),
            ),
          ),
          const SizedBox(width: NenuresSpace.s2),
          IconButton.filled(
            tooltip: 'Enviar',
            onPressed: enabled ? onSend : null,
            icon: const Icon(NenuresIcons.send),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { showKey, lock }

/// Menu da barra do chat: mostrar a chave e trancar a entrada (D7).
class _ChatMenu extends StatelessWidget {
  const _ChatMenu({
    required this.locked,
    required this.onShowKey,
    required this.onLock,
  });

  final bool locked;
  final VoidCallback onShowKey;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Mais opções',
      icon: const Icon(NenuresIcons.moreVert),
      onSelected: (a) => switch (a) {
        _MenuAction.showKey => onShowKey(),
        _MenuAction.lock => onLock(),
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _MenuAction.showKey,
          child: Row(
            children: [
              Icon(NenuresIcons.key),
              SizedBox(width: NenuresSpace.s3),
              Text('Mostrar chave'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.lock,
          enabled: !locked,
          child: Row(
            children: [
              const Icon(NenuresIcons.lock),
              const SizedBox(width: NenuresSpace.s3),
              Text(locked ? 'Entrada trancada' : 'Trancar entrada'),
            ],
          ),
        ),
      ],
    );
  }
}
