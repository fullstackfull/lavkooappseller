import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The seller's health tier (new / good / watch / at_risk) as a colored pill,
/// using the app's semantic colors so it reads the same everywhere.
class TierBadgeWidget extends StatelessWidget {
  final String tier;
  final double fontSize;
  const TierBadgeWidget({super.key, required this.tier, this.fontSize = Dimensions.fontSizeSmall});

  static Color tierColor(BuildContext context, String tier) {
    switch (tier) {
      case 'good':
        return Theme.of(context).colorScheme.onTertiaryContainer;
      case 'watch':
        return Theme.of(context).colorScheme.tertiary;
      case 'at_risk':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = tierColor(context, tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(Dimensions.radiusPill),
        border: Border.all(color: color.withValues(alpha: .5), width: .8),
      ),
      child: Text(getTranslated('tier_$tier', context) ?? tier,
        style: robotoMedium.copyWith(color: color, fontSize: fontSize),
      ),
    );
  }
}
