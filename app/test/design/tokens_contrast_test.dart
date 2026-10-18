import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/design/tokens.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, p) in [
    ('claro', NenuresPalette.light),
    ('escuro', NenuresPalette.dark),
  ]) {
    group('tema $name', () {
      // Pares de texto: mínimo 4,5:1 (WCAG 1.4.3).
      final textPairs = <String, (Color, Color)>{
        'ink / surface-000': (p.ink, p.surface000),
        'ink / surface-100': (p.ink, p.surface100),
        'ink / bubble-theirs': (p.ink, p.bubbleTheirs),
        'ink-muted / surface-000': (p.inkMuted, p.surface000),
        'ink-muted / surface-100': (p.inkMuted, p.surface100),
        'ink-muted / bubble-theirs': (p.inkMuted, p.bubbleTheirs),
        'on-accent / accent': (p.onAccent, p.accent),
        'on-bubble-mine / bubble-mine': (p.onBubbleMine, p.bubbleMine),
        'key-ink / surface-sunk': (p.keyInk, p.surfaceSunk),
        'key-ink / surface-000': (p.keyInk, p.surface000),
        'danger / surface-000': (p.danger, p.surface000),
        'danger / surface-100': (p.danger, p.surface100),
        'on-danger / danger': (p.onDanger, p.danger),
        'warn / surface-000': (p.warn, p.surface000),
        'warn / surface-sunk': (p.warn, p.surfaceSunk),
      };
      textPairs.forEach((label, pair) {
        test('$label >= 4,5:1', () {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        });
      });

      // Contorno de controles e anel de foco: mínimo 3:1 (WCAG 1.4.11).
      final uiPairs = <String, (Color, Color)>{
        'line-strong / surface-000': (p.lineStrong, p.surface000),
        'line-strong / surface-100': (p.lineStrong, p.surface100),
        'line-strong / surface-sunk': (p.lineStrong, p.surfaceSunk),
        'accent (foco) / surface-000': (p.accent, p.surface000),
        'accent (foco) / surface-100': (p.accent, p.surface100),
      };
      uiPairs.forEach((label, pair) {
        test('$label >= 3:1', () {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(3.0));
        });
      });
    });
  }
}
