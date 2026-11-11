abstract class AutomationServiceInterface {
  Future<dynamic> getCatalogue();
  Future<dynamic> getRules();
  Future<dynamic> getRule(int id);
  Future<dynamic> previewRule(int id);
  Future<dynamic> runRule(int id);
  Future<dynamic> saveRule(Map<String, dynamic> payload, {int? id});
  Future<dynamic> setRuleStatus(int id, String status);
  Future<dynamic> deleteRule(int id);
  Future<dynamic> getActivity({int? ruleId});
  Future<dynamic> revertActivity(int id);
}
