import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/returns/domain/repositories/return_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class ReturnRepository implements ReturnRepositoryInterface {
  final DioClient? dioClient;
  ReturnRepository({required this.dioClient});

  @override
  Future<ApiResponse> getReturns({String? status, int offset = 1}) async {
    try {
      final response = await dioClient!.get(AppConstants.returnsUri, queryParameters: {
        'limit': 25,
        'offset': offset,
        if (status != null && status.isNotEmpty) 'status': status,
      });
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getReturn(int id) async {
    try {
      final response = await dioClient!.get('${AppConstants.returnsUri}/$id');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> markInTransit(int id, {String? carrier, String? trackingNumber}) => _post('$id/in-transit', {
        if (carrier != null && carrier.isNotEmpty) 'carrier': carrier,
        if (trackingNumber != null && trackingNumber.isNotEmpty) 'tracking_number': trackingNumber,
      });

  @override
  Future<ApiResponse> receive(int id, {required bool restock}) => _post('$id/receive', {'restock': restock});

  @override
  Future<ApiResponse> reject(int id, {required String reason}) => _post('$id/reject', {'reason': reason});

  Future<ApiResponse> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await dioClient!.post('${AppConstants.returnsUri}/$path', data: body);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
