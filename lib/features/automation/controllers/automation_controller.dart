import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/automation/domain/models/automation_models.dart';
import 'package:syriacosmeticsmanger/features/automation/domain/services/automation_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// The seller's rules and what they have done.
///
/// The preview is held separately from the rule list and cleared whenever the
/// form changes, because a preview of the last rule shown under a different one
/// is worse than no preview at all — it is a confident answer to the wrong
/// question.
class AutomationController with ChangeNotifier {
  final AutomationServiceInterface automationServiceInterface;
  AutomationController({required this.automationServiceInterface});

  AutomationCatalogueModel? _catalogue;
  AutomationCatalogueModel? get catalogue => _catalogue;

  List<AutomationRuleModel> _rules = const <AutomationRuleModel>[];
  List<AutomationRuleModel> get rules => _rules;

  List<AutomationActivityModel> _activity = const <AutomationActivityModel>[];
  List<AutomationActivityModel> get activity => _activity;

  List<AutomationRunModel> _runs = const <AutomationRunModel>[];
  List<AutomationRunModel> get runs => _runs;

  AutomationPreviewModel? _preview;
  AutomationPreviewModel? get preview => _preview;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  int? _previewingRuleId;
  int? get previewingRuleId => _previewingRuleId;

  /// The last validation failures the server sent back, keyed by field.
  Map<String, String> _fieldErrors = const <String, String>{};
  Map<String, String> get fieldErrors => _fieldErrors;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([_loadCatalogue(), _loadRules(), loadActivity(notify: false)]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCatalogue() async {
    final dynamic response = await automationServiceInterface.getCatalogue();
    if (_ok(response) && response.response?.data is Map) {
      _catalogue = AutomationCatalogueModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  Future<void> _loadRules() async {
    final dynamic response = await automationServiceInterface.getRules();
    if (_ok(response) && response.response?.data is Map) {
      final List rows = response.response!.data['rules'] as List? ?? const [];
      _rules = rows
          .whereType<Map>()
          .map((e) => AutomationRuleModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }
  }

  Future<void> loadActivity({int? ruleId, bool notify = true}) async {
    final dynamic response = await automationServiceInterface.getActivity(ruleId: ruleId);
    if (_ok(response) && response.response?.data is Map) {
      final List rows = response.response!.data['actions'] as List? ?? const [];
      _activity = rows
          .whereType<Map>()
          .map((e) => AutomationActivityModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    if (notify) notifyListeners();
  }

  Future<void> loadRuns(int ruleId) async {
    final dynamic response = await automationServiceInterface.getRule(ruleId);
    if (_ok(response) && response.response?.data is Map) {
      final List rows = response.response!.data['runs'] as List? ?? const [];
      _runs = rows
          .whereType<Map>()
          .map((e) => AutomationRunModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    notifyListeners();
  }

  Future<void> loadPreview(int ruleId) async {
    _previewingRuleId = ruleId;
    _preview = null;
    notifyListeners();

    final dynamic response = await automationServiceInterface.previewRule(ruleId);
    if (_ok(response) && response.response?.data is Map) {
      _preview = AutomationPreviewModel.fromJson(Map<String, dynamic>.from(response.response!.data));
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _previewingRuleId = null;
    notifyListeners();
  }

  void clearPreview() {
    _preview = null;
    _previewingRuleId = null;
    notifyListeners();
  }

  Future<bool> saveRule(Map<String, dynamic> payload, {int? id}) async {
    _isBusy = true;
    _fieldErrors = const <String, String>{};
    notifyListeners();

    final dynamic response = await automationServiceInterface.saveRule(payload, id: id);
    final bool ok = response is ApiResponse &&
        (response.response?.statusCode == 200 || response.response?.statusCode == 201);

    if (ok) {
      await _loadRules();
    } else if (response is ApiResponse) {
      _fieldErrors = _errorsFrom(response);
      // Only surface the generic handler when the server did not say which
      // field was wrong — a form that can point at the field should.
      if (_fieldErrors.isEmpty) ApiChecker.checkApi(response);
    }

    _isBusy = false;
    notifyListeners();
    return ok;
  }

  Future<bool> setStatus(int ruleId, String status) async {
    final dynamic response = await automationServiceInterface.setRuleStatus(ruleId, status);
    final bool ok = _ok(response);

    if (ok) {
      await _loadRules();
      notifyListeners();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    return ok;
  }

  Future<bool> deleteRule(int ruleId) async {
    final dynamic response = await automationServiceInterface.deleteRule(ruleId);
    final bool ok = _ok(response);

    if (ok) {
      await _loadRules();
      notifyListeners();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    return ok;
  }

  Future<bool> runRule(int ruleId) async {
    _isBusy = true;
    notifyListeners();

    final dynamic response = await automationServiceInterface.runRule(ruleId);
    final bool ok = _ok(response);

    if (ok) {
      // A run can change both the rule's counters and what it has done, so both
      // are refetched rather than patched.
      await Future.wait([_loadRules(), loadActivity(notify: false)]);
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isBusy = false;
    notifyListeners();
    return ok;
  }

  Future<bool> revert(int activityId) async {
    _isBusy = true;
    notifyListeners();

    final dynamic response = await automationServiceInterface.revertActivity(activityId);
    final bool ok = _ok(response);

    if (ok) {
      await loadActivity(notify: false);
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isBusy = false;
    notifyListeners();
    return ok;
  }

  bool _ok(dynamic response) =>
      response is ApiResponse && response.response?.statusCode == 200;

  /// The API answers validation failures as `errors: [{code, message}]`, where
  /// the code is the field — including the dotted `action_settings.floor` form
  /// for a settings bag.
  Map<String, String> _errorsFrom(ApiResponse response) {
    final dynamic data = response.response?.data;
    if (data is! Map || data['errors'] is! List) return const <String, String>{};

    final Map<String, String> errors = <String, String>{};
    for (final dynamic row in data['errors'] as List) {
      if (row is Map && row['code'] != null && row['message'] != null) {
        errors[row['code'].toString()] = row['message'].toString();
      }
    }
    return errors;
  }
}
