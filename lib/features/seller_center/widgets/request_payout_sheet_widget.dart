import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/payout_models.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Ask for a payout against the withdrawable balance. The amount is checked
/// against that balance here so an obviously impossible request never leaves
/// the device — the ledger stays the authority either way.
class RequestPayoutSheetWidget extends StatefulWidget {
  final PayoutOverviewModel payouts;
  const RequestPayoutSheetWidget({super.key, required this.payouts});

  @override
  State<RequestPayoutSheetWidget> createState() => _RequestPayoutSheetWidgetState();
}

class _RequestPayoutSheetWidgetState extends State<RequestPayoutSheetWidget> {
  final TextEditingController _amountController = TextEditingController();
  String? _payoutCurrency;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// The withdrawable ceiling in the display currency, truncated and without a
  /// symbol so it can be both shown in the field and parsed back for the check.
  String _withdrawableInLocalCurrency(BuildContext context) =>
      PriceConverter.convertPriceWithoutSymbolForWithdraw(context, widget.payouts.withdrawable);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
        ),
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Consumer<SellerCenterController>(
          builder: (context, sellerCenter, _) {
            return SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(
                  child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor.withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(Dimensions.radiusPill),
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                Text(getTranslated('request_payout', context)!,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge,
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text('${getTranslated('withdrawable_balance', context)}: '
                    '${PriceConverter.convertPriceForWithdraw(context, widget.payouts.withdrawable)}',
                    style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                Text(getTranslated('amount', context)!,
                    style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      borderSide: BorderSide(color: Theme.of(context).hintColor.withValues(alpha: .3)),
                    ),
                    suffixIcon: TextButton(
                      onPressed: () => _amountController.text = _withdrawableInLocalCurrency(context),
                      child: Text(getTranslated('max', context)!,
                          style: robotoMedium.copyWith(
                              fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor)),
                    ),
                  ),
                ),

                if (widget.payouts.payoutCurrencies.isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  Text(getTranslated('payout_currency', context)!,
                      style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: .3)),
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    ),
                    child: DropdownButton<String>(
                      value: _payoutCurrency,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: Text(getTranslated('default', context) ?? '',
                          style: robotoRegular.copyWith(color: Theme.of(context).hintColor)),
                      items: widget.payouts.payoutCurrencies.map((code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(code,
                            style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      )).toList(),
                      onChanged: (value) => setState(() => _payoutCurrency = value),
                    ),
                  ),
                ],
                const SizedBox(height: Dimensions.paddingSizeLarge),

                CustomButtonWidget(
                  isLoading: sellerCenter.isSubmitting,
                  btnTxt: getTranslated('request_payout', context),
                  backgroundColor: Theme.of(context).primaryColor,
                  onTap: () async {
                    // The seller reads and types in the store's display currency,
                    // so the check happens there and the amount is converted back
                    // to the ledger's base currency before it is sent.
                    final double? localAmount = double.tryParse(_amountController.text.trim());
                    if (localAmount == null || localAmount <= 0) {
                      showCustomSnackBarWidget(getTranslated('enter_a_valid_amount', context), context);
                      return;
                    }
                    final double localWithdrawable =
                        double.tryParse(_withdrawableInLocalCurrency(context)) ?? 0;
                    if (localAmount > localWithdrawable) {
                      showCustomSnackBarWidget(
                          getTranslated('amount_exceeds_withdrawable_balance', context), context);
                      return;
                    }
                    final bool requested = await sellerCenter.requestPayout(
                      amount: double.tryParse(
                              PriceConverter.reverseConvertPriceWithoutSymbol(context, localAmount)) ??
                          localAmount,
                      payoutCurrency: _payoutCurrency,
                    );
                    if (requested && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
              ]),
            );
          },
        ),
      ),
    );
  }
}
