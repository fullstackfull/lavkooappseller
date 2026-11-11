import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class InventoryRepositoryInterface {
  Future<ApiResponse> getOverview();

  Future<ApiResponse> getMovements({int? productId, String? type, int offset = 1});

  Future<ApiResponse> getWarehouses({int? productId});

  Future<ApiResponse> getBatches({int days = 30});

  /// A signed correction with its reason. Never a bare stock write — the balance
  /// has to keep its history.
  Future<ApiResponse> adjust({required int productId, required int delta, required String reason, String? note});
}
