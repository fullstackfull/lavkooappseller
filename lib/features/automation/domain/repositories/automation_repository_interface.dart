import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class AutomationRepositoryInterface {
  /// What a rule can be built out of, as the server describes it.
  Future<ApiResponse> getCatalogue();

  Future<ApiResponse> getRules();

  Future<ApiResponse> getRule(int id);

  /// What the rule would do right now. Writes nothing.
  Future<ApiResponse> previewRule(int id);

  Future<ApiResponse> runRule(int id);

  Future<ApiResponse> saveRule(Map<String, dynamic> payload, {int? id});

  Future<ApiResponse> setRuleStatus(int id, String status);

  Future<ApiResponse> deleteRule(int id);

  Future<ApiResponse> getActivity({int? ruleId});

  /// Undo one automated change.
  Future<ApiResponse> revertActivity(int id);
}
