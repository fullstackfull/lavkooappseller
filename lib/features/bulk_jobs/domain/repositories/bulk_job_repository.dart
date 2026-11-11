import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/repositories/bulk_job_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class BulkJobRepository implements BulkJobRepositoryInterface {
  final DioClient? dioClient;
  BulkJobRepository({required this.dioClient});

  @override
  Future<ApiResponse> getBulkJobs({int offset = 1}) async {
    try {
      final response = await dioClient!.get(AppConstants.bulkJobsUri, queryParameters: {'limit': 20, 'offset': offset});
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getBulkJob(int id) async {
    try {
      final response = await dioClient!.get('${AppConstants.bulkJobsUri}/$id');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> submitPriceUpdate({
    required List<int> productIds,
    required String mode,
    required num value,
    num? discount,
    String? discountType,
  }) =>
      _post(AppConstants.bulkPriceUpdateUri, {
        'product_ids': productIds,
        'mode': mode,
        'value': value,
        if (discount != null) 'discount': discount,
        if (discount != null && discountType != null) 'discount_type': discountType,
      });

  @override
  Future<ApiResponse> submitStockUpdate({
    required List<int> productIds,
    required String mode,
    required int value,
    String? note,
  }) =>
      _post(AppConstants.bulkStockUpdateUri, {
        'product_ids': productIds,
        'mode': mode,
        'value': value,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  @override
  Future<ApiResponse> downloadFailures(int id) async {
    try {
      final response = await dioClient!.get(
        '${AppConstants.bulkJobsUri}/$id/failures',
        options: Options(responseType: ResponseType.bytes),
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponse> _post(String uri, Map<String, dynamic> body) async {
    try {
      final response = await dioClient!.post(uri, data: body);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
