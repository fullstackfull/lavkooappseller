import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/automation/domain/repositories/automation_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class AutomationRepository implements AutomationRepositoryInterface {
  final DioClient? dioClient;
  AutomationRepository({required this.dioClient});

  @override
  Future<ApiResponse> getCatalogue() => _get('${AppConstants.automationUri}/catalogue');

  @override
  Future<ApiResponse> getRules() => _get('${AppConstants.automationUri}/rules');

  @override
  Future<ApiResponse> getRule(int id) => _get('${AppConstants.automationUri}/rules/$id');

  @override
  Future<ApiResponse> previewRule(int id) => _get('${AppConstants.automationUri}/rules/$id/preview');

  @override
  Future<ApiResponse> getActivity({int? ruleId}) => _get(
        ruleId == null
            ? '${AppConstants.automationUri}/activity'
            : '${AppConstants.automationUri}/activity?rule_id=$ruleId',
      );

  @override
  Future<ApiResponse> runRule(int id) => _post('${AppConstants.automationUri}/rules/$id/run');

  @override
  Future<ApiResponse> revertActivity(int id) => _post('${AppConstants.automationUri}/activity/$id/revert');

  @override
  Future<ApiResponse> saveRule(Map<String, dynamic> payload, {int? id}) async {
    try {
      final response = id == null
          ? await dioClient!.post('${AppConstants.automationUri}/rules', data: payload)
          : await dioClient!.put('${AppConstants.automationUri}/rules/$id', data: payload);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> setRuleStatus(int id, String status) async {
    try {
      final response = await dioClient!.put(
        '${AppConstants.automationUri}/rules/$id/status',
        data: {'status': status},
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> deleteRule(int id) async {
    try {
      final response = await dioClient!.delete('${AppConstants.automationUri}/rules/$id');
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

  Future<ApiResponse> _post(String uri) async {
    try {
      final response = await dioClient!.post(uri, data: const <String, dynamic>{});
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
