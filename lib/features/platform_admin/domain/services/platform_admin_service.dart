import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_health_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/services/platform_admin_service_interface.dart';

class PlatformAdminService implements PlatformAdminServiceInterface {
  /// The most the API gives a page of alerts.
  static const int alertsPerPage = 50;

  /// What the API gives a page of the audit log when it is not told.
  static const int auditLinesPerPage = 25;

  final PlatformAdminRepositoryInterface platformAdminRepoInterface;
  final DateTime Function() _now;

  PlatformAdminService({required this.platformAdminRepoInterface, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  @override
  Future<PlatformAdminResult<PlatformAdminSignInStep>> signIn({
    required String email,
    required String password,
    required String deviceName,
  }) =>
      platformAdminRepoInterface.signIn(email: email, password: password, deviceName: deviceName);

  @override
  Future<PlatformAdminResult<PlatformAdminSignIn>> signInWithSecondFactor({
    required String challenge,
    required PlatformAdminMfaMethod method,
    required String code,
  }) =>
      platformAdminRepoInterface.signInWithSecondFactor(challenge: challenge, method: method, code: code);

  @override
  Future<PlatformAdminResult<PlatformAdminProfile?>> restore() => platformAdminRepoInterface.restore();

  @override
  Future<PlatformAdminResult<PlatformAdminProfile>> profile() => platformAdminRepoInterface.profile();

  @override
  Future<void> signOut() => platformAdminRepoInterface.signOut();

  @override
  Future<PlatformAdminResult<PlatformMarketDirectory>> markets() => platformAdminRepoInterface.markets();

  @override
  Future<PlatformAdminResult<PlatformOverviewModel>> overview({required String market, int? windowDays}) =>
      platformAdminRepoInterface.overview(
        market: market,
        from: windowDays == null ? null : PlatformWindows.firstDay(days: windowDays, today: _now()),
      );

  @override
  Future<PlatformAdminResult<PlatformHealthModel>> health({required String market, int? windowDays}) =>
      platformAdminRepoInterface.health(
        market: market,
        from: windowDays == null ? null : PlatformWindows.firstDay(days: windowDays, today: _now()),
      );

  @override
  Future<PlatformAdminResult<PlatformAlertPage>> alerts(
          {required String market, required int page, String? severity}) =>
      platformAdminRepoInterface.alerts(market: market, page: page, perPage: alertsPerPage, severity: severity);

  @override
  Future<PlatformAdminResult<List<PlatformSessionModel>>> sessions() => platformAdminRepoInterface.sessions();

  @override
  Future<PlatformAdminResult<int>> endSession(int id) => platformAdminRepoInterface.endSession(id);

  @override
  Future<PlatformAdminResult<int>> endOtherSessions() => platformAdminRepoInterface.endOtherSessions();

  @override
  Future<PlatformAdminResult<PlatformAuditPage>> auditLogs({required int page}) =>
      platformAdminRepoInterface.auditLogs(page: page, perPage: auditLinesPerPage);
}
