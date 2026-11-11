import 'package:syriacosmeticsmanger/features/security/domain/repositories/security_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/security/domain/services/security_service_interface.dart';

class SecurityService implements SecurityServiceInterface {
  final SecurityRepositoryInterface securityRepoInterface;
  SecurityService({required this.securityRepoInterface});

  @override
  Future getPermissions() => securityRepoInterface.getPermissions();

  @override
  Future getRoles() => securityRepoInterface.getRoles();

  @override
  Future getStaff() => securityRepoInterface.getStaff();

  @override
  Future getAccess() => securityRepoInterface.getAccess();

  @override
  Future getAudit({String? action}) => securityRepoInterface.getAudit(action: action);

  @override
  Future saveRole(Map<String, dynamic> payload, {int? id}) => securityRepoInterface.saveRole(payload, id: id);

  @override
  Future deleteRole(int id) => securityRepoInterface.deleteRole(id);

  @override
  Future saveStaff(Map<String, dynamic> payload, {int? id}) => securityRepoInterface.saveStaff(payload, id: id);

  @override
  Future signOutStaff(int id) => securityRepoInterface.signOutStaff(id);

  @override
  Future deleteStaff(int id) => securityRepoInterface.deleteStaff(id);

  @override
  Future getKeys() => securityRepoInterface.getKeys();

  @override
  Future issueKey(Map<String, dynamic> payload) => securityRepoInterface.issueKey(payload);

  @override
  Future revokeKey(int id) => securityRepoInterface.revokeKey(id);

  @override
  Future getEvents() => securityRepoInterface.getEvents();

  @override
  Future getWebhooks() => securityRepoInterface.getWebhooks();

  @override
  Future saveWebhook(Map<String, dynamic> payload, {int? id}) => securityRepoInterface.saveWebhook(payload, id: id);

  @override
  Future setWebhookStatus(int id, String status) => securityRepoInterface.setWebhookStatus(id, status);

  @override
  Future deleteWebhook(int id) => securityRepoInterface.deleteWebhook(id);

  @override
  Future testWebhook(int id, String event) => securityRepoInterface.testWebhook(id, event);

  @override
  Future getDeliveries({int? webhookId}) => securityRepoInterface.getDeliveries(webhookId: webhookId);
}
