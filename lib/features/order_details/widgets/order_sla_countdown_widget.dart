import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/order_details/controllers/order_details_controller.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/models/order_breakdown_model.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// How long the seller has to get this order moving.
///
/// The number comes from the marketplace's SLA policy, so it is the same clock
/// the seller is judged by rather than a second, kinder one. It disappears once
/// the order is with the courier — at that point there is nothing left for the
/// seller to be late for, and a countdown would be blaming them for someone
/// else's delay.
class OrderSlaCountdownWidget extends StatelessWidget {
  const OrderSlaCountdownWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderDetailsController>(
      builder: (context, orderDetails, _) {
        final OrderSlaModel? sla = orderDetails.breakdown?.sla;
        if (sla == null || sla.hoursLeft == null) return const SizedBox();

        final bool isLate = sla.isLate;
        final double hours = sla.hoursLeft!.abs();
        final Color color = isLate
            ? Theme.of(context).colorScheme.error
            : (hours <= 6 ? Colors.deepOrange.shade600 : Theme.of(context).primaryColor);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: color.withValues(alpha: .3)),
          ),
          child: Row(children: [
            Icon(isLate ? Icons.warning_amber_rounded : Icons.schedule, size: 18, color: color),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isLate
                      ? '${getTranslated('order_is_late_by', context) ?? ''} ${_hours(hours)} ${getTranslated('hours', context) ?? ''}'
                      : '${_hours(hours)} ${getTranslated('hours_left_to_process', context) ?? ''}',
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: color),
                ),
                if (sla.deadline != null)
                  Text(
                    '${getTranslated('due', context) ?? ''} ${DateConverter.isoStringToLocalDateAndTime(sla.deadline!)}',
                    style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                  ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  /// One decimal under ten hours, none above: "1.5 hours" is useful, "19.4" is
  /// false precision on a window measured in days.
  String _hours(double hours) => hours < 10 ? hours.toStringAsFixed(1) : hours.toStringAsFixed(0);
}
