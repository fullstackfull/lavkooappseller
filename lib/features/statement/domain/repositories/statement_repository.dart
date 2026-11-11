import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/statement/domain/repositories/statement_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class StatementRepository implements StatementRepositoryInterface {
  final DioClient? dioClient;
  StatementRepository({required this.dioClient});

  @override
  Future<ApiResponse> getStatement({String? entryType, String? status, String? from, String? to, int offset = 1}) async {
    try {
      final response = await dioClient!.get(
        AppConstants.statementUri,
        queryParameters: _query(entryType, status, from, to)..addAll({'limit': 25, 'offset': offset}),
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> exportStatement({String? entryType, String? status, String? from, String? to}) async {
    try {
      final response = await dioClient!.get(
        AppConstants.statementExportUri,
        queryParameters: _query(entryType, status, from, to),
        // The file comes back as bytes, not JSON.
        options: Options(responseType: ResponseType.bytes),
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Map<String, dynamic> _query(String? entryType, String? status, String? from, String? to) => {
        if (entryType != null && entryType.isNotEmpty) 'entry_type': entryType,
        if (status != null && status.isNotEmpty) 'status': status,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      };
}
