import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/glass/glass_container.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

class WalletCardWidget extends StatelessWidget {
  final String? amount;
  final String? title;
  final Color? color;
  final IconData? icon;

  const WalletCardWidget({super.key, this.amount, this.title, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = color ?? theme.primaryColor;

    return GlassContainer(
      width: 158,
      // Blur is off here: these cards sit in a horizontally scrolling row, and
      // a BackdropFilter per card is the most expensive thing on the screen.
      enableBlur: false,
      elevation: GlassElevation.medium,
      borderRadius: Dimensions.radiusLarge,
      margin: const EdgeInsetsDirectional.only(end: Dimensions.paddingSizeSmall),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSize,
        vertical: Dimensions.paddingSize,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Dimensions.radiusTiny),
              ),
              child: Icon(icon ?? Icons.account_balance_wallet_rounded,
                  size: Dimensions.iconSizeDefault, color: accent),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                amount ?? '',
                maxLines: 1,
                style: robotoBold.copyWith(
                  color: accent,
                  fontSize: Dimensions.fontSizeLarge,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: robotoRegular.copyWith(
                color: theme.hintColor,
                fontSize: Dimensions.fontSizeSmall,
                height: 1.35,
              ),
            ),
            // Thin progress-style underline ties the card to its semantic colour.
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Container(
              height: 3,
              width: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.25)]),
                borderRadius: BorderRadius.circular(Dimensions.radiusPill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
