import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_severity_style.dart';
import 'package:syriacosmeticsmanger/features/reports/widgets/report_widgets.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// One market, as the platform owner reads it: whether it is open and legally
/// ready, what its orders are doing, what waits, what was asked back, what is
/// short, what is wrong, and the one thing that is not reported.
///
/// Every figure is the market's own. Nothing here is added to another market's,
/// and there is no money on it: where sales would be, the card says why not.
class PlatformMarketCard extends StatelessWidget {
  final PlatformMarketOverview overview;

  /// What the platform says about the market itself; null until it has been read.
  final PlatformMarketModel? market;

  /// Opens the alerts of this market. Null where they cannot be opened from here:
  /// the counts are then only read.
  final VoidCallback? onOpenAlerts;

  const PlatformMarketCard({super.key, required this.overview, this.market, this.onOpenAlerts});

  @override
  Widget build(BuildContext context) {
    final PlatformMarketModel? facts = market;

    return ReportCardWidget(
      children: [
        _Header(code: overview.market, currency: overview.storefrontCurrency),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Wrap(spacing: Dimensions.paddingSizeExtraSmall, runSpacing: Dimensions.paddingSizeExtraSmall, children: [
          _statusTag(context, overview.active, getTranslated('platform_admin_market_active', context)!,
              getTranslated('platform_admin_market_inactive', context)!),
          if (facts != null) ...[
            _statusTag(context, facts.legalReady, getTranslated('platform_admin_legal_ready', context)!,
                getTranslated('platform_admin_legal_not_ready', context)!),
            if (!facts.storefrontEnabled)
              _tag(context, getTranslated('platform_admin_storefronts_off', context)!, Theme.of(context).hintColor),
          ],
        ]),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        PlatformFiguresBlock(figures: overview.figures),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        _AlertCounts(counts: overview.alerts, onOpen: onOpenAlerts),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        PlatformSalesNote(sales: overview.figures.sales),
      ],
    );
  }

  Widget _statusTag(BuildContext context, bool isGood, String good, String bad) =>
      _tag(context, isGood ? good : bad, isGood ? Colors.green.shade700 : Colors.orange.shade800,
          icon: isGood ? Icons.check_circle_outline : Icons.error_outline);
}

/// The figures a market and the bucket of orders without a market have in common.
class PlatformFiguresBlock extends StatelessWidget {
  final PlatformFigures figures;

  const PlatformFiguresBlock({super.key, required this.figures});

  @override
  Widget build(BuildContext context) {
    final PlatformOrderFigures orders = figures.orders;
    final List<MapEntry<String, int>> statuses =
        orders.byStatus.entries.where((MapEntry<String, int> entry) => entry.value > 0).toList();
    final DateTime? latestAt = orders.latestAt;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PlatformFigureRow(
          label: getTranslated('platform_admin_orders_in_window', context)!,
          value: '${orders.total}',
          emphasised: true),
      if (statuses.isNotEmpty) ...[
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Wrap(
          spacing: Dimensions.paddingSizeExtraSmall,
          runSpacing: Dimensions.paddingSizeExtraSmall,
          children: statuses
              .map((MapEntry<String, int> status) => _tag(
                  context,
                  '${PlatformAdminTexts.orderStatus(context, status.key)} ${status.value}',
                  Theme.of(context).primaryColor))
              .toList(),
        ),
      ],
      if (latestAt != null)
        PlatformFigureRow(
            label: getTranslated('platform_admin_latest_order', context)!, value: PlatformAdminTexts.moment(latestAt)),
      PlatformFigureRow(
          label: getTranslated('platform_admin_pending_fulfilment', context)!, value: '${figures.pendingFulfilment}'),
      PlatformFigureRow(
          label: getTranslated('platform_admin_refund_requests', context)!, value: '${figures.refundRequests}'),
      PlatformFigureRow(
          label: getTranslated('platform_admin_refund_requests_pending', context)!,
          value: '${figures.refundRequestsPending}'),
      PlatformFigureRow(label: getTranslated('platform_admin_stock_zero', context)!, value: '${figures.stockZero}'),
      PlatformFigureRow(label: getTranslated('platform_admin_stock_low', context)!, value: '${figures.stockLow}'),
    ]);
  }
}

