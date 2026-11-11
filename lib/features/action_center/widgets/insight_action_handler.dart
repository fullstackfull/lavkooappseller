import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/models/seller_insight_model.dart';
import 'package:syriacosmeticsmanger/features/addProduct/screens/add_product_tab_view_screen.dart';
import 'package:syriacosmeticsmanger/features/order_details/screens/order_details_screen.dart';
import 'package:syriacosmeticsmanger/features/product_details/controllers/product_details_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Turns an insight's action into somewhere to go.
///
/// The whole point of an insight carrying an action is that the seller does not
/// have to work out where to fix it. `open_product` therefore lands on the
/// product editor rather than a read-only detail page — every product insight
/// this app produces is asking for an edit.
///
/// A rejected listing opens its reasons first. The moderator's own words have
/// never been shown in the app, which made a refusal a dead end: refused, with
/// no way to learn why.
class InsightActionHandler {
  const InsightActionHandler._();

  static Future<void> open(BuildContext context, SellerInsightModel insight) async {
    if (insight.title == 'insight_product_rejected') {
      final bool edit = await _showRejection(context, insight) ?? false;
      if (!edit || !context.mounted) return;
    }

    switch (insight.actionKey) {
      case 'open_order':
        final int? orderId = _idFrom(insight.actionParams['order_id']) ?? insight.entityIdAsInt;
        if (orderId != null) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: orderId)));
        }
        return;

      case 'open_product':
        final int? productId = _idFrom(insight.actionParams['product_id']) ?? insight.entityIdAsInt;
        if (productId != null) await _openProduct(context, productId);
        return;
    }
  }

  /// Loads the product before opening the editor.
  ///
  /// The editor reads real fields off the product it is given — unit, code,
  /// product type — so handing it a stub built from an id alone would open a
  /// form that quietly disagrees with the record behind it.
  static Future<void> _openProduct(BuildContext context, int productId) async {
    final ProductDetailsController details = Provider.of<ProductDetailsController>(context, listen: false);

    await details.getProductDetails(productId);
    if (!context.mounted) return;

    if (details.productDetails == null) {
      showCustomSnackBarWidget(getTranslated('product_not_found', context), context,
          sanckBarType: SnackBarType.error);
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddProductTabView(product: details.productDetails, fromHome: false),
    ));
  }

  /// Why the listing was refused, in the moderator's own words.
  ///
  /// Returns true when the seller chose to go on and fix it.
  static Future<bool?> _showRejection(BuildContext context, SellerInsightModel insight) {
    final List<String> codes = insight.actionParams['reason_codes'] is List
        ? List<String>.from((insight.actionParams['reason_codes'] as List).map((code) => code.toString()))
        : const <String>[];
    final String? note = insight.actionParams['note']?.toString();

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(getTranslated('insight_product_rejected', dialogContext) ?? '',
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (insight.body != null)
            Text(insight.body!, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          ...codes.map((code) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• ${getTranslated(code, dialogContext) ?? code}',
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
              )),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(note,
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall, color: Theme.of(dialogContext).hintColor)),
          ],
          // Said plainly rather than left blank: a refusal with no recorded
          // reason is a fact about the record, not a rendering failure.
          if (codes.isEmpty && (note == null || note.isEmpty))
            Text(getTranslated('no_rejection_reason_recorded', dialogContext) ?? '',
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall, color: Theme.of(dialogContext).hintColor)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(getTranslated('close', dialogContext) ?? ''),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(getTranslated('fix_listing', dialogContext) ?? ''),
          ),
        ],
      ),
    );
  }

  static int? _idFrom(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');
}
