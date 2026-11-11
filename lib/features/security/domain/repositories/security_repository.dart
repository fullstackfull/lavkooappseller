import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/security/domain/repositories/security_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class SecurityRepository implements SecurityRepositoryInterface {
  final DioClient? dioClient;
  SecurityRepository({required this.dioClient});

  String get _security => AppConstants.sellerSecurityUri;
  String get _integrations => AppConstants.sellerIntegrationsUri;

  @override
  Future<ApiResponse> getPermissions() => _get('$_security/permissions');

  @override
  Future<ApiResponse> getRoles() => _get('$_security/roles');

  @override
  Future<ApiResponse> getStaff() => _get('$_security/staff');

  @override
  Future<ApiResponse> getAccess() => _get('$_security/access');

  @override
  Future<ApiResponse> getAudit({String? action}) =>
      _get(action == null || action.isEmpty ? '$_security/audit' : '$_security/audit?action=$action');

  @override
  Future<ApiResponse> saveRole(Map<String, dynamic> payload, {int? id}) => _write(
        id == null ? '$_security/roles' : '$_security/roles/$id',
        payload,
        put: id != null,
      );

  @override
  Future<ApiResponse> deleteRole(int id) => _delete('$_security/roles/$id');

  @override
  Future<ApiResponse> saveStaff(Map<String, dynamic> payload, {int? id}) => _write(
        id == null ? '$_security/staff' : '$_security/staff/$id',
        payload,
        put: id != null,
      );

  @override
  Future<ApiResponse> signOutStaff(int id) => _write('$_security/staff/$id/sign-out', const {});

  @override
  Future<ApiResponse> deleteStaff(int id) => _delete('$_security/staff/$id');

  @override
  Future<ApiResponse> getKeys() => _get('$_integrations/keys');

  @override
  Future<ApiResponse> issueKey(Map<String, dynamic> payload) => _write('$_integrations/keys', payload);

  @override
  Future<ApiResponse> revokeKey(int id) => _delete('$_integrations/keys/$id');

  @override
  Future<ApiResponse> getEvents() => _get('$_integrations/events');

  @override
  Future<ApiResponse> getWebhooks() => _get('$_integrations/webhooks');

  @override
  Future<ApiResponse> saveWebhook(Map<String, dynamic> payload, {int? id}) => _write(
        id == null ? '$_integrations/webhooks' : '$_integrations/webhooks/$id',
        payload,
        put: id != null,
      );

  @override
  Future<ApiResponse> setWebhookStatus(int id, String status) =>
      _write('$_integrations/webhooks/$id/status', {'status': status}, put: true);

  @override
  Future<ApiResponse> deleteWebhook(int id) => _delete('$_integrations/webhooks/$id');

  @override
  Future<ApiResponse> testWebhook(int id, String event) =>
      _write('$_integrations/webhooks/$id/test', {'event': event});

  @override
  Future<ApiResponse> getDeliveries({int? webhookId}) => _get(
        webhookId == null ? '$_integrations/deliveries' : '$_integrations/deliveries?webhook_id=$webhookId',
      );

  Future<ApiResponse> _get(String uri) async {
    try {
      return ApiResponse.withSuccess(await dioClient!.get(uri));
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponse> _write(String uri, Map<String, dynamic> payload, {bool put = false}) async {
    try {
      final response = put ? await dioClient!.put(uri, data: payload) : await dioClient!.post(uri, data: payload);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponse> _delete(String uri) async {
    try {
      return ApiResponse.withSuccess(await dioClient!.delete(uri));
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
