import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/models/seller_insight_model.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// How bad, in one colour.
///
/// Kept in one place because the same four levels are read on the home card, in
/// the list and on the filter chips, and three slightly different palettes would
/// make the same insight look like three different things.
class InsightSeverity {
  static const List<String> order = <String>['critical', 'high', 'medium', 'low'];

  static Color color(BuildContext context, String severity) => switch (severity) {
        'critical' => Theme.of(context).colorScheme.error,
        'high' => Colors.deepOrange.shade600,
        'medium' => Colors.amber.shade800,
        _ => Theme.of(context).primaryColor,
      };
}

/// One thing waiting, with what it is about and the way to open it.
///
/// The number under the title is type-aware rather than generic, because
/// "48/100" and "4 hours left" mean entirely different things and a single
/// unlabelled figure would mean neither.
class InsightCardWidget extends StatelessWidget {
  final SellerInsightModel insight;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const InsightCardWidget({super.key, required this.insight, this.onTap, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final Color color = InsightSeverity.color(context, insight.severity);
    final String? detail = _detail(context);

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
              width: 4, height: 38,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Dimensions.radiusPill)),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(getTranslated(insight.title, context) ?? insight.title,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: color)),
                if (insight.body != null && insight.body!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(insight.body!,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                ],
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail,
                      style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
                ],
              ]),
            ),
            if (insight.dismissible && onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                tooltip: getTranslated('dismiss', context),
                icon: Icon(Icons.close, size: 18, color: Theme.of(context).hintColor),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
                child: Icon(Icons.arrow_forward_ios_rounded, size: Dimensions.fontSizeSmall,
                    color: Theme.of(context).hintColor),
              ),
          ]),
        ),
      ),
    );
  }

  /// The figure the insight carries, said in the words of its own type.
  ///
  /// Returns null rather than a placeholder when the type has no figure — an
  /// empty line is better than a number that means nothing.
  String? _detail(BuildContext context) {
    final double? metric = insight.metric;

    return switch (insight.type) {
      'ORDER_SLA' when metric != null && metric >= 0 =>
        '${metric.toStringAsFixed(metric < 10 ? 1 : 0)} ${getTranslated('hours_left', context) ?? ''}',
      'ORDER_SLA' when metric != null =>
        '${metric.abs().toStringAsFixed(metric.abs() < 10 ? 1 : 0)} ${getTranslated('hours_late', context) ?? ''}',
      'LISTING_QUALITY' when metric != null =>
        '${getTranslated('listing_score', context) ?? ''} ${metric.toStringAsFixed(0)}/100',
      'INVENTORY_RISK' when metric != null =>
        '${getTranslated('stock', context) ?? ''} ${metric.toStringAsFixed(0)}',
      _ => null,
    };
  }
}

/// The severity filter, with the open count on each.
///
/// A level with nothing open is still shown, greyed rather than hidden, so the
/// row does not reshuffle under the seller's thumb as insights resolve.
class InsightSeverityFilterWidget extends StatelessWidget {
  final String? selected;
  final Map<String, int> counts;
  final ValueChanged<String?> onChanged;

  const InsightSeverityFilterWidget({
    super.key,
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
        children: [
          _chip(context, null, getTranslated('all', context) ?? '', counts['total'] ?? 0),
          ...InsightSeverity.order.map((severity) => _chip(
                context,
                severity,
                getTranslated('severity_$severity', context) ?? severity,
                counts[severity] ?? 0,
              )),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String? severity, String label, int count) {
    final bool isSelected = selected == severity;
    final Color color = severity == null
        ? Theme.of(context).primaryColor
        : InsightSeverity.color(context, severity);

    return Padding(
      padding: const EdgeInsets.only(right: Dimensions.paddingSizeExtraSmall),
      child: ChoiceChip(
        label: Text(count > 0 ? '$label ($count)' : label),
        selected: isSelected,
        selectedColor: color.withValues(alpha: .15),
        labelStyle: robotoMedium.copyWith(
          fontSize: Dimensions.fontSizeExtraSmall,
          color: isSelected ? color : Theme.of(context).hintColor,
        ),
        onSelected: (_) => onChanged(severity),
      ),
    );
  }
}
