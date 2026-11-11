import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/reports/domain/repositories/report_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class ReportRepository implements ReportRepositoryInterface {
  final DioClient? dioClient;
  ReportRepository({required this.dioClient});

  @override
  Future<ApiResponse> getOrderReport({
    String? dateType, String? from, String? to, String? search, int offset = 1,
  }) => _get(AppConstants.orderReportUri, _periodQuery(dateType, from, to, search, offset));

  @override
  Future<ApiResponse> getProductReport({
    String? dateType, String? from, String? to, String? search, int offset = 1,
  }) => _get(AppConstants.productReportUri, _periodQuery(dateType, from, to, search, offset));

  @override
  Future<ApiResponse> getStockReport({String? search, String? sort, int? categoryId, int offset = 1}) =>
      _get(AppConstants.stockReportUri, {
        'limit': 10,
        'offset': offset,
        if (search != null && search.isNotEmpty) 'search': search,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        if (categoryId != null) 'category_id': categoryId,
      });

  /// A custom range is the only period that carries dates; sending them with
  /// any other would have the server ignore them, and reading them back would
  /// then disagree with what the chips show.
  Map<String, dynamic> _periodQuery(String? dateType, String? from, String? to, String? search, int offset) => {
        'limit': 10,
        'offset': offset,
        if (dateType != null && dateType.isNotEmpty) 'date_type': dateType,
        if (dateType == 'custom_date' && from != null && from.isNotEmpty) 'from': from,
        if (dateType == 'custom_date' && to != null && to.isNotEmpty) 'to': to,
        if (search != null && search.isNotEmpty) 'search': search,
      };

  @override
  Future<ApiResponse> downloadExport(String uri, Map<String, dynamic> queryParameters) async {
    try {
      final response = await dioClient!.get(
        uri,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes),
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
