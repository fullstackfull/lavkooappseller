import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class BulkJobRepositoryInterface {
  Future<ApiResponse> getBulkJobs({int offset = 1});

  Future<ApiResponse> getBulkJob(int id);

  Future<ApiResponse> submitPriceUpdate({
    required List<int> productIds,
    required String mode,
    required num value,
    num? discount,
    String? discountType,
  });

  Future<ApiResponse> submitStockUpdate({
    required List<int> productIds,
    required String mode,
    required int value,
    String? note,
  });

  /// The refused rows as a CSV. Bytes, not JSON — the response type has to be
  /// set for this call alone, or Dio tries to decode a file as text.
  Future<ApiResponse> downloadFailures(int id);
}
