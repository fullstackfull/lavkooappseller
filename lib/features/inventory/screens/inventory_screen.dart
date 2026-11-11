import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/inventory/widgets/inventory_view.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';

/// The whole shop's stock, from the menu.
///
/// Thin on purpose: the same view is embedded in a product's own page, where it
/// is narrowed to that product. One list, two ways in.
class InventoryScreen extends StatelessWidget {
  final int? productId;
  final String? productName;
  final int currentStock;

  const InventoryScreen({super.key, this.productId, this.productName, this.currentStock = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: productName ?? getTranslated('inventory', context)),
      body: InventoryView(productId: productId, productName: productName, currentStock: currentStock),
    );
  }
}
