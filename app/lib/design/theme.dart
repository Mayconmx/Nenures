import 'dart:ui' show FontFeature, FontVariation, lerpDouble;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Cores do design system que o [ColorScheme] do Material não tem.
@immutable
class NenuresColors extends ThemeExtension<NenuresColors> {
  const NenuresColors({
    required this.surfaceSunk,
    required this.inkMuted,
    required this.line,
    required this.lineStrong,
    required this.bubbleMine,
    required this.onBubbleMine,
    required this.bubbleTheirs,
    required this.keyInk,
    required this.danger,
    required this.onDanger,
    required this.warn,
  });

  factory NenuresColors.from(NenuresPalette p) => NenuresColors(
    surfaceSunk: p.surfaceSunk,
    inkMuted: p.inkMuted,
    line: p.line,
    lineStrong: p.lineStrong,
    bubbleMine: p.bubbleMine,
    onBubbleMine: p.onBubbleMine,
    bubbleTheirs: p.bubbleTheirs,
    keyInk: p.keyInk,
    danger: p.danger,
    onDanger: p.onDanger,
    warn: p.warn,
  );

  final Color surfaceSunk;
  final Color inkMuted;
  final Color line;
  final Color lineStrong;
  final Color bubbleMine;
  final Color onBubbleMine;
  final Color bubbleTheirs;
  final Color keyInk;
  final Color danger;
  final Color onDanger;
  final Color warn;

  @override
  NenuresColors copyWith({
    Color? surfaceSunk,
    Color? inkMuted,
    Color? line,
    Color? lineStrong,
    Color? bubbleMine,
    Color? onBubbleMine,
    Color? bubbleTheirs,
    Color? keyInk,
    Color? danger,
    Color? onDanger,
    Color? warn,
  }) => NenuresColors(
    surfaceSunk: surfaceSunk ?? this.surfaceSunk,
    inkMuted: inkMuted ?? this.inkMuted,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    bubbleMine: bubbleMine ?? this.bubbleMine,
    onBubbleMine: onBubbleMine ?? this.onBubbleMine,
    bubbleTheirs: bubbleTheirs ?? this.bubbleTheirs,
    keyInk: keyInk ?? this.keyInk,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    warn: warn ?? this.warn,
  );

