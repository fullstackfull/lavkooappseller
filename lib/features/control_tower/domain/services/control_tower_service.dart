import 'package:syriacosmeticsmanger/features/control_tower/domain/repositories/control_tower_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/control_tower/domain/services/control_tower_service_interface.dart';

class ControlTowerService implements ControlTowerServiceInterface {
  final ControlTowerRepositoryInterface controlTowerRepoInterface;
  ControlTowerService({required this.controlTowerRepoInterface});

  @override
  Future getTower() => controlTowerRepoInterface.getTower();

  @override
  Future getBriefing() => controlTowerRepoInterface.getBriefing();

  @override
  Future updateIssueStatus(int id, String status) =>
      controlTowerRepoInterface.updateIssueStatus(id, status);
}
