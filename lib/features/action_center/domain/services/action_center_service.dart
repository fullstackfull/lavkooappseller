import 'package:syriacosmeticsmanger/features/action_center/domain/repositories/action_center_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/services/action_center_service_interface.dart';

class ActionCenterService implements ActionCenterServiceInterface {
  final ActionCenterRepositoryInterface actionCenterRepoInterface;
  ActionCenterService({required this.actionCenterRepoInterface});

  @override
  Future getInsights({String? severity, int limit = 50}) =>
      actionCenterRepoInterface.getInsights(severity: severity, limit: limit);

  @override
  Future dismiss(int id) => actionCenterRepoInterface.dismiss(id);
}
