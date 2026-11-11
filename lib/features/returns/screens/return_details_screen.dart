import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/features/reports/widgets/report_widgets.dart';
import 'package:syriacosmeticsmanger/features/returns/controllers/return_controller.dart';
import 'package:syriacosmeticsmanger/features/returns/domain/models/return_models.dart';
import 'package:syriacosmeticsmanger/features/returns/widgets/return_widgets.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// One return, and what its refund did to the balance.
///
/// The two decisions live here rather than in a list, because both need the
/// goods in front of you: whether what arrived can be sold again, and whether it
/// should be refused outright.
class ReturnDetailsScreen extends StatefulWidget {
  final int returnId;
  const ReturnDetailsScreen({super.key, required this.returnId});

  @override
  State<ReturnDetailsScreen> createState() => _ReturnDetailsScreenState();
}

class _ReturnDetailsScreenState extends State<ReturnDetailsScreen> {
  String? _refusal;

  @override
  void initState() {
    super.initState();
    Provider.of<ReturnController>(context, listen: false).getReturn(widget.returnId);
  }

  Future<void> _run(Future<String?> Function() action) async {
    final String? refusal = await action();
    if (!mounted) return;
    setState(() => _refusal = refusal);
  }

  /// Receiving asks the one question nobody can answer before opening the box.
  Future<void> _receive(ReturnController returns) async {
    final bool? restock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(getTranslated('receive_return', dialogContext) ?? '',
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
        content: Text(getTranslated('can_these_goods_be_sold_again', dialogContext) ?? '',
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(getTranslated('no_do_not_restock', dialogContext) ?? ''),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(getTranslated('yes_restock', dialogContext) ?? ''),
          ),
        ],
      ),
    );

    if (restock == null || !mounted) return;
    await _run(() => returns.receive(widget.returnId, restock: restock));
  }

  Future<void> _reject(ReturnController returns) async {
    final TextEditingController reason = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(getTranslated('reject_return', dialogContext) ?? '',
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
        content: TextField(
          controller: reason,
          maxLength: 255,
          decoration: InputDecoration(
            labelText: getTranslated('reason', dialogContext),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(getTranslated('cancel', dialogContext) ?? ''),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(getTranslated('reject', dialogContext) ?? ''),
          ),
        ],
      ),
    );

    // A refusal a customer cannot be told the grounds for is not a decision
    // anyone can act on, so an empty reason simply does not submit.
    if (confirmed != true || reason.text.trim().isEmpty || !mounted) return;
    await _run(() => returns.reject(widget.returnId, reason: reason.text.trim()));
  }

  Future<void> _markInTransit(ReturnController returns) async {
    final TextEditingController tracking = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(getTranslated('mark_in_transit', dialogContext) ?? '',
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
        content: TextField(
          controller: tracking,
          decoration: InputDecoration(
            labelText: getTranslated('tracking_number_optional', dialogContext),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(getTranslated('cancel', dialogContext) ?? ''),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(getTranslated('confirm', dialogContext) ?? ''),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _run(() => returns.markInTransit(widget.returnId, trackingNumber: tracking.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('return_details', context)),
      body: Consumer<ReturnController>(
        builder: (context, returns, _) {
          final ReturnShipmentModel? shipment = returns.current;

          if (shipment == null) {
            return Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)));
          }

          return ListView(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            children: [
              ReportCardWidget(children: [
                Row(children: [
                  Expanded(
                    child: Text(shipment.productName ?? shipment.reference ?? '#${shipment.id}',
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
                  ),
                  ReturnStatusChip(status: shipment.status),
                ]),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                ReportRowWidget(label: 'reference', value: shipment.reference ?? '—'),
                ReportRowWidget(label: 'quantity', value: '${shipment.qty}'),
                if (shipment.reason != null && shipment.reason!.isNotEmpty)
                  ReportRowWidget(label: 'reason', value: shipment.reason!),
                if (shipment.orderId != null)
                  ReportRowWidget(label: 'order', value: '#${shipment.orderId}'),
                if (shipment.trackingNumber != null && shipment.trackingNumber!.isNotEmpty)
                  ReportRowWidget(label: 'tracking_number', value: shipment.trackingNumber!),
                if (shipment.receivedAt != null)
                  ReportRowWidget(
                      label: 'received_at',
                      value: DateConverter.isoStringToLocalDateAndTime(shipment.receivedAt!)),
                if (shipment.isRestocked)
                  // The difference a seller is actually looking for: the goods
                  // arrived *and* can be sold again.
                  ReportRowWidget(
                      label: 'restocked', value: getTranslated('yes', context) ?? '',
                      valueColor: Colors.green.shade700),
                if (shipment.note != null && shipment.note!.isNotEmpty)
                  ReportRowWidget(label: 'note', value: shipment.note!),
              ]),

              if (returns.ledger.isNotEmpty) ...[
                const SizedBox(height: Dimensions.paddingSizeLarge),
                Text(getTranslated('effect_on_your_balance', context) ?? '',
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                ReportCardWidget(children: [
                  ...returns.ledger.map((entry) => ReportRowWidget(
                        label: 'ledger_${entry.entryType}',
                        value: entry.isCredit
                            ? PriceConverter.convertPrice(context, entry.credit)
                            : '- ${PriceConverter.convertPrice(context, entry.debit)}',
                        valueColor: entry.isCredit
                            ? Colors.green.shade700
                            : Theme.of(context).colorScheme.error,
                      )),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  // The line sellers never see and most doubt exists.
                  Text(getTranslated('commission_on_a_refund_is_given_back', context) ?? '',
                      style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
                ]),
              ],

              if (_refusal != null) ...[
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(_refusal!,
                    style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).colorScheme.error)),
              ],

              // Offered only while the return is still moving. A closed return
              // has nothing left to decide.
              if (shipment.isOpen) ...[
                const SizedBox(height: Dimensions.paddingSizeLarge),
                if (shipment.isAuthorized)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                    child: CustomButtonWidget(
                      btnTxt: getTranslated('mark_in_transit', context),
                      backgroundColor: Theme.of(context).cardColor,
                      fontColor: Theme.of(context).primaryColor,
                      borderColor: Theme.of(context).primaryColor,
                      onTap: returns.isActing ? null : () => _markInTransit(returns),
                    ),
                  ),
                CustomButtonWidget(
                  btnTxt: getTranslated('receive_return', context),
                  isLoading: returns.isActing,
                  onTap: returns.isActing ? null : () => _receive(returns),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                CustomButtonWidget(
                  btnTxt: getTranslated('reject_return', context),
                  backgroundColor: Theme.of(context).cardColor,
                  fontColor: Theme.of(context).colorScheme.error,
                  borderColor: Theme.of(context).colorScheme.error,
                  onTap: returns.isActing ? null : () => _reject(returns),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
