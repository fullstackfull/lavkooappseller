import 'package:syriacosmeticsmanger/features/automation/domain/repositories/automation_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/automation/domain/services/automation_service_interface.dart';

class AutomationService implements AutomationServiceInterface {
  final AutomationRepositoryInterface automationRepoInterface;
  AutomationService({required this.automationRepoInterface});

  @override
  Future getCatalogue() => automationRepoInterface.getCatalogue();

  @override
  Future getRules() => automationRepoInterface.getRules();

  @override
  Future getRule(int id) => automationRepoInterface.getRule(id);

  @override
  Future previewRule(int id) => automationRepoInterface.previewRule(id);

  @override
  Future runRule(int id) => automationRepoInterface.runRule(id);

  @override
  Future saveRule(Map<String, dynamic> payload, {int? id}) =>
      automationRepoInterface.saveRule(payload, id: id);

  @override
  Future setRuleStatus(int id, String status) => automationRepoInterface.setRuleStatus(id, status);

  @override
  Future deleteRule(int id) => automationRepoInterface.deleteRule(id);

  @override
  Future getActivity({int? ruleId}) => automationRepoInterface.getActivity(ruleId: ruleId);

  @override
  Future revertActivity(int id) => automationRepoInterface.revertActivity(id);
}
