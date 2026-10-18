import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../conversation/conversation_state.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import 'frame.dart';

/// Quantas pessoas estão aqui. Pontos até 6; o texto dá o número exato.
/// O número vem do estado validado pelo protocolo, nunca do servidor.
class PresenceBar extends StatelessWidget {
  const PresenceBar({super.key, required this.count, required this.trailing});

  final int count;
  final Widget trailing;

  static String label(int n) => n == 1 ? 'Só você aqui' : '$n pessoas aqui';

  /// Acima desta escala de fonte, contador e botões ficam em linhas separadas
  /// para que nenhuma palavra seja quebrada no meio.
  static const double stackAboveTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final presence = Row(
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < math.min(count, 6); i++)
                Container(
                  margin: const EdgeInsets.only(right: NenuresSpace.s1),
                  width: NenuresSize.presenceDot,
                  height: NenuresSize.presenceDot,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: NenuresSpace.s1),
        Expanded(
          child: Semantics(
            liveRegion: true,
            label: count == 1
                ? 'Só você na conversa'
                : '$count pessoas na conversa',
            excludeSemantics: true,
            child: Text(
              label(count),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );

    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (scale > stackAboveTextScale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          presence,
          Align(alignment: Alignment.centerRight, child: trailing),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: presence),
        trailing,
      ],
    );
  }
}

/// Balão sem nome, foto nem horário. Todas as outras pessoas usam o mesmo
/// estilo; a interface não atribui identidade a ninguém.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.item});
  final ChatItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.nColors;
    final t = Theme.of(context).textTheme;

    final Widget child;
    switch (item.kind) {
      case ChatItemKind.system:
        child = Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.all(NenuresSpace.s1),
            child: Text(
              item.text,
              style: context.nText.caption,
              textAlign: TextAlign.center,
            ),
          ),
        );
        return _appear(context, Center(child: child));
      case ChatItemKind.mine:
      case ChatItemKind.theirs:
        final mine = item.kind == ChatItemKind.mine;
        const r = Radius.circular(NenuresRadius.lg);
        const s = Radius.circular(NenuresRadius.sm);
        child = Semantics(
          label: mine ? 'Você' : 'Outra pessoa',
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: NenuresSpace.s3,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: mine ? c.bubbleMine : c.bubbleTheirs,
              border: mine ? null : Border.all(color: c.line),
              borderRadius: BorderRadius.only(
                topLeft: r,
                topRight: r,
                bottomLeft: mine ? r : s,
                bottomRight: mine ? s : r,
              ),
            ),
            // Texto puro: URLs não viram links (3.2).
            child: Text(
              item.text,
              style: t.bodyMedium!.copyWith(
                color: mine ? c.onBubbleMine : null,
              ),
            ),
          ),
        );
        return _appear(
          context,
          Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          ),
        );
    }
  }

  /// Entrada curta (180 ms); desligada com redução de movimento.
  Widget _appear(BuildContext context, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NenuresLimits.messageAnimation,
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: 0.4 + 0.6 * v,
        child: Transform.translate(
          offset: Offset(0, 4 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Encerrar em dois toques: o primeiro arma; sem o segundo em 3 s, desarma.
class EndButton extends StatefulWidget {
  const EndButton({super.key, required this.onConfirmed});
  final VoidCallback onConfirmed;

  @override
  State<EndButton> createState() => _EndButtonState();
}

class _EndButtonState extends State<EndButton> {
  Timer? _timer;
  bool _armed = false;

  void _tap() {
    if (_armed) {
      _timer?.cancel();
      setState(() => _armed = false);
      widget.onConfirmed();
      return;
    }
    setState(() => _armed = true);
    _timer = Timer(NenuresLimits.endArmWindow, () {
      if (mounted) setState(() => _armed = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hint: _armed ? null : 'Toque duas vezes em até 3 segundos para sair',
      child: OutlinedButton(
        style: NenuresButtons.danger(context, armed: _armed),
        onPressed: _tap,
        child: Text(_armed ? 'Tocar de novo para sair' : 'Encerrar'),
      ),
    );
  }
}
