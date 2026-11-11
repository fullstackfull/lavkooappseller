import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/security/domain/models/security_models.dart';
import 'package:syriacosmeticsmanger/features/security/domain/services/security_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';

/// The shop's security desk and its integrations.
///
/// One controller for both because they answer the same question from two
/// sides — who can act as this shop — and because a seller looking at "who has
/// a way in" wants their people and their keys on one screen rather than two.
class SecurityController with ChangeNotifier {
  final SecurityServiceInterface securityServiceInterface;
  SecurityController({required this.securityServiceInterface});

  Map<String, List<String>> _permissionGroups = <String, List<String>>{};
  Map<String, List<String>> get permissionGroups => _permissionGroups;

  List<SellerRoleModel> _roles = <SellerRoleModel>[];
  List<SellerRoleModel> get roles => _roles;

  List<SellerStaffModel> _staff = <SellerStaffModel>[];
  List<SellerStaffModel> get staff => _staff;

  List<AccessHolderModel> _access = <AccessHolderModel>[];
  List<AccessHolderModel> get access => _access;

  List<AuditEntryModel> _audit = <AuditEntryModel>[];
  List<AuditEntryModel> get audit => _audit;

  List<ApiKeyModel> _keys = <ApiKeyModel>[];
  List<ApiKeyModel> get keys => _keys;

  List<String> _grantableScopes = <String>[];
  List<String> get grantableScopes => _grantableScopes;

  List<String> _events = <String>[];
  List<String> get events => _events;

  List<WebhookModel> _webhooks = <WebhookModel>[];
  List<WebhookModel> get webhooks => _webhooks;

  List<WebhookDeliveryModel> _deliveries = <WebhookDeliveryModel>[];
  List<WebhookDeliveryModel> get deliveries => _deliveries;

  String? _auditFilter;
  String? get auditFilter => _auditFilter;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// The plaintext of a key that was just issued.
  ///
  /// Held only until the seller dismisses it. There is no endpoint that returns
  /// it again, so the screen has to make that plain rather than letting them
  /// close the sheet and come back for it.
  String? _freshKey;
  String? get freshKey => _freshKey;

