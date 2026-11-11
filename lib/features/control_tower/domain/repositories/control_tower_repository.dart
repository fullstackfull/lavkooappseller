import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/control_tower/domain/repositories/control_tower_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class ControlTowerRepository implements ControlTowerRepositoryInterface {
  final DioClient? dioClient;
  ControlTowerRepository({required this.dioClient});

  @override
  Future<ApiResponse> getTower() => _get(AppConstants.controlTowerUri);

  @override
  Future<ApiResponse> getBriefing() => _get(AppConstants.dailyBriefingUri);

  @override
  Future<ApiResponse> updateIssueStatus(int id, String status) async {
    try {
      final response = await dioClient!.put(
        '${AppConstants.controlTowerIssueUri}$id/status',
        data: {'status': status},
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponse> _get(String uri) async {
    try {
      final response = await dioClient!.get(uri);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
