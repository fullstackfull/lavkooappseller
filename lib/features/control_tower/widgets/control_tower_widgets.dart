import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/action_center/widgets/action_center_widgets.dart';
import 'package:syriacosmeticsmanger/features/control_tower/domain/models/control_tower_models.dart';
import 'package:syriacosmeticsmanger/features/reports/widgets/report_widgets.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// One issue in the tower, with what can be done about it.
///
/// Carries two things the Action Center's card does not: how many records it is
/// about, and whether the platform promoted it because nobody answered. A
/// severity that changed on its own has to say so, or a seller sees a problem
/// they remember as medium sitting under "critical" with no explanation.
class IssueCardWidget extends StatelessWidget {
  final IssueModel issue;
  final bool isUpdating;
  final VoidCallback? onTap;
  final ValueChanged<String>? onStatus;

  const IssueCardWidget({
    super.key,
    required this.issue,
    this.isUpdating = false,
    this.onTap,
    this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = InsightSeverity.color(context, issue.severity);

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: color.withValues(alpha: .25)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 4, height: 40,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Dimensions.radiusPill)),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(getTranslated(issue.title, context) ?? issue.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: color)),
                  ),
                  // The number that turns "1 issue" into something actionable.
                  if (issue.affectedCount > 1)
                    Text('${issue.affectedCount}',
                        style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: color)),
                ]),
                if (issue.body != null && issue.body!.isNotEmpty)
                  Text(issue.body!,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),

                const SizedBox(height: 2),
                Wrap(spacing: Dimensions.paddingSizeExtraSmall, runSpacing: 2, children: [
                  if (issue.impact != null && issue.impact! > 0)
                    _tag(context, PriceConverter.convertPrice(context, issue.impact), color),
                  if (issue.dueAt != null)
                    _tag(
                      context,
                      issue.isOverdue
                          ? getTranslated('overdue', context) ?? ''
                          : '${getTranslated('due', context) ?? ''} ${DateConverter.isoStringToLocalDateOnly(issue.dueAt!)}',
                      issue.isOverdue ? Theme.of(context).colorScheme.error : Theme.of(context).hintColor,
                    ),
                  // Promoted because nobody answered it, said plainly.
                  if (issue.wasEscalated)
                    _tag(context, getTranslated('escalated', context) ?? '', Colors.deepOrange.shade700),
                  if (issue.status != 'open')
                    _tag(context, getTranslated('issue_status_${issue.status}', context) ?? issue.status,
                        Theme.of(context).primaryColor),
                ]),
              ]),
            ),

            if (onStatus != null)
              isUpdating
                  ? const Padding(
                      padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                      child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : PopupMenuButton<String>(
                      onSelected: onStatus,
                      tooltip: getTranslated('update_status', context),
                      icon: Icon(Icons.more_vert, size: 18, color: Theme.of(context).hintColor),
                      itemBuilder: (context) => [
                        // Only what a seller may set. Resolution is the detector's to declare, and
                        // offering it here would make the list a matter of opinion.
                        for (final String status in ['acknowledged', 'in_progress', 'waiting', 'open'])
                          PopupMenuItem<String>(
                            value: status,
                            child: Text(getTranslated('issue_status_$status', context) ?? status),
                          ),
                      ],
                    ),
          ]),
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraSmall, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        child: Text(label,
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
      );
}

/// The day, in numbers that were counted.
///
/// A change against a day with nothing in it is shown as a dash rather than a
/// percentage, because the server sends null there and inventing one on the
/// client would undo the point of it being null.
class DailyBriefingWidget extends StatelessWidget {
  final DailyBriefingModel briefing;
  const DailyBriefingWidget({super.key, required this.briefing});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(getTranslated('today', context) ?? '',
          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
      const SizedBox(height: Dimensions.paddingSizeSmall),

      Row(children: [
        ReportMetricWidget(title: 'orders', value: '${briefing.orders}'),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        ReportMetricWidget(
          title: 'revenue',
          value: PriceConverter.convertPrice(context, briefing.revenue),
        ),
      ]),
      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
      Row(children: [
        _change(context, 'orders', briefing.ordersChange),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        _change(context, 'revenue', briefing.revenueChange),
      ]),

      const SizedBox(height: Dimensions.paddingSizeSmall),
      ReportCardWidget(children: [
        ReportRowWidget(
          label: 'awaiting_shipment', value: '${briefing.awaitingShipment}',
          valueColor: briefing.awaitingShipment > 0 ? Theme.of(context).primaryColor : null,
        ),
        ReportRowWidget(
          label: 'sla_at_risk', value: '${briefing.slaAtRisk}',
          valueColor: briefing.slaAtRisk > 0 ? Theme.of(context).colorScheme.error : null,
        ),
        ReportRowWidget(label: 'returns_to_answer', value: '${briefing.returnsToAnswer}'),
        ReportRowWidget(label: 'low_stock_products', value: '${briefing.lowStockProducts}'),
        ReportRowWidget(
          label: 'withdrawable_balance',
          value: PriceConverter.convertPrice(context, briefing.withdrawable),
        ),
      ]),
    ]);
  }

  Widget _change(BuildContext context, String label, double? percent) {
    // Null means the previous day had nothing to compare against. A dash says so;
    // a number here would be one the server deliberately refused to produce.
    final String text = percent == null
        ? '—'
        : '${percent > 0 ? '+' : ''}${percent.toStringAsFixed(percent.abs() < 10 ? 1 : 0)}%';

    final Color color = percent == null || percent == 0
        ? Theme.of(context).hintColor
        : (percent > 0 ? Colors.green.shade700 : Theme.of(context).colorScheme.error);

    return Expanded(
      child: Text('${getTranslated(label, context) ?? label} $text',
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
    );
  }
}

/// How each domain is doing, at a glance.
class DomainHealthGridWidget extends StatelessWidget {
  final List<DomainHealthModel> health;
  const DomainHealthGridWidget({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Dimensions.paddingSizeExtraSmall,
      runSpacing: Dimensions.paddingSizeExtraSmall,
      children: health.map((domain) {
        final Color color = switch (domain.state) {
          'critical' => Theme.of(context).colorScheme.error,
          'degraded' => Colors.deepOrange.shade600,
          'watch' => Colors.amber.shade800,
          _ => Colors.green.shade600,
        };

        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeExtraSmall),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(Dimensions.radiusPill),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: Dimensions.paddingSizeExtraSmall),
            Text(getTranslated('domain_${domain.domain}', context) ?? domain.domain,
                style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
            if (domain.open > 0)
              Text('  ${domain.open}',
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
          ]),
        );
      }).toList(),
    );
  }
}
