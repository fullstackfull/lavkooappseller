import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class ControlTowerRepositoryInterface {
  Future<ApiResponse> getTower();

  Future<ApiResponse> getBriefing();

  /// Acknowledge, start, or park an issue. Resolution is not settable — the
  /// detector decides that by ceasing to report.
  Future<ApiResponse> updateIssueStatus(int id, String status);
}
