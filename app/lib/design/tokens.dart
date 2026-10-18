// Tokens do design system do Nenures (artifact H7qHKD34BUarMZ8SpvzxSF, tokens.json v1).
// Fonte única de cores e medidas: nenhum widget escreve cor ou tamanho direto.
//
// Diferença em relação ao design system publicado:
// - `lineStrong` é novo. `line` tem contraste de 1,3:1 e não serve para a borda de
//   campos (WCAG 1.4.11 pede 3:1). Ver docs/revisao-seguranca.md, C7.

import 'package:flutter/painting.dart';

/// Paleta de um tema (claro ou escuro).
class NenuresPalette {
  const NenuresPalette({
    required this.surface000,
    required this.surface100,
    required this.surfaceSunk,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.onAccent,
    required this.bubbleMine,
    required this.onBubbleMine,
    required this.bubbleTheirs,
    required this.keyInk,
    required this.danger,
    required this.onDanger,
    required this.warn,
  });

  final Color surface000;
  final Color surface100;
  final Color surfaceSunk;
  final Color ink;
  final Color inkMuted;
  final Color line;
  final Color lineStrong;
  final Color accent;
  final Color onAccent;
  final Color bubbleMine;
  final Color onBubbleMine;
  final Color bubbleTheirs;
  final Color keyInk;
  final Color danger;
  final Color onDanger;
  final Color warn;

  /// O QR fica preto sobre branco nos dois temas, para qualquer câmera ler.
  static const Color qrDark = Color(0xFF000000);
  static const Color qrLight = Color(0xFFFFFFFF);

  static const light = NenuresPalette(
    surface000: Color(0xFFEEF0F3),
    surface100: Color(0xFFFFFFFF),
    surfaceSunk: Color(0xFFE3E6EB),
    ink: Color(0xFF1B2230),
    inkMuted: Color(0xFF5F6878),
    line: Color(0xFFD3D8E0),
    lineStrong: Color(0xFF78818F),
    accent: Color(0xFF3D5A8C),
    onAccent: Color(0xFFFFFFFF),
    bubbleMine: Color(0xFF3D5A8C),
    onBubbleMine: Color(0xFFF4F6FB),
    bubbleTheirs: Color(0xFFFFFFFF),
    keyInk: Color(0xFF2C3A55),
    danger: Color(0xFFA8392F),
    onDanger: Color(0xFFFFFFFF),
    warn: Color(0xFF8A5A12),
  );

  static const dark = NenuresPalette(
    surface000: Color(0xFF121620),
    surface100: Color(0xFF1A2030),
    surfaceSunk: Color(0xFF0D1018),
    ink: Color(0xFFE4E8F0),
    inkMuted: Color(0xFF8F98AA),
    line: Color(0xFF2A3245),
    lineStrong: Color(0xFF66718A),
    accent: Color(0xFF8AA6D8),
    onAccent: Color(0xFF0F1420),
    bubbleMine: Color(0xFF34507F),
    onBubbleMine: Color(0xFFEEF2FA),
    bubbleTheirs: Color(0xFF1F2638),
    keyInk: Color(0xFFB9C8E6),
    danger: Color(0xFFE07A6F),
    onDanger: Color(0xFF1A0D0B),
    warn: Color(0xFFD9A75A),
  );
}

/// Espaçamento (grade de 4 px).
abstract final class NenuresSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;
}

/// Raios de borda.
abstract final class NenuresRadius {
  static const double sm = 4;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Medidas fixas.
abstract final class NenuresSize {
  /// Alvo de toque mínimo (Android).
  static const double touchMin = 48;

  /// Altura visual do botão pequeno; a área de toque continua com [touchMin].
  static const double smallButton = 36;
  static const double presenceDot = 8;
  static const double qr = 168;
  static const double focusRing = 2;

  /// Largura máxima do conteúdo em telas grandes.
  static const double maxContent = 480;
}

/// Famílias de fonte empacotadas em assets/fonts (OFL).
abstract final class NenuresFonts {
  static const String display = 'BricolageGrotesque';
  static const String body = 'IBMPlexSans';
  static const String mono = 'IBMPlexMono';
}

/// Limites do produto que aparecem na interface.
abstract final class NenuresLimits {
  static const int messageMaxChars = 1000;
  static const Duration keyLifetime = Duration(minutes: 10);
  static const Duration keyWarnAt = Duration(minutes: 1);
  static const Duration endArmWindow = Duration(seconds: 3);
  static const Duration backgroundLimit = Duration(seconds: 60);
  static const Duration messageAnimation = Duration(milliseconds: 180);
}
