import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';

/// Nome do app: "nenures" em minúsculas seguido de um ponto em accent a 50%.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'nenures',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          text: 'nenures',
          // O ponto é o próprio "." da fonte: fica na linha de base sem
          // exigir cálculo de layout (widgets em linha quebram o layout
          // intrínseco usado pelo ScreenFrame).
          children: [
            TextSpan(
              text: '.',
              style: TextStyle(color: accent.withValues(alpha: 0.5)),
            ),
          ],
        ),
        style: context.nText.wordmark,
      ),
    );
  }
}

/// Estrutura comum das telas: conteúdo rolável (para fonte em 200%) e ações
/// presas embaixo quando há espaço.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.children,
    this.actions = const [],
    this.top,
  });

  final Widget? top;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: NenuresSize.maxContent),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NenuresSpace.s4,
                  ),
                  // Ocupa a tela quando cabe (ações embaixo) e rola quando
                  // não cabe (fonte grande).
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: NenuresSpace.s3),
                        top ??
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Wordmark(),
                            ),
                        ...children,
                        const Spacer(),
                        const SizedBox(height: NenuresSpace.s6),
                        for (final a in actions) ...[
                          a,
                          const SizedBox(height: NenuresSpace.s2),
                        ],
                        const SizedBox(height: NenuresSpace.s3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estilos dos botões pequenos (pílula) e de perigo. A altura visual é
/// [NenuresSize.smallButton]; a área de toque continua com 48 dp porque o
/// tema usa `MaterialTapTargetSize.padded`.
abstract final class NenuresButtons {
  static ButtonStyle small(BuildContext context) => OutlinedButton.styleFrom(
    minimumSize: const Size(0, NenuresSize.smallButton),
    padding: const EdgeInsets.symmetric(horizontal: NenuresSpace.s3),
    shape: const StadiumBorder(),
    textStyle: Theme.of(context).textTheme.labelMedium,
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  static ButtonStyle danger(BuildContext context, {required bool armed}) {
    final c = context.nColors;
    return small(context).copyWith(
      foregroundColor: WidgetStatePropertyAll(armed ? c.onDanger : c.danger),
      backgroundColor: WidgetStatePropertyAll(
        armed ? c.danger : Colors.transparent,
      ),
      side: WidgetStatePropertyAll(BorderSide(color: c.danger)),
    );
  }
}
