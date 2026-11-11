import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/inventory/controllers/inventory_controller.dart';
import 'package:syriacosmeticsmanger/features/inventory/domain/models/inventory_models.dart';
import 'package:syriacosmeticsmanger/features/inventory/widgets/stock_adjust_sheet.dart';
import 'package:syriacosmeticsmanger/features/reports/widgets/report_widgets.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The shop's stock, and why every number is what it is.
///
/// A view rather than a screen, because the same list is the whole shop's stock
/// from the menu and one product's history from that product's page — the same
/// records, narrowed.
///
/// The marketplace has recorded each movement all along — the change, the
/// balance it left, a reason and who made it — and the app has never shown any
/// of it. A stock level that changes for no stated reason is the kind of figure
/// people stop trusting and start keeping a spreadsheet beside.
///
/// Warehouses and batches appear only where the marketplace runs them for this
/// seller. An empty warehouse section implies they ought to have warehouses;
/// showing nothing is the truth.
class InventoryView extends StatefulWidget {
  /// Narrow everything to one product, when opened from that product.
  final int? productId;
  final String? productName;

  /// Only meaningful alongside a product: the correction sheet shows what the
  /// level will read once the change lands, and it cannot do that without
  /// knowing what it reads now.
  final int currentStock;

  const InventoryView({super.key, this.productId, this.productName, this.currentStock = 0});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final InventoryController inventory = Provider.of<InventoryController>(context, listen: false);
    await inventory.getOverview();
    await inventory.getMovements(
      productId: widget.productId,
      clearProduct: widget.productId == null,
      clearType: true,
    );
    if (inventory.overview?.warehousesEnabled ?? false) {
      await inventory.getWarehouses(productId: widget.productId);
    }
    if (inventory.overview?.batchesEnabled ?? false) {
      await inventory.getBatches();
    }
  }

  Future<void> _openAdjustSheet() async {
    final InventoryController inventory = Provider.of<InventoryController>(context, listen: false);
    // The balance the ledger last recorded, when it has one — the product's own
    // column is what the seller last saw, which may be a screen old.
    final int currentStock = inventory.movements?.movements.firstOrNull?.balanceAfter ?? widget.currentStock;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StockAdjustSheet(
        productId: widget.productId!,
        productName: widget.productName,
        currentStock: currentStock,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Consumer<InventoryController>(
        builder: (context, inventory, _) {
          final InventoryOverviewModel? overview = inventory.overview;
          final List<StockMovementModel> movements = inventory.movements?.movements ?? const [];

          return RefreshIndicator(
            onRefresh: _load,
            color: Theme.of(context).cardColor,
            backgroundColor: Theme.of(context).primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                if (overview != null && widget.productId == null) ...[
                  Row(children: [
                    ReportMetricWidget(title: 'products', value: '${overview.products}'),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    ReportMetricWidget(
                      title: 'out_of_stock', value: '${overview.outOfStock}',
                      valueColor: overview.outOfStock > 0 ? Theme.of(context).colorScheme.error : null,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    ReportMetricWidget(
                      title: 'running_low', value: '${overview.runningLow}',
                      valueColor: overview.runningLow > 0 ? Colors.orange.shade800 : null,
                    ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  ReportCardWidget(children: [
                    // What "low" means here, in the seller's own reorder level rather than a number
                    // the app decided. The panel says the same thing beside the same count.
                    if (overview.lowStockThreshold != null)
                      ReportRowWidget(
                        label: 'low_stock_threshold',
                        value: '${overview.lowStockThreshold}',
                      ),
                    ReportRowWidget(label: 'units_on_hand', value: '${overview.unitsOnHand}'),
                    ReportRowWidget(label: 'movements_recorded', value: '${overview.movementsRecorded}'),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                ],

                if (overview != null && overview.warehousesEnabled && inventory.warehouses.isNotEmpty) ...[
                  Text(getTranslated('warehouses', context) ?? '',
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  ...inventory.warehouses.map((warehouse) => Padding(
                        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
                        child: ReportCardWidget(
                          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(warehouse.name ?? '#${warehouse.id}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                              ),
                              if (warehouse.isDefault)
                                Text(getTranslated('default', context) ?? '',
                                    style: robotoRegular.copyWith(
                                        fontSize: Dimensions.fontSizeExtraSmall,
                                        color: Theme.of(context).primaryColor)),
                            ]),
                            if (warehouse.address != null && warehouse.address!.isNotEmpty)
                              Text(warehouse.address!,
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: robotoRegular.copyWith(
                                      fontSize: Dimensions.fontSizeExtraSmall,
                                      color: Theme.of(context).hintColor)),
                          ],
                        ),
                      )),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                ],

                if (overview != null && overview.batchesEnabled) ...[
                  if (inventory.expired.isNotEmpty)
                    _batchSection(context, 'expired_batches', inventory.expired,
                        color: Theme.of(context).colorScheme.error),
                  if (inventory.expiringSoon.isNotEmpty)
                    _batchSection(context, 'expiring_soon', inventory.expiringSoon,
                        color: Colors.orange.shade800),
                ],

                Text(getTranslated('stock_movements', context) ?? '',
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                if (movements.isEmpty)
                  Center(
                    child: inventory.isLoading
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            const NoDataScreen(),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
                              // Nothing recorded is a real answer for a shop that
                              // has not moved stock yet.
                              child: Text(getTranslated('no_stock_movements_yet', context) ?? '',
                                  textAlign: TextAlign.center,
                                  style: robotoRegular.copyWith(
                                      fontSize: Dimensions.fontSizeSmall,
                                      color: Theme.of(context).hintColor)),
                            ),
                          ]),
                  )
                else
                  ...movements.map((movement) => Padding(
                        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
                        child: _movement(context, movement),
                      )),
              ],
            ),
          );
        },
      ),

      // Offered only with a product in hand. A correction is always to one
      // product's balance, so the shop-wide view has nothing to correct.
      if (widget.productId != null)
        Positioned(
          right: Dimensions.paddingSizeDefault,
          bottom: Dimensions.paddingSizeDefault,
          child: FloatingActionButton.extended(
            heroTag: 'correct-stock',
            onPressed: _openAdjustSheet,
            backgroundColor: Theme.of(context).primaryColor,
            icon: const Icon(Icons.tune, color: Colors.white),
            label: Text(getTranslated('correct_stock', context) ?? '',
                style: robotoMedium.copyWith(color: Colors.white)),
          ),
        ),
    ]);
  }

  Widget _batchSection(BuildContext context, String title, List<ProductBatchModel> batches, {required Color color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(getTranslated(title, context) ?? '',
          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge, color: color)),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      ...batches.map((batch) => Padding(
            padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
            child: ReportCardWidget(
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              children: [
                Row(children: [
                  Expanded(
                    child: Text(batch.batchNumber ?? '#${batch.id}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                  ),
                  Text('${batch.quantity}',
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: color)),
                ]),
                if (batch.expiryDate != null)
                  Text('${getTranslated('expires', context) ?? ''} ${batch.expiryDate}',
                      style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
              ],
            ),
          )),
      const SizedBox(height: Dimensions.paddingSizeLarge),
    ]);
  }

  Widget _movement(BuildContext context, StockMovementModel movement) {
    final Color color = movement.isIncrease ? Colors.green.shade700 : Theme.of(context).colorScheme.error;

    return ReportCardWidget(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      children: [
        Row(children: [
          Expanded(
            child: Text(getTranslated('movement_${movement.type}', context) ?? movement.type,
                style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
          ),
          Text(movement.isIncrease ? '+${movement.qtyChange}' : '${movement.qtyChange}',
              style: robotoBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: color)),
        ]),
        Row(children: [
          Expanded(
            child: Text(
              [
                if (movement.reason != null) getTranslated('reason_${movement.reason}', context) ?? movement.reason!,
                if (movement.note != null && movement.note!.isNotEmpty) movement.note!,
                if (movement.createdByType != null) getTranslated(movement.createdByType!, context) ?? movement.createdByType!,
              ].join(' · '),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
            ),
          ),
          // The balance the change left behind, so the log reads without being
          // replayed from the top.
          if (movement.balanceAfter != null)
            Text('→ ${movement.balanceAfter}',
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
        ]),
        if (movement.createdAt != null)
          Text(DateConverter.isoStringToLocalDateAndTime(movement.createdAt!),
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
      ],
    );
  }
}
