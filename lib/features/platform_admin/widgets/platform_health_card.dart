import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_health_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_market_card.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// One market's operational health, or the rows whose market the platform does
/// not record (L-09).
///
/// Three groups, never added together: the payment attempts that never came
/// back, the sales channels, and the carriers. Each figure carries the SERVER'S
/// sentence about what it means, shown under it, so the screen explains a number
/// in the words of the thing that counted it.
///
/// No figure is coloured and none is called bad: the thresholds belong to
/// whoever is watching, and this card has no ruling on when a count becomes an
/// incident. The border marks a card with something on it; the figures say what,
/// drawn the way every other figure of this shell is drawn.
class PlatformHealthCard extends StatelessWidget {
  final PlatformMarketHealth health;

  /// What each figure means, keyed by its path, as the server sent it.
  final Map<String, String> means;

  const PlatformHealthCard({super.key, required this.health, this.means = const <String, String>{}});

  @override
  Widget build(BuildContext context) {
    final Color border = health.needsAttention
        ? Theme.of(context).colorScheme.error.withValues(alpha: .35)
        : Theme.of(context).hintColor.withValues(alpha: .2);

    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          _figure(
            context,
            label: getTranslated('platform_admin_stuck_payments', context)!,
            value: health.payments.stuckAttempts,
            meaning: means['payments.stuck_attempts'],
          ),
          _figure(
            context,
            label: getTranslated('platform_admin_reconciliation_breaks', context)!,
            value: health.payments.reconciliationBreaks,
            meaning: means['payments.reconciliation_breaks'],
          ),
          const Divider(height: Dimensions.paddingSizeLarge),
          _group(
            context,
            heading: getTranslated('platform_admin_sales_channels', context)!,
            connections: health.channels.accounts,
            connectionsLabel: getTranslated('platform_admin_accounts', context)!,
            failing: health.channels.failingResources,
            failingMeaning: means['integrations.channels.failing_resources'],
            late: health.channels.lateResources,
            lateMeaning: means['integrations.channels.late_resources'],
            lastSuccessAt: health.channels.lastSuccessAt,
          ),
          const Divider(height: Dimensions.paddingSizeLarge),
          _group(
            context,
            heading: getTranslated('platform_admin_carriers', context)!,
            connections: health.carriers.connections,
            connectionsLabel: getTranslated('platform_admin_connections', context)!,
            failing: health.carriers.failingCapabilities,
            failingMeaning: means['integrations.carriers.failing_capabilities'],
            late: health.carriers.lateCapabilities,
            lateMeaning: means['integrations.carriers.late_capabilities'],
            lastSuccessAt: health.carriers.lastSuccessAt,
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context) {
    final String name = health.isUnattributed
        ? getTranslated('platform_admin_unattributed', context)!
        : PlatformAdminTexts.marketName(context, health.market!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
        if (health.isUnattributed && means['unattributed'] != null)
          Padding(
            padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
            child: Text(
              means['unattributed']!,
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
            ),
          ),
        if (!health.isUnattributed && health.legalEntity != null)
          Padding(
            padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
            child: Text(
              health.legalEntity!,
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
            ),
          ),
      ],
    );
  }

  Widget _group(
    BuildContext context, {
    required String heading,
    required int connections,
    required String connectionsLabel,
    required int failing,
    required String? failingMeaning,
    required int late,
    required String? lateMeaning,
    required DateTime? lastSuccessAt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        _figure(context, label: connectionsLabel, value: connections),
        _figure(
          context,
          label: getTranslated('platform_admin_failing', context)!,
          value: failing,
          meaning: failingMeaning,
        ),
        _figure(context, label: getTranslated('platform_admin_late', context)!, value: late, meaning: lateMeaning),
        Padding(
          padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
          child: Text(
            lastSuccessAt == null
                ? getTranslated('platform_admin_never_succeeded', context)!
                : '${getTranslated('platform_admin_last_success', context)!}: ${PlatformAdminTexts.moment(lastSuccessAt)}',
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
          ),
        ),
      ],
    );
  }

  /// One count, drawn the way every other figure of this shell is drawn
  /// (`PlatformFigureRow`), with the server's sentence under it when there is
  /// one.
  ///
  /// No colour and no word for how bad a number is: the thresholds belong to
  /// whoever is watching, and this card has no ruling on when a count becomes
  /// an incident. The border says there is something to look at; the figures
  /// say what.
  Widget _figure(BuildContext context, {required String label, required int value, String? meaning}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlatformFigureRow(label: label, value: '$value'),
        if (meaning != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
            child: Text(
              meaning,
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
            ),
          ),
      ],
    );
  }
}