  @override
  NenuresColors lerp(NenuresColors? other, double t) {
    if (other == null) return this;
    return NenuresColors(
      surfaceSunk: Color.lerp(surfaceSunk, other.surfaceSunk, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      bubbleMine: Color.lerp(bubbleMine, other.bubbleMine, t)!,
      onBubbleMine: Color.lerp(onBubbleMine, other.onBubbleMine, t)!,
      bubbleTheirs: Color.lerp(bubbleTheirs, other.bubbleTheirs, t)!,
      keyInk: Color.lerp(keyInk, other.keyInk, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
    );
  }
}

/// Estilos de texto do design system fora do [TextTheme].
@immutable
class NenuresText extends ThemeExtension<NenuresText> {
  const NenuresText({
    required this.wordmark,
    required this.key,
    required this.timer,
    required this.label,
    required this.caption,
  });

  final TextStyle wordmark;
  final TextStyle key;
  final TextStyle timer;
  final TextStyle label;
  final TextStyle caption;

  @override
  NenuresText copyWith({
    TextStyle? wordmark,
    TextStyle? key,
    TextStyle? timer,
    TextStyle? label,
    TextStyle? caption,
  }) => NenuresText(
    wordmark: wordmark ?? this.wordmark,
    key: key ?? this.key,
    timer: timer ?? this.timer,
    label: label ?? this.label,
    caption: caption ?? this.caption,
  );

  @override
  NenuresText lerp(NenuresText? other, double t) {
    if (other == null) return this;
    return NenuresText(
      wordmark: TextStyle.lerp(wordmark, other.wordmark, t)!,
      key: TextStyle.lerp(key, other.key, t)!,
      timer: TextStyle.lerp(timer, other.timer, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
    );
  }
}

/// Atalhos: `context.nColors`, `context.nText`.
extension NenuresThemeContext on BuildContext {
  NenuresColors get nColors => Theme.of(this).extension<NenuresColors>()!;
  NenuresText get nText => Theme.of(this).extension<NenuresText>()!;
}

/// Estilo de texto com peso aplicado também ao eixo `wght` das fontes variáveis.
TextStyle _style({
  required String family,
  required double size,
  required double lineHeight,
  required int weight,
  required Color color,
  double letterSpacingEm = 0,
  double? opticalSize,
  List<FontFeature>? features,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [
      FontVariation.weight(weight.toDouble()),
      if (opticalSize != null) FontVariation.opticalSize(opticalSize),
    ],
    letterSpacing: lerpDouble(0, size, letterSpacingEm),
    color: color,
    fontFeatures: features,
  );
}

ThemeData buildNenuresTheme(Brightness brightness) {
  final p = brightness == Brightness.light
      ? NenuresPalette.light
      : NenuresPalette.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: p.danger,
    onError: p.onDanger,
    surface: p.surface000,
    onSurface: p.ink,
    onSurfaceVariant: p.inkMuted,
    surfaceContainerLowest: p.surfaceSunk,
    surfaceContainerLow: p.surface100,
    surfaceContainer: p.surface100,
    surfaceContainerHigh: p.surface100,
    surfaceContainerHighest: p.surface100,
    outline: p.lineStrong,
    outlineVariant: p.line,
  );

  final display = _style(
    family: NenuresFonts.display,
    size: 34,
    lineHeight: 37,
    weight: 700,
    letterSpacingEm: -0.02,
    opticalSize: 34,
    color: p.ink,
  );
  final title = _style(
    family: NenuresFonts.display,
    size: 22,
    lineHeight: 28,
    weight: 500,
    letterSpacingEm: -0.01,
    opticalSize: 22,
    color: p.ink,
  );
  final body = _style(
    family: NenuresFonts.body,
    size: 15,
    lineHeight: 22,
    weight: 400,
    color: p.ink,
  );
  final bodyStrong = _style(
    family: NenuresFonts.body,
    size: 15,
    lineHeight: 22,
    weight: 500,
    color: p.ink,
  );
  final caption = _style(
    family: NenuresFonts.body,
    size: 13,
    lineHeight: 18,
    weight: 400,
    color: p.inkMuted,
  );

  final textTheme = TextTheme(
    displayLarge: display,
    titleLarge: title,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: bodyStrong,
    labelMedium: bodyStrong.copyWith(fontSize: 13, height: 18 / 13),
  );

  const tabular = [FontFeature.tabularFigures()];
  final nText = NenuresText(
    wordmark: _style(
      family: NenuresFonts.display,
      size: 22,
      lineHeight: 28,
      weight: 700,
      letterSpacingEm: -0.02,
      opticalSize: 22,
      color: p.ink,
    ),
    key: _style(
      family: NenuresFonts.mono,
      size: 19,
      lineHeight: 30,
      weight: 400,
      color: p.keyInk,
    ),
    timer: _style(
      family: NenuresFonts.mono,
      size: 13,
      lineHeight: 18,
      weight: 400,
      color: p.inkMuted,
      features: tabular,
    ),
    label: _style(
      family: NenuresFonts.mono,
      size: 11,
      lineHeight: 14,
      weight: 500,
      letterSpacingEm: 0.08,
      color: p.inkMuted,
    ),
    caption: caption,
  );

  const minSize = Size(64, NenuresSize.touchMin);
  final roundedMd = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(NenuresRadius.md),
  );
  const pad = EdgeInsets.symmetric(
    horizontal: NenuresSpace.s4,
    vertical: NenuresSpace.s3,
  );

  OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(NenuresRadius.md),
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.surface000,
    fontFamily: NenuresFonts.body,
    textTheme: textTheme,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: NoSplash.splashFactory,
    extensions: [NenuresColors.from(p), nText],
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minSize,
        padding: pad,
        shape: roundedMd,
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        textStyle: bodyStrong,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minSize,
        padding: pad,
        shape: roundedMd,
        backgroundColor: p.surface100,
        foregroundColor: p.ink,
        side: BorderSide(color: p.line),
        textStyle: bodyStrong,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minSize,
        padding: pad,
        shape: roundedMd,
        foregroundColor: p.ink,
        textStyle: bodyStrong,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(NenuresSize.touchMin),
        foregroundColor: p.ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface100,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: NenuresSpace.s4,
        vertical: NenuresSpace.s3,
      ),
      hintStyle: body.copyWith(color: p.inkMuted),
      labelStyle: body.copyWith(color: p.inkMuted),
      errorStyle: caption.copyWith(
        color: p.danger,
        fontSize: 14,
        height: 20 / 14,
      ),
      border: inputBorder(p.lineStrong),
      enabledBorder: inputBorder(p.lineStrong),
      focusedBorder: inputBorder(p.accent, NenuresSize.focusRing),
      errorBorder: inputBorder(p.danger),
      focusedErrorBorder: inputBorder(p.danger, NenuresSize.focusRing),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: body.copyWith(color: p.surface000),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
