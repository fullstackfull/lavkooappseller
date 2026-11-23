import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/services/platform_admin_service.dart';

/// How a window is asked for, and the sizes of the pages the screens ask for.
void main() {
  late _RecordingRepository repository;

  PlatformAdminService serviceAt(DateTime now) {
    repository = _RecordingRepository();
    return PlatformAdminService(platformAdminRepoInterface: repository, now: () => now);
  }

  group('the first day of a window', () {
    test('a window of n days ending today starts n - 1 days before today', () {
      final DateTime today = DateTime(2026, 11, 17, 23, 59);

      expect(PlatformWindows.firstDay(days: 1, today: today), '2026-11-17');
      expect(PlatformWindows.firstDay(days: 7, today: today), '2026-11-11');
      expect(PlatformWindows.firstDay(days: 30, today: today), '2026-10-19');
      expect(PlatformWindows.firstDay(days: 92, today: today), '2026-08-18');
    });

    test('crosses a month, a year and a leap day as the calendar does', () {
      expect(PlatformWindows.firstDay(days: 7, today: DateTime(2026, 3, 3)), '2026-02-25');
      expect(PlatformWindows.firstDay(days: 7, today: DateTime(2028, 3, 3)), '2028-02-26');
      expect(PlatformWindows.firstDay(days: 92, today: DateTime(2026, 1, 10)), '2025-10-11');
    });

    test('is the same wherever the clocks change, because it counts days and not hours', () {
      expect(PlatformWindows.firstDay(days: 7, today: DateTime(2026, 3, 29)), '2026-03-23');
      expect(PlatformWindows.firstDay(days: 7, today: DateTime(2026, 10, 26)), '2026-10-20');
    });

    test('is written with the digits the API reads, whatever the language of the app', () async {
      await initializeDateFormatting('ar', null);
      final String? before = Intl.defaultLocale;
      Intl.defaultLocale = 'ar';

      try {
        expect(PlatformWindows.firstDay(days: 7, today: DateTime(2026, 1, 9)), '2026-01-03');
      } finally {
        Intl.defaultLocale = before;
      }
    });

    test('offers a week, a month and the longest the API allows, and the month is what the API answers by default', () {
      expect(PlatformWindows.choices, <int>[7, 30, 92]);
      expect(PlatformWindows.defaultDays, 30);
      expect(PlatformWindows.choices, contains(PlatformWindows.defaultDays));
    });
  });

  group('the service', () {
    test('asks the overview for a window by its first day, counted from today', () async {
      final PlatformAdminService service = serviceAt(DateTime(2026, 11, 17, 9));

      await service.overview(market: 'KW', windowDays: 7);

      expect(repository.overviewCalls, <String>['KW from 2026-11-11']);
    });

    test('asks for no window at all when it has none, so the server chooses its own', () async {
      final PlatformAdminService service = serviceAt(DateTime(2026, 11, 17, 9));

      await service.overview(market: 'all');

      expect(repository.overviewCalls, <String>['all from null']);
    });

    test('asks for the largest page of alerts the API gives, with the filters it was handed', () async {
      final PlatformAdminService service = serviceAt(DateTime(2026, 11, 17));

      await service.alerts(market: 'KW', page: 2, severity: 'critical');
      await service.alerts(market: 'all', page: 1);

      expect(repository.alertCalls, <String>['KW p2 x50 critical', 'all p1 x50 null']);
    });

    test('asks for the default page of the audit log', () async {
      final PlatformAdminService service = serviceAt(DateTime(2026, 11, 17));

      await service.auditLogs(page: 3);

      expect(repository.auditCalls, <String>['p3 x25']);
    });

    test('hands a sign-in to the repository as it is, and nothing is added to it', () async {
      final PlatformAdminService service = serviceAt(DateTime(2026, 11, 17));

      await service.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');

      expect(repository.signIns, <String>['owner@example.test/a-password/Pixel 9']);
    });

    test('hands the second step to the repository as it is: the challenge, the way and the code', () async {
      final PlatformAdminService service = serviceAt(DateTime(2026, 11, 17));

      await service.signInWithSecondFactor(
          challenge: 'lkpc_x', method: PlatformAdminMfaMethod.recoveryCode, code: 'abcde-fghj2');

      expect(repository.secondSteps, <String>['lkpc_x/recoveryCode/abcde-fghj2']);
    });

    test('asks the repository to end the other sessions, and nothing more', () async {
      final PlatformAdminService service = serviceAt(DateTime(2026, 11, 17));

      await service.endOtherSessions();

      expect(repository.endOtherSessionsCalls, 1);
    });
  });
}

class _RecordingRepository implements PlatformAdminRepositoryInterface {
  final List<String> overviewCalls = <String>[];
  final List<String> alertCalls = <String>[];
  final List<String> auditCalls = <String>[];
  final List<String> signIns = <String>[];
  final List<String> secondSteps = <String>[];
  int endOtherSessionsCalls = 0;

  static const PlatformAdminResult<Never> _nothing = PlatformAdminResult<Never>.failure(PlatformAdminFailure.network());

  @override
  Future<PlatformAdminResult<PlatformOverviewModel>> overview({required String market, String? from}) async {
    overviewCalls.add('$market from $from');
    return _nothing;
  }

  @override
  Future<PlatformAdminResult<PlatformAlertPage>> alerts({
    required String market,
    required int page,
    required int perPage,
    String? severity,
  }) async {
    alertCalls.add('$market p$page x$perPage $severity');
    return _nothing;
  }

  @override
  Future<PlatformAdminResult<PlatformAuditPage>> auditLogs({required int page, required int perPage}) async {
    auditCalls.add('p$page x$perPage');
    return _nothing;
  }

  @override
  Future<PlatformAdminResult<PlatformAdminSignInStep>> signIn({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    signIns.add('$email/$password/$deviceName');
    return _nothing;
  }

  @override
  Future<PlatformAdminResult<PlatformAdminSignIn>> signInWithSecondFactor({
    required String challenge,
    required PlatformAdminMfaMethod method,
    required String code,
  }) async {
    secondSteps.add('$challenge/${method.name}/$code');
    return _nothing;
  }

  @override
  Future<PlatformAdminResult<int>> endOtherSessions() async {
    endOtherSessionsCalls++;
    return _nothing;
  }

  @override
  Future<PlatformAdminResult<PlatformAdminProfile?>> restore() => throw UnimplementedError();

  @override
  Future<PlatformAdminResult<PlatformAdminProfile>> profile() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<PlatformAdminResult<PlatformMarketDirectory>> markets() => throw UnimplementedError();

  @override
  Future<PlatformAdminResult<List<PlatformSessionModel>>> sessions() => throw UnimplementedError();

  @override
  Future<PlatformAdminResult<int>> endSession(int id) => throw UnimplementedError();
}
