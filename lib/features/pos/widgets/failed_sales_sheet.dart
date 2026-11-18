import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/offline_sales_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The sales that the offline outbox could not send. Each stays on the device with the reason the server gave, until the seller retries it or removes it: a sale is the only record of money
/// taken at the counter, so the app never deletes one by itself.
class FailedSalesSheet extends StatelessWidget {
  const FailedSalesSheet({super.key, this.formatAmount = amountText});

  /// How the amount of a sale is written. It is the shop's currency format; a test gives its own, because that format needs the providers of the whole app.
  final String Function(BuildContext context, double amount) formatAmount;

  static String amountText(BuildContext context, double amount) => PriceConverter.convertPrice(context, amount);

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) => const FailedSalesSheet(),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSize),
        child: Consumer<OfflineSalesController>(
          builder: (BuildContext context, OfflineSalesController offline, _) {
            final List<PendingPosOrder> failed = offline.failedSales;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(getTranslated('sales_not_sent', context) ?? '', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(getTranslated('sales_not_sent_explained', context) ?? '', style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                if (failed.isNotEmpty)
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: failed.length,
                      separatorBuilder: (BuildContext context, int index) => const Divider(),
                      itemBuilder: (BuildContext context, int index) => _FailedSaleTile(order: failed[index], formatAmount: formatAmount),
                    ),
                  )
                // A retry gives a failed sale its attempts back, so the list is empty while the sales are still unsent: the sheet says how many wait, and never that everything is synced.
                else if (offline.hasPending)
                  Text('${getTranslated('unsynced_sales', context)}: ${offline.pendingCount}', style: robotoMedium),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(getTranslated('close', context) ?? '')),
                    if (failed.isNotEmpty)
                      FilledButton(
                        onPressed: offline.isOnline && !offline.isSyncing ? () => offline.retryFailedSales() : null,
                        child: Text(getTranslated('retry', context) ?? ''),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FailedSaleTile extends StatelessWidget {
  const _FailedSaleTile({required this.order, required this.formatAmount});

  final PendingPosOrder order;
  final String Function(BuildContext context, double amount) formatAmount;

  @override
  Widget build(BuildContext context) {
    final String? reason = order.lastError == OfflineSalesController.refusedWithoutReason ? getTranslated('something_went_wrong', context) : order.lastError;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${order.customerName} · ${formatAmount(context, order.orderAmount)}', style: robotoMedium),
      subtitle: Text(
        '${order.createdAt.toLocal().toString().substring(0, 16)}${reason == null || reason.isEmpty ? '' : '\n${getTranslated('reason', context)}: $reason'}',
        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
      ),
      isThreeLine: reason != null && reason.isNotEmpty,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded),
        tooltip: getTranslated('remove_sale', context),
        onPressed: () => _confirmRemoval(context),
      ),
    );
  }

  Future<void> _confirmRemoval(BuildContext context) async {
    final OfflineSalesController offline = Provider.of<OfflineSalesController>(context, listen: false);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(getTranslated('remove_sale', dialogContext) ?? ''),
        content: Text(getTranslated('remove_sale_confirmation', dialogContext) ?? ''),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(getTranslated('no', dialogContext) ?? '')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(getTranslated('yes', dialogContext) ?? '')),
        ],
      ),
    );

    if (confirmed == true) {
      await offline.remove(order.id);
    }
  }
}
