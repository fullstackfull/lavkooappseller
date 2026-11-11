import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/inventory/domain/models/inventory_models.dart';
import 'package:syriacosmeticsmanger/features/inventory/domain/services/inventory_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// The shop's stock, and the history behind every number.
///
/// A correction is never a bare write to a stock level: it goes through the
/// ledger, which refuses to drive a balance below zero and records why the
/// number moved. `adjust` therefore returns the refusal message rather than a
/// bare false, because "it did not work" is not something a seller can act on
/// and "that would take you below zero" is.
class InventoryController with ChangeNotifier {
  final InventoryServiceInterface inventoryServiceInterface;
  InventoryController({required this.inventoryServiceInterface});

  InventoryOverviewModel? _overview;
  InventoryOverviewModel? get overview => _overview;

  StockMovementListModel? _movements;
  StockMovementListModel? get movements => _movements;

  List<WarehouseModel> _warehouses = const <WarehouseModel>[];
  List<WarehouseModel> get warehouses => _warehouses;

  List<ProductBatchModel> _expiringSoon = const <ProductBatchModel>[];
  List<ProductBatchModel> get expiringSoon => _expiringSoon;

  List<ProductBatchModel> _expired = const <ProductBatchModel>[];
  List<ProductBatchModel> get expired => _expired;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isAdjusting = false;
  bool get isAdjusting => _isAdjusting;

  /// Null means the whole shop. Set it and every read narrows to one product.
  int? _productId;
  int? get productId => _productId;

  String? _type;
  String? get type => _type;

  List<String> get reasons => _overview?.reasons ?? const <String>[];

  Future<void> getOverview() async {
    _isLoading = true;
    notifyListeners();

    final dynamic response = await inventoryServiceInterface.getOverview();
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      _overview = InventoryOverviewModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> getMovements({int? productId, String? type, bool clearType = false, bool clearProduct = false}) async {
    if (clearProduct) {
      _productId = null;
    } else if (productId != null) {
      _productId = productId;
    }
    if (clearType) {
      _type = null;
    } else if (type != null) {
      _type = type;
    }

    _isLoading = true;
    notifyListeners();

    final dynamic response = await inventoryServiceInterface.getMovements(productId: _productId, type: _type);
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      _movements = StockMovementListModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> getWarehouses({int? productId}) async {
    final dynamic response = await inventoryServiceInterface.getWarehouses(productId: productId);
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      final dynamic rows = response.response!.data['warehouses'];
      _warehouses = rows is List
          ? rows.whereType<Map>().map((row) => WarehouseModel.fromJson(Map<String, dynamic>.from(row))).toList()
          : const <WarehouseModel>[];
      notifyListeners();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  Future<void> getBatches({int days = 30}) async {
    final dynamic response = await inventoryServiceInterface.getBatches(days: days);
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(response.response!.data);
      _expiringSoon = _batches(data['expiring_soon']);
      _expired = _batches(data['expired']);
      notifyListeners();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  /// Applies a signed correction.
  ///
  /// Returns null on success, or the reason it was refused — which the caller
  /// shows. A correction that silently does nothing is indistinguishable from
  /// one the seller mistyped.
  Future<String?> adjust({
    required int productId,
    required int delta,
    required String reason,
    String? note,
  }) async {
    _isAdjusting = true;
    notifyListeners();

    String? refusal;
    final dynamic response = await inventoryServiceInterface.adjust(
      productId: productId,
      delta: delta,
      reason: reason,
      note: note,
    );

    if (response is ApiResponse && response.response?.statusCode == 200) {
      await getMovements();
      await getOverview();
    } else if (response is ApiResponse) {
      refusal = _refusalFrom(response) ?? response.error?.toString();
      // Reported by the caller, so ApiChecker is not also asked to shout about
      // an outcome the screen is already explaining.
      if (refusal == null) ApiChecker.checkApi(response);
    }

    _isAdjusting = false;
    notifyListeners();
    return refusal;
  }

  String? _refusalFrom(ApiResponse response) {
    final dynamic data = response.response?.data;
    if (data is Map && data['errors'] is List && (data['errors'] as List).isNotEmpty) {
      final dynamic first = (data['errors'] as List).first;
      if (first is Map && first['message'] != null) return first['message'].toString();
    }
    return null;
  }

  List<ProductBatchModel> _batches(dynamic rows) => rows is List
      ? rows.whereType<Map>().map((row) => ProductBatchModel.fromJson(Map<String, dynamic>.from(row))).toList()
      : const <ProductBatchModel>[];
}
