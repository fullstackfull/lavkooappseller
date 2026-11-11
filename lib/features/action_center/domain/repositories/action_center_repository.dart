import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/repositories/action_center_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class ActionCenterRepository implements ActionCenterRepositoryInterface {
  final DioClient? dioClient;
  ActionCenterRepository({required this.dioClient});

  @override
  Future<ApiResponse> getInsights({String? severity, int limit = 50}) async {
    try {
      final response = await dioClient!.get(AppConstants.actionCenterUri, queryParameters: {
        'limit': limit,
        if (severity != null && severity.isNotEmpty) 'severity': severity,
      });
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> dismiss(int id) async {
    try {
      final response = await dioClient!.post('${AppConstants.actionCenterUri}/$id/dismiss', data: {});
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
