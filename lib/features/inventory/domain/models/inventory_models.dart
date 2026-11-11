/// The state of the shop's stock, counted rather than estimated.
///
/// `warehousesEnabled` and `batchesEnabled` exist so the app can hide a module
/// the marketplace does not run for this seller. Showing an empty warehouse
/// screen implies they ought to have warehouses; saying nothing is the truth.
class InventoryOverviewModel {
  final int? lowStockThreshold;
  final int products;
  final int outOfStock;
  final int runningLow;
  final int unitsOnHand;
  final int movementsRecorded;
  final List<String> reasons;
  final List<String> movementTypes;
  final bool warehousesEnabled;
  final bool batchesEnabled;

  const InventoryOverviewModel({
    this.lowStockThreshold,
    this.products = 0,
    this.outOfStock = 0,
    this.runningLow = 0,
    this.unitsOnHand = 0,
    this.movementsRecorded = 0,
    this.reasons = const <String>[],
    this.movementTypes = const <String>[],
    this.warehousesEnabled = false,
    this.batchesEnabled = false,
  });

  factory InventoryOverviewModel.fromJson(Map<String, dynamic> json) => InventoryOverviewModel(
        lowStockThreshold: _int(json['low_stock_threshold']),
        products: _int(json['products']) ?? 0,
        outOfStock: _int(json['out_of_stock']) ?? 0,
        runningLow: _int(json['running_low']) ?? 0,
        unitsOnHand: _int(json['units_on_hand']) ?? 0,
        movementsRecorded: _int(json['movements_recorded']) ?? 0,
        reasons: _strings(json['reasons']),
        movementTypes: _strings(json['movement_types']),
        warehousesEnabled: json['warehouses_enabled'] == true,
        batchesEnabled: json['batches_enabled'] == true,
      );

  static int? _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  static List<String> _strings(dynamic value) => value is List
      ? List<String>.from(value.map((entry) => entry.toString()))
      : const <String>[];
}

/// One recorded change, with the balance it left behind.
///
/// `balanceAfter` is what makes the log readable without replaying it: a seller
/// scrolling back can see what the number was at each point rather than adding
/// up every change since.
class StockMovementModel {
  final int id;
  final int? productId;
  final String type;
  final int qtyChange;
  final int? balanceAfter;
  final String? reason;
  final String? note;
  final String? createdByType;
  final String? createdAt;

  const StockMovementModel({
    required this.id,
    this.productId,
    this.type = '',
    this.qtyChange = 0,
    this.balanceAfter,
    this.reason,
    this.note,
    this.createdByType,
    this.createdAt,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> json) => StockMovementModel(
        id: InventoryOverviewModel._int(json['id']) ?? 0,
        productId: InventoryOverviewModel._int(json['product_id']),
        type: json['type']?.toString() ?? '',
        qtyChange: InventoryOverviewModel._int(json['qty_change']) ?? 0,
        balanceAfter: InventoryOverviewModel._int(json['balance_after']),
        reason: json['reason']?.toString(),
        note: json['note']?.toString(),
        createdByType: json['created_by_type']?.toString(),
        createdAt: json['created_at']?.toString(),
      );

  bool get isIncrease => qtyChange > 0;
}

class StockMovementListModel {
  final int totalSize;
  final List<StockMovementModel> movements;

  const StockMovementListModel({this.totalSize = 0, this.movements = const <StockMovementModel>[]});

  factory StockMovementListModel.fromJson(Map<String, dynamic> json) => StockMovementListModel(
        totalSize: InventoryOverviewModel._int(json['total_size']) ?? 0,
        movements: json['movements'] is List
            ? (json['movements'] as List)
                .whereType<Map>()
                .map((row) => StockMovementModel.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const <StockMovementModel>[],
      );
}

class WarehouseModel {
  final int id;
  final String? name;
  final String? code;
  final String? address;
  final bool isDefault;
  final String? status;

  const WarehouseModel({required this.id, this.name, this.code, this.address, this.isDefault = false, this.status});

  factory WarehouseModel.fromJson(Map<String, dynamic> json) => WarehouseModel(
        id: InventoryOverviewModel._int(json['id']) ?? 0,
        name: json['name']?.toString(),
        code: json['code']?.toString(),
        address: json['address']?.toString(),
        isDefault: json['is_default'] == true,
        status: json['status']?.toString(),
      );
}

/// Stock with a date on it. Expiring is worth knowing while it can still be
/// sold; expired is worth knowing because it cannot.
class ProductBatchModel {
  final int id;
  final int? productId;
  final String? batchNumber;
  final String? expiryDate;
  final int quantity;
  final String? status;

  const ProductBatchModel({
    required this.id,
    this.productId,
    this.batchNumber,
    this.expiryDate,
    this.quantity = 0,
    this.status,
  });

  factory ProductBatchModel.fromJson(Map<String, dynamic> json) => ProductBatchModel(
        id: InventoryOverviewModel._int(json['id']) ?? 0,
        productId: InventoryOverviewModel._int(json['product_id']),
        batchNumber: json['batch_number']?.toString(),
        expiryDate: json['expiry_date']?.toString(),
        quantity: InventoryOverviewModel._int(json['quantity']) ?? 0,
        status: json['status']?.toString(),
      );
}
