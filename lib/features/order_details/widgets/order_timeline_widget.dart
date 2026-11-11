import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/order_details/controllers/order_details_controller.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/models/order_breakdown_model.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// What has happened to this order, oldest first.
///
/// Every entry is a record that exists — a status change someone made, a courier
/// assignment, an edit, a refund request. Nothing is inferred from the current
/// status, because an inferred timeline is a story rather than a history: it
/// would show "confirmed" at a time nobody confirmed anything.
class OrderTimelineWidget extends StatelessWidget {
  const OrderTimelineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderDetailsController>(
      builder: (context, orderDetails, _) {
        final List<OrderTimelineEventModel> events = orderDetails.breakdown?.timeline ?? const [];
        if (events.isEmpty) return const SizedBox();

        return Container(
          width: double.infinity,
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
            Text(getTranslated('order_timeline', context) ?? '',
                style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            ...events.asMap().entries.map((entry) => _event(
                  context,
                  entry.value,
                  isLast: entry.key == events.length - 1,
                )),
          ]),
        );
      },
    );
  }

  Widget _event(BuildContext context, OrderTimelineEventModel event, {required bool isLast}) {
    final Color color = Theme.of(context).primaryColor;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 9, height: 9, margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          if (!isLast)
            Expanded(child: Container(width: 1, color: color.withValues(alpha: .25))),
        ]),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : Dimensions.paddingSizeSmall),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(getTranslated(event.key, context) ?? event.key,
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
              if (event.at != null)
                Text(DateConverter.isoStringToLocalDateAndTime(event.at!),
                    style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
              // Who moved it. A seller chasing a cancellation needs to know
              // whether it was them, the customer, or the marketplace.
              if (event.actor != null || event.note != null)
                Text(
                  [
                    if (event.actor != null) getTranslated(event.actor!, context) ?? event.actor!,
                    if (event.note != null && event.note!.isNotEmpty) event.note!,
                  ].join(' · '),
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
