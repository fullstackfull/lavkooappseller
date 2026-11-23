import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_capability_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';

/// What the admin may do is what the server says, and the app says so when the server changes its mind.
///
/// The example grant of the backend's runbook is a country manager who is given the overview and the
/// alerts and nothing else: no markets, no audit log, no sessions. That is the viewer most of these tests are.
void main() {
  late FakePlatformAdminService service;
  late DateTime now;

  setUp(() {
    service = FakePlatformAdminService();
    now = DateTime.utc(2026, 11, 17, 10);
  });

  PlatformAdminProfile countryManager() => PlatformAdminProfile.fromJson(fixtureData('me_restricted_capabilities'));

  PlatformAdminProfile owner() => PlatformAdminProfile.fromJson(fixtureData('me_with_capabilities'));

  /// The platform owner, with the same markets and the same scope, and only these parts of the API.
  PlatformAdminProfile ownerWith(List<String> capabilities) => PlatformAdminProfile.fromJson(
      <String, dynamic>{...fixtureData('me_with_capabilities'), 'capabilities': capabilities});

  Future<PlatformAdminController> signedInAs(PlatformAdminProfile profile) async {
    final PlatformAdminController controller =
        PlatformAdminController(platformAdminServiceInterface: service, now: () => now);
    service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(profile);
    service.onProfile = () async => PlatformAdminResult<PlatformAdminProfile>.success(profile);
    await controller.restoreSession();
    service.calls.clear();
    return controller;
  }

  PlatformAdminResult<T> notIncluded<T>([String fixtureName = 'error_capability_not_allowed']) =>
      refused<T>(fixtureName);

  group('what the admin may do', () {
    test('is what the server listed for the grant, and nothing is included for nobody', () async {
      final PlatformAdminController controller = PlatformAdminController(platformAdminServiceInterface: service);

      expect(PlatformCapability.values.any(controller.can), isFalse);
      await signedInAs(countryManager()).then((PlatformAdminController signedIn) {
        expect(signedIn.can(PlatformCapability.overview), isTrue);
        expect(signedIn.can(PlatformCapability.alerts), isTrue);
        expect(signedIn.can(PlatformCapability.markets), isFalse);
        expect(signedIn.can(PlatformCapability.audit), isFalse);
        expect(signedIn.can(PlatformCapability.sessions), isFalse);
      });
    });

    test('is everything for the platform owner, and for a server that does not list capabilities', () async {
      expect(PlatformCapability.values.every((await signedInAs(owner())).can), isTrue);
      expect(PlatformCapability.values.every((await signedInAs(ownerProfile())).can), isTrue);
    });

    test('says when the grant ends, when it does', () async {
      expect((await signedInAs(countryManager())).profile!.grantExpiresAt, DateTime.utc(2027, 3, 31, 20, 59, 59));
      expect((await signedInAs(owner())).profile!.grantExpiresAt, isNull);
    });
  });

  group('a grant that does not include the markets', () {
    test('has an overview all the same: the markets are not asked for, and nothing waits for them', () async {
      final PlatformAdminController controller = await signedInAs(countryManager());

      await controller.loadOverview();

      expect(service.calls, <String>['overview all null']);
      expect(controller.overview, isNotNull);
      expect(controller.hasOverview, isTrue);
      expect(controller.overviewFailure, isNull);
    });

    test('has its alerts all the same, without asking for the markets either', () async {
      final PlatformAdminController controller = await signedInAs(countryManager());

      await controller.loadAlerts();

      expect(service.calls, <String>['alerts all p1 null']);
      expect(controller.alerts, isNotEmpty);
    });

    test('chooses between the markets its grant names, as the server listed them', () async {
      final PlatformAdminController controller = await signedInAs(countryManager());

      expect(controller.marketCodes, <String>['AE', 'KW']);
      controller.selectMarket('KW');
      expect(controller.market, 'KW');
      controller.selectMarket('SA');
      expect(controller.market, 'KW', reason: 'a market the grant does not name cannot be chosen');
    });

    test('is never asked for them, not even when the screen is pulled down', () async {
      final PlatformAdminController controller = await signedInAs(countryManager());
      await controller.loadOverview();

      await controller.loadOverview(force: true);

      expect(service.count('markets'), 0);
      expect(service.count('overview'), 2);
    });
  });

  group('a grant that does include the markets', () {
    test('waits for them, as it always did: the cards are drawn when the facts about the markets are here', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      final Gate<PlatformAdminResult<PlatformMarketDirectory>> gate =
          Gate<PlatformAdminResult<PlatformMarketDirectory>>();
      service.onMarkets = () => gate.future;

      final Future<void> loading = controller.loadOverview();
      await Future<void>.delayed(Duration.zero);

      expect(controller.overview, isNull, reason: 'the overview is not stored before the directory is here');
      expect(controller.marketCodes, isEmpty);
      gate.open(PlatformAdminResult<PlatformMarketDirectory>.success(
          PlatformMarketDirectory.fromJson(fixtureData('markets_owner'))));
      await loading;

      expect(controller.hasOverview, isTrue);
      expect(controller.marketCodes, <String>['SA', 'AE', 'KW', 'QA', 'BH', 'OM']);
    });
  });

  group('a part of the API the grant does not include, though the app offered it', () {
    final Map<String, Future<void> Function(PlatformAdminController)> loaders =
        <String, Future<void> Function(PlatformAdminController)>{
      'overview': (PlatformAdminController controller) => controller.loadOverview(),
      'alerts': (PlatformAdminController controller) => controller.loadAlerts(),
      'sessions': (PlatformAdminController controller) => controller.loadSessions(),
      'audit': (PlatformAdminController controller) => controller.loadAuditLog(),
    };

    void refuse(String part) {
      switch (part) {
        case 'overview':
          service.onOverview = (String market, int? windowDays) async => notIncluded<PlatformOverviewModel>();
        case 'alerts':
          service.onAlerts = (String market, int page, String? severity) async => notIncluded<PlatformAlertPage>();
        case 'sessions':
          service.onSessions = () async => notIncluded<List<PlatformSessionModel>>();
        case 'audit':
          service.onAuditLogs = (int page) async => notIncluded<PlatformAuditPage>();
      }
    }

    PlatformAdminFailure? failureOf(PlatformAdminController controller, String part) => switch (part) {
          'overview' => controller.overviewFailure,
          'alerts' => controller.alertsFailure,
          'sessions' => controller.sessionsFailure,
          _ => controller.auditFailure,
        };

    test(
        'is said for that screen as what it is, which is not an error of the connection and not the end of the session',
        () async {
      for (final String part in loaders.keys) {
        service = FakePlatformAdminService();
        final PlatformAdminController controller = await signedInAs(owner());
        refuse(part);

        await loaders[part]!(controller);

        expect(failureOf(controller, part)!.kind, PlatformAdminFailureKind.capabilityNotAllowed, reason: part);
        expect(controller.stage, PlatformAdminStage.signedIn, reason: part);
        expect(controller.sessionEnded, isFalse, reason: part);
      }
    });

    test(
        'makes the app read what the grant includes again, once, and the screen keeps saying so while the server still lists it',
        () async {
      for (final String part in loaders.keys) {
        service = FakePlatformAdminService();
        final PlatformAdminController controller = await signedInAs(owner());
        refuse(part);

        await loaders[part]!(controller);

        expect(service.count('profile'), 1, reason: part);
        expect(failureOf(controller, part)!.kind, PlatformAdminFailureKind.capabilityNotAllowed,
            reason: '$part: the list still has it, so the screen is not thrown away and asked again in a loop');
        expect(controller.accessEpoch, 0, reason: part);
      }
    });

    test('and when the list says it is gone, the part is gone: not offered, and nothing held for it', () async {
      for (final String part in loaders.keys) {
        service = FakePlatformAdminService();
        final PlatformAdminController controller = await signedInAs(owner());
        final List<String> remaining = PlatformCapability.values
            .map((PlatformCapability capability) => capability.name)
            .where((String name) => name != part)
            .toList();
        refuse(part);
        service.onProfile = () async => PlatformAdminResult<PlatformAdminProfile>.success(ownerWith(remaining));

        await loaders[part]!(controller);

        expect(controller.can(PlatformCapability.values.firstWhere((capability) => capability.name == part)), isFalse,
            reason: part);
        expect(failureOf(controller, part), isNull, reason: '$part: it was thrown away, not merely hidden');
        expect(controller.accessEpoch, 1, reason: part);
        expect(controller.stage, PlatformAdminStage.signedIn, reason: part);
      }
    });

    test('a further page that is refused makes the app read the list again too', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      await controller.loadAlerts();
      await controller.loadAuditLog();
      service.calls.clear();
      service.onAlerts = (String market, int page, String? severity) async => notIncluded<PlatformAlertPage>();
      service.onAuditLogs = (int page) async => notIncluded<PlatformAuditPage>();

      await controller.loadMoreAlerts();
      await controller.loadMoreAuditLog();

      expect(service.count('profile'), 2);
    });

    test('ending a session that is refused makes the app read the list again, and says why it was not ended', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      await controller.loadSessions();
      service.calls.clear();
      service.onEndSession = (int id) async => notIncluded<int>();

      final PlatformAdminFailure? failure = await controller.endSession(5);

      expect(failure!.kind, PlatformAdminFailureKind.capabilityNotAllowed);
      expect(service.count('profile'), 1);
      expect(service.count('sessions'), 0,
          reason: 'a session that was refused is not read again as if it had been ended');
    });

    test('ending the other sessions that is refused makes the app read the list again too', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      await controller.loadSessions();
      service.calls.clear();
      service.onEndOtherSessions = () async => notIncluded<int>();

      final PlatformAdminResult<int>? result = await controller.endOtherSessions();

      expect(result!.failure!.kind, PlatformAdminFailureKind.capabilityNotAllowed);
      expect(service.count('profile'), 1);
      expect(service.count('sessions'), 0);
    });

    test('two refusals that come together make the app read the list once', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      service.onOverview = (String market, int? windowDays) async => notIncluded<PlatformOverviewModel>();
      service.onMarkets = () async => notIncluded<PlatformMarketDirectory>('error_capability_not_allowed_markets');

      await controller.loadOverview();

      expect(service.count('profile'), 1);
    });

    test('a list that cannot be read changes nothing, and the next refusal asks again', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      service.onOverview = (String market, int? windowDays) async => notIncluded<PlatformOverviewModel>();
      service.onProfile = () async => unreachable<PlatformAdminProfile>();

      await controller.loadOverview();
      await controller.loadOverview(force: true);

      expect(service.count('profile'), 2);
      expect(controller.stage, PlatformAdminStage.signedIn);
      expect(controller.can(PlatformCapability.overview), isTrue);
    });

    test('a list that is refused ends the session, once, with the note', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      service.onOverview = (String market, int? windowDays) async => notIncluded<PlatformOverviewModel>();
      service.onProfile = () async => refused<PlatformAdminProfile>('error_unauthenticated');

      await controller.loadOverview();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isTrue);
    });
  });

  group('the markets, when the grant lost them while the app was open', () {
    test('are not what the overview waits for, nor what makes it fail: it is drawn without them', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      service.onMarkets = () async => notIncluded<PlatformMarketDirectory>('error_capability_not_allowed_markets');

      await controller.loadOverview();

      expect(controller.overview, isNotNull);
      expect(controller.overviewFailure, isNull);
      expect(controller.hasOverview, isTrue);
      expect(service.count('profile'), 1);
    });

    test(
        'and when the list agrees, they are not asked for again; when it does not, they are not asked for in a loop either',
        () async {
      final PlatformAdminController controller = await signedInAs(owner());
      service.onMarkets = () async => notIncluded<PlatformMarketDirectory>('error_capability_not_allowed_markets');
      await controller.loadOverview();
      service.calls.clear();

      await controller.loadAlerts();
      await controller.loadOverview(force: false);

      expect(service.count('markets'), 0);
      expect(controller.marketCodes, owner().markets);

      await controller.loadOverview(force: true);
      expect(service.count('markets'), 1, reason: 'pulling down tries them once more');
    });

    test('the alerts are drawn without them as well', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      service.onMarkets = () async => notIncluded<PlatformMarketDirectory>('error_capability_not_allowed_markets');

      await controller.loadAlerts();

      expect(controller.alerts, isNotEmpty);
      expect(controller.alertsFailure, isNull);
      expect(service.count('profile'), 1);
    });
  });

  group('reading the list again', () {
    test('changes nothing, and tells nobody, when nothing changed', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      await controller.loadOverview();
      int heard = 0;
      controller.addListener(() => heard++);

      await controller.refreshProfile();

      expect(controller.overview, isNotNull);
      expect(controller.accessEpoch, 0);
      expect(heard, 1, reason: 'the screens are told once, and no more');
    });

    test('throws away what was held when what the grant includes changed, and counts it', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      await controller.loadOverview();
      service.onProfile = () async =>
          PlatformAdminResult<PlatformAdminProfile>.success(ownerWith(<String>['overview', 'alerts', 'markets']));

      await controller.refreshProfile();

      expect(controller.overview, isNull);
      expect(controller.accessEpoch, 1);
      expect(controller.can(PlatformCapability.sessions), isFalse);
    });

    test('counts a part that was added too, because what is shown has to be asked for again', () async {
      final PlatformAdminController controller = await signedInAs(countryManager());
      service.onProfile = () async => PlatformAdminResult<PlatformAdminProfile>.success(owner());

      await controller.refreshProfile();

      expect(controller.can(PlatformCapability.sessions), isTrue);
      expect(controller.accessEpoch, 1);
    });

    test('puts the viewer back on all markets when the market they were looking at is no longer theirs', () async {
      final PlatformAdminController controller = await signedInAs(countryManager());
      controller.selectMarket('KW');
      service.onProfile =
          () async => PlatformAdminResult<PlatformAdminProfile>.success(PlatformAdminProfile.fromJson(<String, dynamic>{
                'admin_id': 5,
                'scope': 'restricted',
                'markets': <String>['AE'],
                'capabilities': <String>['overview', 'alerts']
              }));

      await controller.refreshProfile();

      expect(controller.market, 'all');
      expect(controller.marketCodes, <String>['AE']);
    });

    test('is asked once when it is asked twice at once', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      final Gate<PlatformAdminResult<PlatformAdminProfile>> gate = Gate<PlatformAdminResult<PlatformAdminProfile>>();
      service.onProfile = () => gate.future;

      final Future<void> first = controller.refreshProfile();
      final Future<void> second = controller.refreshProfile();
      gate.open(PlatformAdminResult<PlatformAdminProfile>.success(owner()));
      await Future.wait(<Future<void>>[first, second]);

      expect(service.count('profile'), 1);
    });

    test('is not asked for nobody, and its answer is not acted on after the admin signed out', () async {
      final PlatformAdminController signedOut = PlatformAdminController(platformAdminServiceInterface: service);
      await signedOut.refreshProfile();
      expect(service.calls, isEmpty);

      final PlatformAdminController controller = await signedInAs(owner());
      final Gate<PlatformAdminResult<PlatformAdminProfile>> gate = Gate<PlatformAdminResult<PlatformAdminProfile>>();
      service.onProfile = () => gate.future;
      final Future<void> pending = controller.refreshProfile();

      await controller.signOut();
      gate.open(PlatformAdminResult<PlatformAdminProfile>.success(owner()));
      await pending;

      expect(controller.profile, isNull);
      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isFalse);
    });

    test(
        'and a refusal of the session that comes after the admin signed out is not the end of a session that already ended',
        () async {
      final PlatformAdminController controller = await signedInAs(owner());
      final Gate<PlatformAdminResult<PlatformAdminProfile>> gate = Gate<PlatformAdminResult<PlatformAdminProfile>>();
      service.onProfile = () => gate.future;
      final Future<void> pending = controller.refreshProfile();

      await controller.signOut();
      gate.open(refused<PlatformAdminProfile>('error_unauthenticated'));
      await pending;

      expect(controller.sessionEnded, isFalse);
      expect(controller.stage, PlatformAdminStage.signedOut);
    });

    test('after a long time away is how the app learns that the grant was narrowed', () async {
      final PlatformAdminController controller = await signedInAs(owner());
      controller.onAppBackgrounded();
      now = now.add(const Duration(minutes: 30));
      service.onProfile = () async => PlatformAdminResult<PlatformAdminProfile>.success(countryManager());

      final bool thrownAway = await controller.onAppResumed();

      expect(thrownAway, isTrue);
      expect(controller.can(PlatformCapability.sessions), isFalse);
      expect(controller.profile!.grantExpiresAt, isNotNull);
    });
  });
}
