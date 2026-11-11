import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class SecurityRepositoryInterface {
  Future<ApiResponse> getPermissions();
  Future<ApiResponse> getRoles();
  Future<ApiResponse> getStaff();
  Future<ApiResponse> getAccess();
  Future<ApiResponse> getAudit({String? action});

  Future<ApiResponse> saveRole(Map<String, dynamic> payload, {int? id});
  Future<ApiResponse> deleteRole(int id);
  Future<ApiResponse> saveStaff(Map<String, dynamic> payload, {int? id});
  Future<ApiResponse> signOutStaff(int id);
  Future<ApiResponse> deleteStaff(int id);

  Future<ApiResponse> getKeys();
  Future<ApiResponse> issueKey(Map<String, dynamic> payload);
  Future<ApiResponse> revokeKey(int id);

  Future<ApiResponse> getEvents();
  Future<ApiResponse> getWebhooks();
  Future<ApiResponse> saveWebhook(Map<String, dynamic> payload, {int? id});
  Future<ApiResponse> setWebhookStatus(int id, String status);
  Future<ApiResponse> deleteWebhook(int id);
  Future<ApiResponse> testWebhook(int id, String event);
  Future<ApiResponse> getDeliveries({int? webhookId});
}
