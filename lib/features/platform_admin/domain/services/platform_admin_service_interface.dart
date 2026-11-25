import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_health_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';

abstract class PlatformAdminServiceInterface {
  /// A session, or the second step of the sign-in where the server wants one.
  Future<PlatformAdminResult<PlatformAdminSignInStep>> signIn({
    required String email,
    required String password,
    required String deviceName,
  });

  Future<PlatformAdminResult<PlatformAdminSignIn>> signInWithSecondFactor({
    required String challenge,
    required PlatformAdminMfaMethod method,
    required String code,
  });

  /// A success with no profile means there was no session to pick up; a failure
  /// of kind unauthenticated means there was one, and it is over.
  Future<PlatformAdminResult<PlatformAdminProfile?>> restore();

  Future<PlatformAdminResult<PlatformAdminProfile>> profile();

  Future<void> signOut();

  Future<PlatformAdminResult<PlatformMarketDirectory>> markets();

  /// [windowDays] is how many days, ending today, to count; with none the server
  /// counts its own default window.
  Future<PlatformAdminResult<PlatformOverviewModel>> overview({required String market, int? windowDays});

  /// Operational health per market. [windowDays] is how many days back to look;
  /// with none, the server chooses its own window.
  Future<PlatformAdminResult<PlatformHealthModel>> health({required String market, int? windowDays});

  Future<PlatformAdminResult<PlatformAlertPage>> alerts({required String market, required int page, String? severity});

  Future<PlatformAdminResult<List<PlatformSessionModel>>> sessions();

  Future<PlatformAdminResult<int>> endSession(int id);

  /// Succeeds with how many sessions were ended.
  Future<PlatformAdminResult<int>> endOtherSessions();

  Future<PlatformAdminResult<PlatformAuditPage>> auditLogs({required int page});
}
