import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/models/seller_insight_model.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/services/action_center_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// Everything waiting for the seller, worst first.
///
/// One store, read once: home, this list and the badge all read this controller,
/// so they cannot disagree about what needs attention. Nothing here is invented
/// to fill a screen — an empty list means nothing is waiting, and that is what
/// it says.
class ActionCenterController with ChangeNotifier {
  final ActionCenterServiceInterface actionCenterServiceInterface;
  ActionCenterController({required this.actionCenterServiceInterface});

  ActionCenterModel? _actionCenter;
  ActionCenterModel? get actionCenter => _actionCenter;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _severity;
  String? get severity => _severity;

  List<SellerInsightModel> get insights => _actionCenter?.insights ?? const <SellerInsightModel>[];

  int get total => _actionCenter?.total ?? 0;
  int get urgentCount => _actionCenter?.urgentCount ?? 0;

  int countOf(String severity) => _actionCenter?.counts[severity] ?? 0;

  Future<void> getInsights({String? severity, bool clearSeverity = false}) async {
    if (clearSeverity) {
      _severity = null;
    } else if (severity != null) {
      _severity = severity;
    }

    _isLoading = true;
    notifyListeners();

    final dynamic response = await actionCenterServiceInterface.getInsights(severity: _severity);
    if (response is ApiResponse && response.response?.statusCode == 200 && response.response?.data is Map) {
      _actionCenter = ActionCenterModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Hides one insight.
  ///
  /// The row is removed here as soon as the server accepts it rather than after
  /// a full reload, so the list does not flash; the counts come back from the
  /// next fetch, which is the only place they are ever computed.
  Future<bool> dismiss(int id) async {
    final dynamic response = await actionCenterServiceInterface.dismiss(id);

    if (response is ApiResponse && response.response?.statusCode == 200) {
      await getInsights();
      return true;
    }

    if (response is ApiResponse) ApiChecker.checkApi(response);
    return false;
  }
}
