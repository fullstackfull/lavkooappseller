import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/analytics_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/seller_center_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/screens/scorecard_screen.dart';
import 'package:syriacosmeticsmanger/features/seller_center/widgets/tier_badge_widget.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The seller-center summary on the home tab: health tier, verification
/// standing, withdrawable ledger balance and open SLA breaches — one glance,
/// tap for the full scorecard.
class SellerCenterCardWidget extends StatelessWidget {
  const SellerCenterCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SellerCenterController>(
      builder: (context, sellerCenter, _) {
        final SellerCenterOverviewModel? overview = sellerCenter.overview;
        if (overview == null) {
          return const SizedBox();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
          child: Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: InkWell(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScorecardScreen())),
              child: Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: .08)),
                  boxShadow: [
                    BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: .05),
                        spreadRadius: -3, blurRadius: 12, offset: Offset.fromDirection(0, 6)),
                  ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(getTranslated('seller_center', context)!,
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge,
                          color: Theme.of(context).textTheme.bodyLarge?.color),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    TierBadgeWidget(tier: overview.performance?.tier ?? 'new'),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: Dimensions.fontSizeDefault,
                        color: Theme.of(context).hintColor),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeDefault),

                  Row(children: [
                    _OverviewStatWidget(
                      title: 'verification',
                      value: getTranslated(overview.verificationStatus ?? 'unverified', context) ?? '',
                      color: _verificationColor(context, overview.verificationStatus),
                    ),
                    _OverviewStatWidget(
                      title: 'withdrawable_balance',
                      value: PriceConverter.convertPrice(context, overview.finance?.withdrawable ?? 0),
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    _OverviewStatWidget(
                      title: 'open_sla_breaches',
                      value: '${overview.openSlaBreachCount}',
                      color: overview.openSlaBreachCount > 0
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ]),

                  // Only surfaces when something is actually waiting, so the card
                  // stays quiet on a day with nothing to do.
                  if (sellerCenter.activities?.hasAny ?? false) ...[
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                    _ActivitiesStripWidget(activities: sellerCenter.activities!),
                  ],
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Color? _verificationColor(BuildContext context, String? status) {
    switch (status) {
      case 'verified':
      case 'not_required':
        return Theme.of(context).colorScheme.onTertiaryContainer;
      case 'pending':
        return Theme.of(context).colorScheme.tertiary;
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).hintColor;
    }
  }
}

class _ActivitiesStripWidget extends StatelessWidget {
  final SellerActivitiesModel activities;
  const _ActivitiesStripWidget({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Row(children: [
        Icon(Icons.notifications_active_outlined,
            size: Dimensions.iconSizeSmall, color: Theme.of(context).colorScheme.tertiary),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(
          child: Text(_summary(context),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).colorScheme.tertiary)),
        ),
      ]),
    );
  }

  String _summary(BuildContext context) {
    final List<String> parts = [];
    if (activities.newOrderCount > 0) {
      parts.add('${activities.newOrderCount} ${getTranslated('new_orders_waiting', context)}');
    }
    if (activities.restockProductCount > 0) {
      parts.add('${activities.restockProductCount} ${getTranslated('products_await_restock', context)}');
    }
    return parts.join('  •  ');
  }
}

class _OverviewStatWidget extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;
  const _OverviewStatWidget({required this.title, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(getTranslated(title, context)!,
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(value,
          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: color),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }
}