/// A label and a figure on one line. The label wraps, where the reports' row cuts
/// it short, because at a large text size a cut label is a figure nobody can name.
class PlatformFigureRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasised;

  const PlatformFigureRow({super.key, required this.label, required this.value, this.emphasised = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Text(label,
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: (emphasised ? robotoBold : robotoMedium)
                .copyWith(fontSize: emphasised ? Dimensions.fontSizeLarge : Dimensions.fontSizeSmall),
          ),
        ),
      ]),
    );
  }
}

/// Where sales would be, and why they are not.
class PlatformSalesNote extends StatelessWidget {
  final PlatformSalesFigure sales;

  const PlatformSalesNote({super.key, required this.sales});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline, size: Dimensions.iconSizeSmall, color: Theme.of(context).hintColor),
      const SizedBox(width: Dimensions.paddingSizeExtraSmall),
      Expanded(
        child: Text(
          PlatformAdminTexts.sales(context, sales),
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
        ),
      ),
    ]);
  }
}

/// The orders that belong to no single market, kept apart from every market's own.
class PlatformUnattributedCard extends StatelessWidget {
  final PlatformUnattributedOverview unattributed;

  const PlatformUnattributedCard({super.key, required this.unattributed});

  @override
  Widget build(BuildContext context) {
    return ReportCardWidget(
      children: [
        Row(children: [
          Icon(Icons.help_outline, size: Dimensions.iconSizeMedium, color: Theme.of(context).hintColor),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Text(getTranslated('platform_admin_unattributed_title', context)!,
                style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
          ),
        ]),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(
          getTranslated('platform_admin_unattributed_explanation', context)!,
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        PlatformFiguresBlock(figures: unattributed.figures),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        PlatformSalesNote(sales: unattributed.figures.sales),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String code;
  final String? currency;

  const _Header({required this.code, this.currency});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child:
            Wrap(spacing: Dimensions.paddingSizeExtraSmall, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(PlatformAdminTexts.marketName(context, code),
              style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
          Text(code,
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
        ]),
      ),
      if (currency != null)
        Text(currency!,
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
    ]);
  }
}

class _AlertCounts extends StatelessWidget {
  final PlatformAlertCounts counts;
  final VoidCallback? onOpen;

  const _AlertCounts({required this.counts, this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (counts.total == 0) {
      return Row(children: [
        Icon(Icons.notifications_none_rounded, size: Dimensions.iconSizeSmall, color: Theme.of(context).hintColor),
        const SizedBox(width: Dimensions.paddingSizeExtraSmall),
        Expanded(
          child: Text(getTranslated('platform_admin_alerts_none', context)!,
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
        ),
      ]);
    }

    final Widget tags =
        Wrap(spacing: Dimensions.paddingSizeExtraSmall, runSpacing: Dimensions.paddingSizeExtraSmall, children: [
      for (final (String severity, int count) in <(String, int)>[
        (PlatformSeverity.critical, counts.critical),
        (PlatformSeverity.warning, counts.warning),
        (PlatformSeverity.info, counts.info),
      ])
        if (count > 0)
          _tag(context, '${PlatformAdminTexts.severity(context, severity)} $count',
              PlatformSeverityStyle.color(context, severity),
              icon: PlatformSeverityStyle.icon(severity)),
    ]);
    if (onOpen == null) return tags;

    return Semantics(
      button: true,
      hint: getTranslated('platform_admin_open_alerts', context),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          child: Row(children: [
            Expanded(child: tags),
            Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
          ]),
        ),
      ),
    );
  }
}

/// A small label with a colour that says how it stands, and words that say it too.
Widget _tag(BuildContext context, String label, Color color, {IconData? icon}) => Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeOrder),
      decoration:
          BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(Dimensions.radiusPill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: Dimensions.iconSizeSmall, color: color),
          const SizedBox(width: Dimensions.paddingSizeVeryTiny),
        ],
        Flexible(
            child: Text(label, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color))),
      ]),
    );
