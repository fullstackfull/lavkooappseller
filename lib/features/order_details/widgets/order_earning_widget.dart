import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/order_details/controllers/order_details_controller.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/models/order_breakdown_model.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// What this order is worth to the seller.
///
/// The total the customer paid is not the seller's number — commission, tax and
/// sometimes shipping come out of it — and until now nothing said what was left.
///
/// Where the marketplace has not booked the earning yet the card says so and
/// shows no figure. That is the point: a seller reads "you receive" as what will
/// land in their account, so it may only come from the record that will pay
/// them. A plausible estimate in that slot would be a lie with a decimal point.
class OrderEarningWidget extends StatelessWidget {
  const OrderEarningWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderDetailsController>(
      builder: (context, orderDetails, _) {
        final OrderFeesModel? fees = orderDetails.breakdown?.fees;

        if (fees == null) {
          return orderDetails.isBreakdownLoading
              ? const Padding(
                  padding: EdgeInsets.all(Dimensions.paddingSizeDefault),
                  child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : const SizedBox();
        }

        return _card(context, children: [
          Text(getTranslated('your_earning', context) ?? '',
              style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          _row(context, 'items_total', PriceConverter.convertPrice(context, fees.itemsPrice)),
          if (fees.itemsDiscount > 0)
            _row(context, 'discount', '- ${PriceConverter.convertPrice(context, fees.itemsDiscount)}'),
          if (fees.itemsTax > 0) _row(context, 'tax', PriceConverter.convertPrice(context, fees.itemsTax)),
          if (fees.shippingCost != null && fees.shippingCost! > 0)
            _row(context,
                fees.isShippingFree ? 'shipping_free' : 'shipping',
                PriceConverter.convertPrice(context, fees.shippingCost)),

          if (fees.commissionAmount != null)
            _row(context, 'marketplace_commission',
                '- ${PriceConverter.convertPrice(context, fees.commissionAmount)}',
                color: Theme.of(context).colorScheme.error),

          // The rule, not just the amount: one lump sum says what was taken, the
          // rule says why.
          ...fees.rules.where((rule) => rule.label != null).map((rule) => Padding(
                padding: const EdgeInsets.only(left: Dimensions.paddingSizeSmall, bottom: 2),
                child: Text(
                  rule.percentage != null
                      ? '${rule.label} · ${rule.percentage!.toStringAsFixed(rule.percentage! % 1 == 0 ? 0 : 2)}%'
                      : '${rule.label}',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                ),
              )),

          const Divider(height: Dimensions.paddingSizeLarge),

          if (fees.sellerReceives != null)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(getTranslated('you_receive', context) ?? '',
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
              Text(PriceConverter.convertPrice(context, fees.sellerReceives),
                  style: robotoBold.copyWith(
                      fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).primaryColor)),
            ])
          else
            Row(children: [
              Icon(Icons.info_outline, size: 16, color: Theme.of(context).hintColor),
              const SizedBox(width: Dimensions.paddingSizeExtraSmall),
              Expanded(
                child: Text(getTranslated('earning_not_recorded_yet', context) ?? '',
                    style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
              ),
            ]),

          if (fees.ledger.isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            ...fees.ledger.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(getTranslated('ledger_${entry.entryType}', context) ?? entry.entryType,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
                    ),
                    // When a pending earning becomes withdrawable — the most asked
                    // question about a seller's balance.
                    if (entry.status == 'pending' && entry.availableAt != null)
                      Text(
                        '${getTranslated('available_on', context) ?? ''} ${DateConverter.isoStringToLocalDateOnly(entry.availableAt!)}',
                        style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                      ),
                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                    Text(
                      entry.credit > 0
                          ? PriceConverter.convertPrice(context, entry.credit)
                          : '- ${PriceConverter.convertPrice(context, entry.debit)}',
                      style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: entry.credit > 0 ? Colors.green.shade700 : Theme.of(context).colorScheme.error),
                    ),
                  ]),
                )),
          ],
        ]);
      },
    );
  }

  Widget _card(BuildContext context, {required List<Widget> children}) => Container(
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _row(BuildContext context, String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(getTranslated(label, context) ?? label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
          ),
          Text(value,
              style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: color ?? Theme.of(context).textTheme.bodyLarge?.color)),
        ]),
      );
}
