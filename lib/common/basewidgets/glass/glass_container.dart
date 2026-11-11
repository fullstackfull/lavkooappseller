import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/theme/app_glass.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';

/// Frosted-glass surface: a real backdrop blur, a translucent sheen, a hairline
/// border and a soft drop shadow.
///
/// Blur is the expensive part, so [enableBlur] can be turned off for surfaces
/// drawn many times in a scrolling list — the panel then falls back to the
/// opaque [AppGlass.solidTint] and still matches the rest of the design.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double? width;
  final double? height;
  final bool enableBlur;
  final GlassElevation elevation;
  final Color? tint;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Border? border;
  final AlignmentGeometry? alignment;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = Dimensions.radiusLarge,
    this.width,
    this.height,
    this.enableBlur = true,
    this.elevation = GlassElevation.soft,
    this.tint,
    this.gradient,
    this.onTap,
    this.border,
    this.alignment,
  });

  List<BoxShadow> _shadow(AppGlass glass) {
    switch (elevation) {
      case GlassElevation.none:
        return const <BoxShadow>[];
      case GlassElevation.soft:
        return glass.shadowSoft;
      case GlassElevation.medium:
        return glass.shadowMedium;
      case GlassElevation.strong:
        return glass.shadowStrong;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppGlass glass = AppGlass.of(context);
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    Widget surface = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding ?? const EdgeInsets.all(Dimensions.paddingSize),
      decoration: BoxDecoration(
        color: gradient == null ? (tint ?? (enableBlur ? glass.tint : glass.solidTint)) : null,
        gradient: gradient,
        borderRadius: radius,
        border: border ?? Border.all(color: glass.border, width: 1),
      ),
      child: child,
    );

    if (enableBlur) {
      surface = BackdropFilter(filter: glass.blurFilter, child: surface);
    }

    Widget panel = DecoratedBox(
      // The shadow lives outside the clip so the blur cannot eat it.
      decoration: BoxDecoration(borderRadius: radius, boxShadow: _shadow(glass)),
      child: ClipRRect(borderRadius: radius, child: surface),
    );

    if (onTap != null) {
      panel = Stack(children: [
        panel,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(borderRadius: radius, onTap: onTap, child: const SizedBox.expand()),
          ),
        ),
      ]);
    }

    if (margin != null) {
      panel = Padding(padding: margin!, child: panel);
    }
    return panel;
  }
}

enum GlassElevation { none, soft, medium, strong }

/// The ambient gradient wash the glass surfaces sit on. Without something with
/// colour behind it, a blurred panel has nothing to blur.
class AmbientBackground extends StatelessWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final AppGlass glass = AppGlass.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: glass.ambientColors,
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// A soft coloured orb used behind hero sections to give the blur something
/// interesting to pick up. Purely decorative.
class GlassOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const GlassOrb({super.key, required this.color, this.size = 220, this.opacity = 0.35});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: size / 4, sigmaY: size / 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: opacity),
            ),
          ),
        ),
      ),
    );
  }
}
