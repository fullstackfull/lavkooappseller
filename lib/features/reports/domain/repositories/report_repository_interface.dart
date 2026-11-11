import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class ReportRepositoryInterface {
  Future<ApiResponse> getOrderReport({String? dateType, String? from, String? to, String? search, int offset = 1});

  Future<ApiResponse> getProductReport({String? dateType, String? from, String? to, String? search, int offset = 1});

  Future<ApiResponse> getStockReport({String? search, String? sort, int? categoryId, int offset = 1});

  /// Fetches an export as raw bytes. The file comes back as a binary body, not
  /// JSON, so the response type has to be set for this call alone — leaving the
  /// client's default would have Dio try to decode a spreadsheet as text.
  Future<ApiResponse> downloadExport(String uri, Map<String, dynamic> queryParameters);
}