  /// Same for a webhook's signing secret.
  String? _freshSecret;
  String? get freshSecret => _freshSecret;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      _loadPermissions(),
      _loadRoles(),
      _loadStaff(),
      _loadAccess(),
      _loadAudit(),
      _loadKeys(),
      _loadEvents(),
      _loadWebhooks(),
      _loadDeliveries(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  void clearFreshCredentials() {
    _freshKey = null;
    _freshSecret = null;
    notifyListeners();
  }

  Future<void> filterAudit(String? action) async {
    _auditFilter = action;
    await _loadAudit();
    notifyListeners();
  }

  Future<bool> saveRole({int? id, required String name, required List<String> permissions}) =>
      _write(() => securityServiceInterface.saveRole({'name': name, 'permissions': permissions}, id: id));

  Future<bool> deleteRole(int id) => _write(() => securityServiceInterface.deleteRole(id));

  Future<bool> saveStaff({
    int? id,
    required String name,
    String? email,
    String? password,
    int? roleId,
    String status = 'active',
  }) {
    final Map<String, dynamic> payload = {'name': name, 'seller_role_id': roleId, 'status': status};

    if (email != null && email.isNotEmpty) payload['email'] = email;
    if (password != null && password.isNotEmpty) payload['password'] = password;

    return _write(() => securityServiceInterface.saveStaff(payload, id: id));
  }

  Future<bool> signOutStaff(int id) => _write(() => securityServiceInterface.signOutStaff(id));

  Future<bool> deleteStaff(int id) => _write(() => securityServiceInterface.deleteStaff(id));

  /// Issue a key and hold on to the plaintext for the one moment it exists.
  Future<bool> issueKey({required String name, required List<String> scopes}) async {
    _isSaving = true;
    notifyListeners();

    final dynamic response = await securityServiceInterface.issueKey({'name': name, 'scopes': scopes});
    final bool ok = _succeeded(response);

    if (ok && response is ApiResponse && response.response?.data is Map) {
      _freshKey = Map<String, dynamic>.from(response.response!.data)['key']?.toString();
    } else if (response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isSaving = false;
    if (ok) await load();
    notifyListeners();

    return ok;
  }

  Future<bool> revokeKey(int id) => _write(() => securityServiceInterface.revokeKey(id));

  Future<bool> saveWebhook({
    int? id,
    required String name,
    required String url,
    required List<String> events,
  }) async {
    _isSaving = true;
    notifyListeners();

    final dynamic response = await securityServiceInterface.saveWebhook(
      {'name': name, 'url': url, 'events': events},
      id: id,
    );
    final bool ok = _succeeded(response);

    if (ok && id == null && response is ApiResponse && response.response?.data is Map) {
      _freshSecret = Map<String, dynamic>.from(response.response!.data)['secret']?.toString();
    } else if (!ok && response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isSaving = false;
    if (ok) await load();
    notifyListeners();

    return ok;
  }

  Future<bool> setWebhookStatus(int id, String status) =>
      _write(() => securityServiceInterface.setWebhookStatus(id, status));

  Future<bool> deleteWebhook(int id) => _write(() => securityServiceInterface.deleteWebhook(id));

  Future<bool> testWebhook(int id, String event) =>
      _write(() => securityServiceInterface.testWebhook(id, event));

  /// Deliveries for one endpoint, or all of them when nothing is named.
  Future<void> showDeliveriesFor(int? webhookId) async {
    await _loadDeliveries(webhookId: webhookId);
    notifyListeners();
  }

  Future<bool> _write(Future Function() call) async {
    _isSaving = true;
    notifyListeners();

    final dynamic response = await call();
    final bool ok = _succeeded(response);

    if (!ok && response is ApiResponse) {
      ApiChecker.checkApi(response);
    }

    _isSaving = false;
    // Reloaded rather than patched in place: a role change moves people between
    // rows, and a screen that only edited one label would show a team that does
    // not exist.
    if (ok) await load();
    notifyListeners();

    return ok;
  }

  bool _succeeded(dynamic response) {
    final int? code = response is ApiResponse ? response.response?.statusCode : null;

    return code != null && code >= 200 && code < 300;
  }

  Future<void> _loadPermissions() async {
    final Map<String, dynamic>? data = await _read(securityServiceInterface.getPermissions());
    final dynamic groups = data?['groups'];

    if (groups is Map) {
      _permissionGroups = groups.map(
        (key, value) => MapEntry(key.toString(), value is List ? value.map((e) => e.toString()).toList() : <String>[]),
      );
    }
  }

  Future<void> _loadRoles() async {
    final Map<String, dynamic>? data = await _read(securityServiceInterface.getRoles());
    _roles = _list(data?['roles'], SellerRoleModel.fromJson);
  }

  Future<void> _loadStaff() async {
    final Map<String, dynamic>? data = await _read(securityServiceInterface.getStaff());
    _staff = _list(data?['staff'], SellerStaffModel.fromJson);
  }

  Future<void> _loadAccess() async {
    final Map<String, dynamic>? data = await _read(securityServiceInterface.getAccess());
    _access = _list(data?['holders'], AccessHolderModel.fromJson);
  }

  Future<void> _loadAudit() async {
    final Map<String, dynamic>? data = await _read(securityServiceInterface.getAudit(action: _auditFilter));
    _audit = _list(data?['entries'], AuditEntryModel.fromJson);
  }

  Future<void> _loadKeys() async {
    final Map<String, dynamic>? data = await _read(securityServiceInterface.getKeys());
    _keys = _list(data?['keys'], ApiKeyModel.fromJson);
    _grantableScopes = data?['grantable_scopes'] is List
        ? (data!['grantable_scopes'] as List).map((e) => e.toString()).toList()
        : <String>[];
  }

  Future<void> _loadEvents() async {
    final Map<String, dynamic>? data = await _read(securityServiceInterface.getEvents());
    _events = data?['events'] is List ? (data!['events'] as List).map((e) => e.toString()).toList() : <String>[];
  }

  Future<void> _loadWebhooks() async {
    final Map<String, dynamic>? data = await _read(securityServiceInterface.getWebhooks());
    _webhooks = _list(data?['webhooks'], WebhookModel.fromJson);
  }

  Future<void> _loadDeliveries({int? webhookId}) async {
    final Map<String, dynamic>? data = await _read(securityServiceInterface.getDeliveries(webhookId: webhookId));
    _deliveries = _list(data?['deliveries'], WebhookDeliveryModel.fromJson);
  }

  Future<Map<String, dynamic>?> _read(Future response) async {
    final dynamic result = await response;

    if (result is ApiResponse && result.response?.statusCode == 200 && result.response?.data is Map) {
      return Map<String, dynamic>.from(result.response!.data);
    }

    if (result is ApiResponse) {
      ApiChecker.checkApi(result);
    }

    return null;
  }

  List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) build) => raw is List
      ? raw.whereType<Map>().map((e) => build(Map<String, dynamic>.from(e))).toList()
      : <T>[];
}
