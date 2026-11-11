import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/glass/glass_container.dart';
import 'package:syriacosmeticsmanger/theme/app_glass.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Semantic tone for a metric, kept separate from the brand accent so status
/// still reads at a glance in both themes.
enum StatTone { brand, success, warning, danger, info, neutral }

extension _ToneColors on StatTone {
  List<Color> gradient(AppGlass glass, ThemeData theme) {
    switch (this) {
      case StatTone.brand:   return glass.brandGradient;
      case StatTone.success: return glass.successGradient;
      case StatTone.warning: return glass.warningGradient;
      case StatTone.danger:  return glass.dangerGradient;
      case StatTone.info:    return glass.infoGradient;
      case StatTone.neutral: return <Color>[theme.hintColor, theme.hintColor];
    }
  }
}

/// A metric tile: a large value, a quiet label, an optional trend, and a tinted
/// icon chip that carries the semantic colour.
class GlassStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final StatTone tone;
  final String? trend;
  final bool trendIsPositive;
  final VoidCallback? onTap;
  final double? width;

  const GlassStatCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.tone = StatTone.brand,
    this.trend,
    this.trendIsPositive = true,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppGlass glass = AppGlass.of(context);
    final List<Color> colors = tone.gradient(glass, theme);

    return GlassContainer(
      width: width,
      onTap: onTap,
      elevation: GlassElevation.medium,
      borderRadius: Dimensions.radiusLarge,
      padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(Dimensions.radiusTiny),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: Dimensions.iconSizeDefault, color: Colors.white),
              ),
            const Spacer(),
            if (trend != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeExtraSmall,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: (trendIsPositive ? glass.successGradient.last : glass.dangerGradient.last)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Dimensions.radiusPill),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    trendIsPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: Dimensions.iconSizeExtraSmall,
                    color: trendIsPositive ? glass.successGradient.last : glass.dangerGradient.last,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    trend!,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: trendIsPositive ? glass.successGradient.last : glass.dangerGradient.last,
                    ),
                  ),
                ]),
              ),
          ]),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: robotoBold.copyWith(
                fontSize: Dimensions.fontSizeExtraLargeTwenty,
                color: theme.textTheme.bodyLarge?.color,
                // Keeps digits from jittering as values update.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero panel at the top of a screen: a full-bleed brand gradient with a
/// blurred orb behind it and a headline figure.
class GlassHeroPanel extends StatelessWidget {
  final String title;
  final String value;
  final String? caption;
  final IconData? icon;
  final List<Widget> actions;
  final StatTone tone;

  const GlassHeroPanel({
    super.key,
    required this.title,
    required this.value,
    this.caption,
    this.icon,
    this.actions = const <Widget>[],
    this.tone = StatTone.brand,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppGlass glass = AppGlass.of(context);
    final List<Color> colors = tone.gradient(glass, theme);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Dimensions.radiusXLarge),
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: colors,
                ),
              ),
            ),
          ),
          const PositionedDirectional(
            top: -60,
            end: -40,
            child: GlassOrb(color: Colors.white, size: 180, opacity: 0.22),
          ),
          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: Dimensions.iconSizeMedium),
                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: robotoMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: Dimensions.fontSizeDefault,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: robotoBold.copyWith(
                      color: Colors.white,
                      fontSize: Dimensions.fontSizeWallet,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: robotoRegular.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSize),
                  Row(children: actions),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
