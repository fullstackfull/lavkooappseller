import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/reports/domain/models/report_models.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The pieces every report page is built from, so the three read as one feature
/// rather than three that happen to sit together.

class ReportCardWidget extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  const ReportCardWidget({super.key, required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        boxShadow: [
          BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: .05),
              spreadRadius: -3, blurRadius: 12, offset: Offset.fromDirection(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

/// The period chips.
///
/// Highlights what was tapped rather than what the last response echoed, so the
/// selection moves while the new period loads.
class ReportPeriodPickerWidget extends StatelessWidget {
  final ReportPeriodModel period;
  final String selected;
  final ValueChanged<String> onChanged;
  final VoidCallback? onPickRange;

  const ReportPeriodPickerWidget({
    super.key,
    required this.period,
    required this.selected,
    required this.onChanged,
    this.onPickRange,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> types = period.dateTypes.isNotEmpty
        ? period.dateTypes
        : const ['today', 'this_week', 'this_month', 'this_year', 'custom_date'];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSizeExtraSmall),
        itemBuilder: (context, index) {
          final String type = types[index];
          final bool isSelected = type == selected;
          return InkWell(
            onTap: () => type == 'custom_date' && onPickRange != null ? onPickRange!() : onChanged(type),
            borderRadius: BorderRadius.circular(Dimensions.radiusPill),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(Dimensions.radiusPill),
              ),
              child: Text(getTranslated('period_$type', context) ?? type,
                  style: (isSelected ? robotoBold : robotoRegular).copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                  )),
            ),
          );
        },
      ),
    );
  }
}

class ReportMetricWidget extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;
  const ReportMetricWidget({super.key, required this.title, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          boxShadow: [
            BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: .05),
                spreadRadius: -3, blurRadius: 12, offset: Offset.fromDirection(0, 6)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeExtraLarge,
                  color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: 2),
          Text(getTranslated(title, context) ?? title,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
        ]),
      ),
    );
  }
}

/// A bar per bucket, scrollable, drawn from the series the server sent.
///
/// The server builds that series from the calendar rather than from the rows,
/// so a period with nothing in it draws a flat line — which reads as "nothing
/// sold", not as "no data".
class ReportChartWidget extends StatelessWidget {
  final ReportChartModel chart;
  final String title;
  const ReportChartWidget({super.key, required this.chart, required this.title});

  @override
  Widget build(BuildContext context) {
    if (!chart.hasBars) {
      return const SizedBox();
    }

    final double peak = chart.peak;

    return ReportCardWidget(children: [
      Text(getTranslated(title, context) ?? title,
          style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chart.length,
          separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          itemBuilder: (context, index) {
            final double value = chart.values[index];
            // Every bucket keeps a visible foot, so an empty one is a bar of
            // height zero rather than a gap in the row.
            final double fraction = peak <= 0 ? 0 : value / peak;

            return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(value <= 0 ? '' : _short(value),
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
              const SizedBox(height: 2),
              Container(
                width: 22,
                height: 8 + (92 * fraction),
                decoration: BoxDecoration(
                  color: value > 0
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).hintColor.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              SizedBox(
                width: 34,
                child: Text(chart.labels[index],
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  /// Bar captions have room for a few characters, not for a full currency
  /// string; the exact figures are in the cards above.
  String _short(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }
}

class ReportRowWidget extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const ReportRowWidget({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
          child: Text(getTranslated(label, context) ?? label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Text(value,
            style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color)),
      ]),
    );
  }
}
