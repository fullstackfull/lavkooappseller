import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/returns/domain/models/return_models.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Where a return has got to, in one word and one colour.
///
/// Restocked and received are deliberately different: both mean the goods
/// arrived, but only one means they can be sold again, and that is the
/// difference a seller is actually looking for.
class ReturnStatusChip extends StatelessWidget {
  final String status;
  const ReturnStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color = colorFor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeExtraSmall),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(Dimensions.radiusPill),
      ),
      child: Text(getTranslated('return_status_$status', context) ?? status,
          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
    );
  }

  static Color colorFor(BuildContext context, String status) => switch (status) {
        'restocked' => Colors.green.shade600,
        'received' => Colors.blueGrey.shade600,
        'rejected' => Theme.of(context).colorScheme.error,
        'in_transit' => Colors.orange.shade700,
        _ => Theme.of(context).primaryColor,
      };
}

class ReturnCardWidget extends StatelessWidget {
  final ReturnShipmentModel shipment;
  final VoidCallback? onTap;
  const ReturnCardWidget({super.key, required this.shipment, this.onTap});

  @override
  Widget build(BuildContext context) {
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
            border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: .08)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(shipment.productName ?? shipment.reference ?? '#${shipment.id}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
              ),
              ReturnStatusChip(status: shipment.status),
            ]),
            const SizedBox(height: 2),
            Text(
              [
                '${getTranslated('quantity', context) ?? ''} ${shipment.qty}',
                if (shipment.reference != null) shipment.reference!,
                if (shipment.reason != null && shipment.reason!.isNotEmpty) shipment.reason!,
              ].join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
            ),
            if (shipment.createdAt != null)
              Text(DateConverter.isoStringToLocalDateOnly(shipment.createdAt!),
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
          ]),
        ),
      ),
    );
  }
}
