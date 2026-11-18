import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';

/// Everything the app asks of the platform admin API, and the one place its
/// session lives.
abstract class PlatformAdminRepositoryInterface {
  /// Signs in with the admin's own e-mail and password. On success the token is
  /// kept, here and in the platform's own secure storage.
  Future<PlatformAdminResult<PlatformAdminSignIn>> signIn({
    required String email,
    required String password,
    required String deviceName,
  });

  /// Picks up the session a previous launch left behind and asks the server who
  /// it belongs to. A success with no profile means there was no session; a
  /// failure of kind unauthenticated means there was one, and it is over.
  Future<PlatformAdminResult<PlatformAdminProfile?>> restore();

  Future<PlatformAdminResult<PlatformAdminProfile>> profile();

  /// Ends the session on this phone, whatever the server says, and then asks the
  /// server to end it there too.
  Future<void> signOut();

  Future<PlatformAdminResult<PlatformMarketDirectory>> markets();

  /// [from] is the first day of the window, `YYYY-MM-DD`; the window ends today.
  /// With none, the server chooses its own.
  Future<PlatformAdminResult<PlatformOverviewModel>> overview({required String market, String? from});

  Future<PlatformAdminResult<PlatformAlertPage>> alerts({
    required String market,
    required int page,
    required int perPage,
    String? severity,
  });

  Future<PlatformAdminResult<List<PlatformSessionModel>>> sessions();

  /// Ends one of the admin's own sessions; succeeds with its id.
  Future<PlatformAdminResult<int>> endSession(int id);

  Future<PlatformAdminResult<PlatformAuditPage>> auditLogs({required int page, required int perPage});
}
