abstract class ControlTowerServiceInterface {
  Future getTower();

  Future getBriefing();

  Future updateIssueStatus(int id, String status);
}
