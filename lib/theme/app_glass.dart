import 'dart:ui';

import 'package:flutter/material.dart';

/// The app's glass + elevation design tokens.
///
/// Registered as a [ThemeExtension] so every surface reads its blur, tint,
/// border and shadow from the active theme instead of hardcoding colours that
/// only work in one brightness.
@immutable
class AppGlass extends ThemeExtension<AppGlass> {
  /// Fill painted on top of the blurred backdrop.
  final Color tint;

  /// Slightly stronger fill for surfaces that must stay readable over photos.
  final Color solidTint;

  /// Hairline that gives a glass panel its edge.
  final Color border;

  /// Bright edge along the top of a panel, mimicking light catching glass.
  final Color highlight;

  /// Backdrop blur strength.
  final double blur;

  /// Three elevation tiers, from a resting card to a floating sheet.
  final List<BoxShadow> shadowSoft;
  final List<BoxShadow> shadowMedium;
  final List<BoxShadow> shadowStrong;

  /// Ambient wash painted behind the app shell.
  final List<Color> ambientColors;

  /// Brand gradient used on primary actions and hero numbers.
  final List<Color> brandGradient;

  /// Semantic gradients for status surfaces.
  final List<Color> successGradient;
  final List<Color> warningGradient;
  final List<Color> dangerGradient;
  final List<Color> infoGradient;

  /// Shimmer placeholder colours that follow the active brightness.
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppGlass({
    required this.tint,
    required this.solidTint,
    required this.border,
    required this.highlight,
    required this.blur,
    required this.shadowSoft,
    required this.shadowMedium,
    required this.shadowStrong,
    required this.ambientColors,
    required this.brandGradient,
    required this.successGradient,
    required this.warningGradient,
    required this.dangerGradient,
    required this.infoGradient,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const AppGlass lightTokens = AppGlass(
    tint: Color(0x99FFFFFF),
    solidTint: Color(0xF2FFFFFF),
    border: Color(0x40FFFFFF),
    highlight: Color(0xB3FFFFFF),
    blur: 18,
    shadowSoft: [
      BoxShadow(color: Color(0x0F0F291E), blurRadius: 12, offset: Offset(0, 4)),
      BoxShadow(color: Color(0x0A0F291E), blurRadius: 2, offset: Offset(0, 1)),
    ],
    shadowMedium: [
      BoxShadow(color: Color(0x1A0F291E), blurRadius: 24, offset: Offset(0, 10)),
      BoxShadow(color: Color(0x0D0F291E), blurRadius: 4, offset: Offset(0, 2)),
    ],
    shadowStrong: [
      BoxShadow(color: Color(0x260F291E), blurRadius: 40, offset: Offset(0, 18)),
      BoxShadow(color: Color(0x140F291E), blurRadius: 8, offset: Offset(0, 4)),
    ],
    ambientColors: [Color(0xFFE6F0EB), Color(0xFFF7F8FA), Color(0xFFFFF3E8)],
    brandGradient: [Color(0xFF063523), Color(0xFF1F7A55)],
    successGradient: [Color(0xFF12C98A), Color(0xFF04A66E)],
    warningGradient: [Color(0xFFFFC44D), Color(0xFFF58300)],
    dangerGradient: [Color(0xFFFF7B7B), Color(0xFFE84545)],
    infoGradient: [Color(0xFF458F70), Color(0xFF297F5B)],
    shimmerBase: Color(0xFFE7ECF2),
    shimmerHighlight: Color(0xFFF7FAFD),
  );

  static const AppGlass darkTokens = AppGlass(
    tint: Color(0x59FFFFFF),
    solidTint: Color(0xF2111B17),
    border: Color(0x1FFFFFFF),
    highlight: Color(0x33FFFFFF),
    blur: 22,
    shadowSoft: [
      BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
    shadowMedium: [
      BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 10)),
    ],
    shadowStrong: [
      BoxShadow(color: Color(0x99000000), blurRadius: 40, offset: Offset(0, 18)),
    ],
    ambientColors: [Color(0xFF0B1410), Color(0xFF09100D), Color(0xFF0C120F)],
    brandGradient: [Color(0xFF2C8F66), Color(0xFF197D54)],
    successGradient: [Color(0xFF2FD79B), Color(0xFF14A97A)],
    warningGradient: [Color(0xFFFFCE6B), Color(0xFFE99328)],
    dangerGradient: [Color(0xFFFF8F8F), Color(0xFFD94A4A)],
    infoGradient: [Color(0xFF508F75), Color(0xFF30795A)],
    shimmerBase: Color(0xFF18221D),
    shimmerHighlight: Color(0xFF202C27),
  );

  /// Tokens for the active theme, with a light-mode default so a widget used
  /// outside a themed subtree still renders sensibly.
  static AppGlass of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.extension<AppGlass>() ??
        (theme.brightness == Brightness.dark ? darkTokens : lightTokens);
  }

