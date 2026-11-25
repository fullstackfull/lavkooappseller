import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/order_details/controllers/order_details_controller.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/models/shipment_hold_model.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Why a shipment of this order has not left (H1-04, H1-06).
///
/// A shipment can be held for something the seller can act on -- a product with no permission to reach the order's destination, a
/// regulated product with no licence on file, an address no carrier serves -- and until now nothing told them: the reason was written by
/// the dispatcher and read only by the admin panel, so a seller watching an order that never moved could not find out why.
///
/// Nothing at all when nothing is held, which is almost every order: a card saying "no shipment is held" on every order is a card nobody
/// reads. The reasons arrive already in the seller's language, because the server translates each one for the request, so there is nothing
/// here to translate and no key to keep in step. A hold the server recorded without a reason says it is held and invents no cause.
class ShipmentHoldWidget extends StatelessWidget {
  const ShipmentHoldWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderDetailsController>(
      builder: (BuildContext context, OrderDetailsController orderDetails, _) {
        final List<ShipmentHoldModel> holds = orderDetails.shipmentHolds;

        if (holds.isEmpty) {
          return const SizedBox();
        }

        final Color warning = Theme.of(context).colorScheme.error;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: warning.withValues(alpha: .4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                Icon(Icons.pause_circle_outline, size: 18, color: warning),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                Expanded(
                  child: Text(
                    getTranslated('shipment_on_hold', context) ?? '',
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge, color: warning),
                  ),
                ),
              ]),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              for (final ShipmentHoldModel hold in holds)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    hold.reason ?? getTranslated('the_reason_was_not_recorded', context) ?? '',
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
