import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/confirmation_dialog_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_dialog_widget.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/payout_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/widgets/request_payout_sheet_widget.dart';
import 'package:syriacosmeticsmanger/features/seller_center/widgets/status_pill_widget.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Ledger payouts: what is available, pending and reserved, what can actually
/// be withdrawn right now, and the history of requests with their state.
class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  @override
  void initState() {
    Provider.of<SellerCenterController>(context, listen: false).getPayouts();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('payouts', context)),
      body: RefreshIndicator(
        onRefresh: () => Provider.of<SellerCenterController>(context, listen: false).getPayouts(),
        color: Theme.of(context).cardColor,
        backgroundColor: Theme.of(context).primaryColor,
        child: Consumer<SellerCenterController>(
          builder: (context, sellerCenter, _) {
            final PayoutOverviewModel? payouts = sellerCenter.payouts;
            if (payouts == null) {
              return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * .6,
                  child: Center(child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  )),
                ),
              ]);
            }

            final bool canRequest = payouts.withdrawable > 0
                && payouts.payoutEligible
                && !payouts.inCoolingPeriod;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                _WithdrawableCardWidget(payouts: payouts, canRequest: canRequest),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                // Every bucket the ledger reports, including the ones it returns
                // as negatives (money held for a request, money already paid
                // out). All four are shown because they sum to the total — drop
                // one and the column silently stops adding up.
                _CardWidget(children: [
                  _BalanceRowWidget(title: 'available', amount: payouts.available),
                  _BalanceRowWidget(title: 'pending', amount: payouts.pending),
                  _BalanceRowWidget(title: 'on_hold', amount: payouts.reserved),
                  _BalanceRowWidget(title: 'already_paid_out', amount: payouts.paid),
                  Divider(height: Dimensions.paddingSizeLarge,
                      color: Theme.of(context).hintColor.withValues(alpha: .15)),
                  _BalanceRowWidget(title: 'total_balance', amount: payouts.balance, isBold: true),
                ]),

                // A refusal the seller can act on beats a disabled button with no reason.
                if (!payouts.payoutEligible) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  _NoticeWidget(
                    message: getTranslated('kyc_verification_required', context)!,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ],
                if (payouts.inCoolingPeriod) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  _NoticeWidget(
                    message: getTranslated('bank_details_recently_changed', context)!,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
                  child: Text(getTranslated('payout_history', context)!,
                      style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                ),

                if (payouts.requests.isEmpty)
                  _CardWidget(children: [
                    Text(getTranslated('no_payout_request_yet', context)!,
                        style: robotoRegular.copyWith(color: Theme.of(context).hintColor)),
                  ])
                else
                  ...payouts.requests.map((request) => Padding(
                    padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                    child: _PayoutRequestCardWidget(request: request),
                  )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WithdrawableCardWidget extends StatelessWidget {
  final PayoutOverviewModel payouts;
  final bool canRequest;
  const _WithdrawableCardWidget({required this.payouts, required this.canRequest});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Image.asset(Images.cardWhite, height: Dimensions.logoHeight, width: Dimensions.logoHeight),
        const SizedBox(height: Dimensions.paddingSizeDefault),

        Text(getTranslated('withdrawable_balance', context)!,
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).cardColor)),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        // The withdrawable figure is a ceiling, so it truncates rather than
        // rounds — rounding up would advertise more than the ledger allows.
        Text(PriceConverter.convertPriceForWithdraw(context, payouts.withdrawable),
            style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeMaxLarge, color: Theme.of(context).cardColor)),
        const SizedBox(height: Dimensions.paddingSizeDefault),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).cardColor,
              disabledBackgroundColor: Theme.of(context).cardColor.withValues(alpha: .5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusSmall)),
            ),
            onPressed: !canRequest ? null : () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => RequestPayoutSheetWidget(payouts: payouts),
            ),
            child: Text(getTranslated('request_payout', context)!,
                style: robotoMedium.copyWith(color: Theme.of(context).primaryColor)),
          ),
        ),
      ]),
    );
  }
}

class _PayoutRequestCardWidget extends StatelessWidget {
  final PayoutRequestModel request;
  const _PayoutRequestCardWidget({required this.request});

  @override
  Widget build(BuildContext context) {
    return _CardWidget(children: [
      Row(children: [
        Expanded(
          child: Text(PriceConverter.convertPrice(context, request.amount),
              style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: Theme.of(context).textTheme.bodyLarge?.color)),
        ),
        StatusPillWidget(status: request.status),
      ]),
      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
      Text(request.reference ?? '',
          style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),

      if (request.isOpen && request.id != null) ...[
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => showAnimatedDialogWidget(
              context,
              ConfirmationDialogWidget(
                icon: Images.accountDeleteWarning,
                title: getTranslated('cancel_payout_request', context),
                description: getTranslated('cancel_payout_request_confirmation', context),
                onYesPressed: () {
                  Navigator.pop(context);
                  Provider.of<SellerCenterController>(context, listen: false).cancelPayout(request.id!);
                },
              ),
              isFlip: true,
            ),
            child: Text(getTranslated('cancel_request', context)!,
                style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).colorScheme.error)),
          ),
        ),
      ],
    ]);
  }
}

class _BalanceRowWidget extends StatelessWidget {
  final String title;
  final double amount;
  final bool isBold;
  const _BalanceRowWidget({required this.title, required this.amount, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final TextStyle style = (isBold ? robotoMedium : robotoRegular)
        .copyWith(color: Theme.of(context).textTheme.bodyLarge?.color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(getTranslated(title, context)!, style: style),
        Text(PriceConverter.convertPrice(context, amount), style: style),
      ]),
    );
  }
}

class _NoticeWidget extends StatelessWidget {
  final String message;
  final Color color;
  const _NoticeWidget({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: Dimensions.iconSizeSmall, color: color),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(
          child: Text(message,
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: color)),
        ),
      ]),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final List<Widget> children;
  const _CardWidget({required this.children});

  @override
  Widget build(BuildContext context) {
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
