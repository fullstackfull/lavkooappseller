import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/control_tower/domain/models/control_tower_models.dart';
import 'package:syriacosmeticsmanger/features/control_tower/domain/services/control_tower_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// What is wrong, and what the day looks like.
///
/// Both are fetched together because the screen shows them together, and
/// separately from everything else because a slow tower must not keep the rest
/// of the app from rendering.
class ControlTowerController with ChangeNotifier {
  final ControlTowerServiceInterface controlTowerServiceInterface;
  ControlTowerController({required this.controlTowerServiceInterface});

  ControlTowerModel? _tower;
  ControlTowerModel? get tower => _tower;

  DailyBriefingModel? _briefing;
  DailyBriefingModel? get briefing => _briefing;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int? _updatingIssueId;
  int? get updatingIssueId => _updatingIssueId;

  List<TowerSectionModel> get sections => _tower?.populated ?? const <TowerSectionModel>[];

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([_loadTower(), _loadBriefing()]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadTower() async {
    final dynamic response = await controlTowerServiceInterface.getTower();
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      _tower = ControlTowerModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  Future<void> _loadBriefing() async {
    final dynamic response = await controlTowerServiceInterface.getBriefing();
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      _briefing = DailyBriefingModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  /// Say what is being done about an issue.
  ///
  /// Reloads the tower on success rather than editing the row in place: moving
  /// an issue can move it between sections, and a screen that only changed a
  /// label would leave it under the wrong heading.
  Future<bool> setStatus(int issueId, String status) async {
    _updatingIssueId = issueId;
    notifyListeners();

    final dynamic response = await controlTowerServiceInterface.updateIssueStatus(issueId, status);
    final bool ok = response is ApiResponse && response.response?.statusCode == 200;

    if (ok) {
      await _loadTower();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _updatingIssueId = null;
    notifyListeners();
    return ok;
  }
}
