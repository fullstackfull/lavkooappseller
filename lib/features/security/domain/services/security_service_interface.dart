abstract class SecurityServiceInterface {
  Future getPermissions();
  Future getRoles();
  Future getStaff();
  Future getAccess();
  Future getAudit({String? action});

  Future saveRole(Map<String, dynamic> payload, {int? id});
  Future deleteRole(int id);
  Future saveStaff(Map<String, dynamic> payload, {int? id});
  Future signOutStaff(int id);
  Future deleteStaff(int id);

  Future getKeys();
  Future issueKey(Map<String, dynamic> payload);
  Future revokeKey(int id);

  Future getEvents();
  Future getWebhooks();
  Future saveWebhook(Map<String, dynamic> payload, {int? id});
  Future setWebhookStatus(int id, String status);
  Future deleteWebhook(int id);
  Future testWebhook(int id, String event);
  Future getDeliveries({int? webhookId});
}
