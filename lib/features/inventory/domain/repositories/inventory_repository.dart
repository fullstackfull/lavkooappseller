import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/inventory/domain/repositories/inventory_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class InventoryRepository implements InventoryRepositoryInterface {
  final DioClient? dioClient;
  InventoryRepository({required this.dioClient});

  @override
  Future<ApiResponse> getOverview() => _get(AppConstants.inventoryOverviewUri, const {});

  @override
  Future<ApiResponse> getMovements({int? productId, String? type, int offset = 1}) =>
      _get(AppConstants.inventoryMovementsUri, {
        'limit': 25,
        'offset': offset,
        if (productId != null) 'product_id': productId,
        if (type != null && type.isNotEmpty) 'type': type,
      });

  @override
  Future<ApiResponse> getWarehouses({int? productId}) =>
      _get(AppConstants.inventoryWarehousesUri, {if (productId != null) 'product_id': productId});

  @override
  Future<ApiResponse> getBatches({int days = 30}) => _get(AppConstants.inventoryBatchesUri, {'days': days});

  @override
  Future<ApiResponse> adjust({required int productId, required int delta, required String reason, String? note}) async {
    try {
      final response = await dioClient!.post(
        '${AppConstants.inventoryAdjustUri}$productId/adjust',
        data: {
          'delta': delta,
          'reason': reason,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponse> _get(String uri, Map<String, dynamic> queryParameters) async {
    try {
      final response = await dioClient!.get(uri, queryParameters: queryParameters);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