  /// The blur filter matching [blur].
  ImageFilter get blurFilter => ImageFilter.blur(sigmaX: blur, sigmaY: blur);

  /// A top-left to bottom-right sheen used as a glass panel's fill.
  LinearGradient get sheen => LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [highlight, tint],
      );

  @override
  AppGlass copyWith({
    Color? tint,
    Color? solidTint,
    Color? border,
    Color? highlight,
    double? blur,
    List<BoxShadow>? shadowSoft,
    List<BoxShadow>? shadowMedium,
    List<BoxShadow>? shadowStrong,
    List<Color>? ambientColors,
    List<Color>? brandGradient,
    List<Color>? successGradient,
    List<Color>? warningGradient,
    List<Color>? dangerGradient,
    List<Color>? infoGradient,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppGlass(
      tint: tint ?? this.tint,
      solidTint: solidTint ?? this.solidTint,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      blur: blur ?? this.blur,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      shadowMedium: shadowMedium ?? this.shadowMedium,
      shadowStrong: shadowStrong ?? this.shadowStrong,
      ambientColors: ambientColors ?? this.ambientColors,
      brandGradient: brandGradient ?? this.brandGradient,
      successGradient: successGradient ?? this.successGradient,
      warningGradient: warningGradient ?? this.warningGradient,
      dangerGradient: dangerGradient ?? this.dangerGradient,
      infoGradient: infoGradient ?? this.infoGradient,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  static List<Color> _lerpColors(List<Color> a, List<Color> b, double t) {
    final int length = a.length < b.length ? a.length : b.length;
    return List<Color>.generate(length, (i) => Color.lerp(a[i], b[i], t) ?? b[i]);
  }

  @override
  AppGlass lerp(ThemeExtension<AppGlass>? other, double t) {
    if (other is! AppGlass) return this;
    return AppGlass(
      tint: Color.lerp(tint, other.tint, t)!,
      solidTint: Color.lerp(solidTint, other.solidTint, t)!,
      border: Color.lerp(border, other.border, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      blur: lerpDouble(blur, other.blur, t) ?? blur,
      shadowSoft: BoxShadow.lerpList(shadowSoft, other.shadowSoft, t) ?? shadowSoft,
      shadowMedium: BoxShadow.lerpList(shadowMedium, other.shadowMedium, t) ?? shadowMedium,
      shadowStrong: BoxShadow.lerpList(shadowStrong, other.shadowStrong, t) ?? shadowStrong,
      ambientColors: _lerpColors(ambientColors, other.ambientColors, t),
      brandGradient: _lerpColors(brandGradient, other.brandGradient, t),
      successGradient: _lerpColors(successGradient, other.successGradient, t),
      warningGradient: _lerpColors(warningGradient, other.warningGradient, t),
      dangerGradient: _lerpColors(dangerGradient, other.dangerGradient, t),
      infoGradient: _lerpColors(infoGradient, other.infoGradient, t),
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }
}
