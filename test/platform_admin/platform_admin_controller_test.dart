import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';

/// The state of the platform admin principal, from the first launch to sign-out.
///
/// The questions that matter are the ones about what is remembered: that a
/// refusal of the token ends everything, that switching market leaves nothing of
/// the old one behind, and that an answer which was still on its way when
/// something was thrown away does not bring it back.
void main() {
  late FakePlatformAdminService service;
  late DateTime now;

  setUp(() {
    service = FakePlatformAdminService();
    now = DateTime.utc(2026, 11, 17, 10);
  });

  PlatformAdminController newController() => PlatformAdminController(
        platformAdminServiceInterface: service,
        now: () => now,
      );

  Future<PlatformAdminController> signedIn({PlatformAdminProfile? as}) async {
    final PlatformAdminController controller = newController();
    service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(as ?? ownerProfile());
    await controller.restoreSession();
    service.calls.clear();
    return controller;
  }

  Future<PlatformAdminController> signedInOwnerWithOverview() async {
    final PlatformAdminController controller = await signedIn();
    await controller.loadOverview();
    service.calls.clear();
    return controller;
  }

  group('picking up a session a previous launch left', () {
    test('starts out looking, and shows nothing until it knows', () {
      final PlatformAdminController controller = newController();

      expect(controller.stage, PlatformAdminStage.restoring);
      expect(controller.profile, isNull);
      expect(service.calls, isEmpty, reason: 'nothing is asked until the shell asks');
    });

    test('with none, ends signed out and says nothing of a session that ended', () async {
      final PlatformAdminController controller = newController();

      await controller.restoreSession();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isFalse);
      expect(service.calls, <String>['restore']);
    });

    test('with one the server confirms, is signed in as who the server says', () async {
      final PlatformAdminController controller = await signedIn(as: restrictedProfile());

      expect(controller.stage, PlatformAdminStage.signedIn);
      expect(controller.profile!.markets, <String>['AE', 'KW']);
      expect(controller.isRestricted, isTrue);
    });

    test('with one the server refuses, is signed out and says the session ended', () async {
      final PlatformAdminController controller = newController();
      service.onRestore = () async => refused<PlatformAdminProfile?>('error_unauthenticated');

      await controller.restoreSession();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isTrue);
      expect(controller.profile, isNull);
    });

    test('with one that could not be checked, says why and can try again', () async {
      final PlatformAdminController controller = newController();
      service.onRestore = () async => unreachable<PlatformAdminProfile?>();

      await controller.restoreSession();

      expect(controller.stage, PlatformAdminStage.restoreFailed);
      expect(controller.restoreFailure!.kind, PlatformAdminFailureKind.network);
      expect(controller.sessionEnded, isFalse);

      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await controller.restoreSession();

      expect(controller.stage, PlatformAdminStage.signedIn);
      expect(controller.restoreFailure, isNull);
    });

    test('an API that is switched off or not ready is a failure to try again, not a session that ended', () async {
      for (final String fixtureName in <String>['error_api_switched_off', 'error_not_ready']) {
        final PlatformAdminController controller = newController();
        service.onRestore = () async => refused<PlatformAdminProfile?>(fixtureName);

        await controller.restoreSession();

        expect(controller.stage, PlatformAdminStage.restoreFailed, reason: fixtureName);
        expect(controller.sessionEnded, isFalse, reason: fixtureName);
      }
    });
  });

  group('signing in', () {
    test(
        'succeeds with who the server says, read from the API once the session is open, and loads nothing until a screen asks',
        () async {
      final PlatformAdminController controller = newController();
      await controller.restoreSession();
      service.calls.clear();

      final bool signedIn =
          await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');

      expect(signedIn, isTrue);
      expect(controller.stage, PlatformAdminStage.signedIn);
      expect(controller.profile!.adminId, 4);
      expect(controller.signInFailure, isNull);
      expect(service.calls, <String>['signIn owner@example.test/Pixel 9', 'profile']);
    });

    test('is busy while it asks, and a second tap is ignored', () async {
      final PlatformAdminController controller = newController();
      final Gate<PlatformAdminResult<PlatformAdminSignInStep>> gate =
          Gate<PlatformAdminResult<PlatformAdminSignInStep>>();
      service.onSignIn = () => gate.future;

      final Future<bool> first = controller.signIn(email: 'a@example.test', password: 'x', deviceName: 'Pixel');
      final bool second = await controller.signIn(email: 'a@example.test', password: 'x', deviceName: 'Pixel');
      gate.open(PlatformAdminResult<PlatformAdminSignInStep>.success(PlatformAdminSessionOpened(ownerSignIn())));

      expect(second, isFalse);
      expect(await first, isTrue);
      expect(controller.stage, PlatformAdminStage.signedIn);
      expect(service.count('signIn'), 1);
    });

    test('shows that it is busy', () async {
      final PlatformAdminController controller = newController();
      final Gate<PlatformAdminResult<PlatformAdminSignInStep>> gate =
          Gate<PlatformAdminResult<PlatformAdminSignInStep>>();
      service.onSignIn = () => gate.future;

      final Future<bool> pending = controller.signIn(email: 'a@example.test', password: 'x', deviceName: 'Pixel');

      expect(controller.stage, PlatformAdminStage.signingIn);
      gate.open(PlatformAdminResult<PlatformAdminSignInStep>.success(PlatformAdminSessionOpened(ownerSignIn())));
      await pending;
    });

    test('a refusal leaves the admin signed out with the reason, and is not a session that ended', () async {
      final PlatformAdminController controller = newController();
      service.onSignIn = () async => refused<PlatformAdminSignInStep>('login_failed_wrong_password');

      final bool signedIn =
          await controller.signIn(email: 'owner@example.test', password: 'wrong', deviceName: 'Pixel 9');

      expect(signedIn, isFalse);
      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.signInFailure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(controller.sessionEnded, isFalse);
      expect(controller.profile, isNull);
    });

    test('too many attempts says when to try again', () async {
      final PlatformAdminController controller = newController();
      service.onSignIn = () async => refused<PlatformAdminSignInStep>('error_login_throttled');

      await controller.signIn(email: 'owner@example.test', password: 'wrong', deviceName: 'Pixel 9');

      expect(controller.signInFailure!.kind, PlatformAdminFailureKind.throttled);
      expect(controller.signInFailure!.retryAt, isNotNull);
      expect(controller.stage, PlatformAdminStage.signedOut);
    });

    test('no connection, an API that is off and one that is not ready are each said as what they are', () async {
      final Map<String, PlatformAdminFailureKind> expected = <String, PlatformAdminFailureKind>{
        'error_api_switched_off_login': PlatformAdminFailureKind.notAvailable,
        'error_not_ready': PlatformAdminFailureKind.notReady,
      };
      for (final MapEntry<String, PlatformAdminFailureKind> entry in expected.entries) {
        final PlatformAdminController controller = newController();
        service.onSignIn = () async => refused<PlatformAdminSignInStep>(entry.key);

        await controller.signIn(email: 'owner@example.test', password: 'x', deviceName: 'Pixel 9');

        expect(controller.signInFailure!.kind, entry.value, reason: entry.key);
      }
      final PlatformAdminController offline = newController();
      service.onSignIn = () async => unreachable<PlatformAdminSignInStep>();

      await offline.signIn(email: 'owner@example.test', password: 'x', deviceName: 'Pixel 9');

      expect(offline.signInFailure!.kind, PlatformAdminFailureKind.network);
    });

    test('a new attempt clears the last failure and the note that a session ended', () async {
      final PlatformAdminController controller = newController();
      service.onRestore = () async => refused<PlatformAdminProfile?>('error_unauthenticated');
      await controller.restoreSession();
      service.onSignIn = () async => refused<PlatformAdminSignInStep>('login_failed_wrong_password');
      await controller.signIn(email: 'owner@example.test', password: 'wrong', deviceName: 'Pixel 9');
      expect(controller.signInFailure, isNotNull);

      service.onSignIn =
          () async => PlatformAdminResult<PlatformAdminSignInStep>.success(PlatformAdminSessionOpened(ownerSignIn()));
      await controller.signIn(email: 'owner@example.test', password: 'right', deviceName: 'Pixel 9');

      expect(controller.signInFailure, isNull);
      expect(controller.sessionEnded, isFalse);
      expect(controller.stage, PlatformAdminStage.signedIn);
    });

    test('the password is not kept by the controller: it is not among anything it says about itself', () async {
      final PlatformAdminController controller = newController();

      await controller.signIn(email: 'owner@example.test', password: 'the-password-123', deviceName: 'Pixel 9');

      expect(controller.toString(), isNot(contains('the-password-123')));
      expect(controller.profile.toString(), isNot(contains('the-password-123')));
    });
  });

  group('the overview', () {
    test('loads the facts about the markets and the figures together, for all markets and the server\'s own window',
        () async {
      final PlatformAdminController controller = await signedIn();

      await controller.loadOverview();

      expect(service.calls, containsAll(<String>['markets', 'overview all null']));
      expect(controller.hasOverview, isTrue);
      expect(controller.overview!.markets, hasLength(6));
      expect(controller.markets.map((PlatformMarketModel market) => market.code),
          <String>['SA', 'AE', 'KW', 'QA', 'BH', 'OM']);
      expect(controller.isLoadingOverview, isFalse);
      expect(controller.overviewFailure, isNull);
    });

    test('is busy while it loads, and says so to anyone listening', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<PlatformOverviewModel>> gate = Gate<PlatformAdminResult<PlatformOverviewModel>>();
      service.onOverview = (String market, int? windowDays) => gate.future;
      int notified = 0;
      controller.addListener(() => notified++);

      final Future<void> loading = controller.loadOverview();

      expect(controller.isLoadingOverview, isTrue);
      expect(notified, 1);
      gate.open(PlatformAdminResult<PlatformOverviewModel>.success(FakePlatformAdminService.overviewOf('all', null)));
      await loading;
      expect(controller.isLoadingOverview, isFalse);
      expect(notified, 2);
    });

    test('is not asked for again while it is held, and is when it is forced', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();

      await controller.loadOverview();
      expect(service.calls, isEmpty);

      await controller.loadOverview(force: true);
      expect(service.calls, containsAll(<String>['markets', 'overview all null']));
    });

    test('is not asked for twice at once', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<PlatformOverviewModel>> gate = Gate<PlatformAdminResult<PlatformOverviewModel>>();
      service.onOverview = (String market, int? windowDays) => gate.future;

      final Future<void> first = controller.loadOverview();
      final Future<void> second = controller.loadOverview();
      gate.open(PlatformAdminResult<PlatformOverviewModel>.success(FakePlatformAdminService.overviewOf('all', null)));
      await Future.wait(<Future<void>>[first, second]);

      expect(service.count('overview'), 1);
    });

    test('is not asked for before sign-in', () async {
      final PlatformAdminController controller = newController();

      await controller.loadOverview();

      expect(service.calls, isEmpty);
    });

    test('a window of its own is asked for by its days, and each window is held under its own key', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();

      controller.selectWindow(7);
      expect(controller.overview, isNull, reason: 'the month that was held is not the week that was asked for');
      await controller.loadOverview();
      expect(service.calls, <String>['overview all 7']);
      expect(controller.overview!.window!.days, 7);

      controller.selectWindow(null);
      expect(controller.overview!.window!.days, 30, reason: 'the month is still held');
      await controller.loadOverview();
      expect(service.calls, <String>['overview all 7'], reason: 'and is not asked for again');
    });

    test('a market is asked for alone, with no card of any other', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();

      controller.selectMarket('KW');
      await controller.loadOverview();

      expect(service.calls, <String>['overview KW null']);
      expect(controller.overview!.markets.map((PlatformMarketOverview market) => market.market), <String>['KW']);
      expect(controller.overview!.unattributed, isNull);
    });

    test('a market is not asked for again with the facts about the markets, which are not about one market', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();

      controller.selectMarket('KW');
      await controller.loadOverview();

      expect(service.calls, isNot(contains('markets')));
      expect(controller.markets, hasLength(6));
    });
  });

  group('switching market', () {
    test('forgets everything that was counted for the market that was left', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      await controller.loadAlerts();
      expect(controller.alerts, isNotEmpty);
      service.calls.clear();

      controller.selectMarket('KW');

      expect(controller.market, 'KW');
      expect(controller.overview, isNull);
      expect(controller.alerts, isEmpty);
      expect(controller.hasOverview, isFalse);
      expect(controller.hasAlertList, isFalse);
    });

    test('and what is shown for the new market is asked for, not read from the old one', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();

      controller.selectMarket('KW');
      controller.selectMarket('all');
      await controller.loadOverview();

      expect(service.calls, contains('overview all null'),
          reason: 'the answer for all markets was not kept while Kuwait was chosen');
    });

    test('keeps what is not about a market: the facts about the markets, the sessions and the audit log', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      await controller.loadSessions();
      await controller.loadAuditLog();

      controller.selectMarket('KW');

      expect(controller.markets, hasLength(6));
      expect(controller.sessions, isNotNull);
      expect(controller.auditLines, isNotNull);
    });

    test('only a market the server listed for this viewer can be chosen', () async {
      final PlatformAdminController controller = await signedIn(as: restrictedProfile());
      await controller.loadOverview();

      controller.selectMarket('SA');
      expect(controller.market, 'all');
      expect(controller.hasOverview, isTrue, reason: 'a refused choice changes nothing, and forgets nothing');

      controller.selectMarket('kw');
      expect(controller.market, 'KW');
    });

    test('the code is written the way the server writes it', () async {
      final PlatformAdminController controller = await signedIn();

      controller.selectMarket('kw');
      expect(controller.market, 'KW');
      controller.selectMarket('ALL');
      expect(controller.market, 'all');
    });

    test('choosing the market that is already chosen forgets nothing', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();

      controller.selectMarket('all');

      expect(controller.hasOverview, isTrue);
    });

    test('an answer for the market that was left, still on its way, is dropped when it arrives', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<PlatformOverviewModel>> late = Gate<PlatformAdminResult<PlatformOverviewModel>>();
      service.onOverview = (String market, int? windowDays) => market == 'all'
          ? late.future
          : Future<PlatformAdminResult<PlatformOverviewModel>>.value(PlatformAdminResult<PlatformOverviewModel>.success(
              FakePlatformAdminService.overviewOf(market, windowDays)));
      final Future<void> loadingAll = controller.loadOverview();

      controller.selectMarket('KW');
      await controller.loadOverview();
      late.open(PlatformAdminResult<PlatformOverviewModel>.success(FakePlatformAdminService.overviewOf('all', null)));
      await loadingAll;

      expect(controller.market, 'KW');
      expect(controller.overview!.markets.map((PlatformMarketOverview market) => market.market), <String>['KW']);
      controller.selectMarket('all');
      expect(controller.overview, isNull, reason: 'the late answer for all markets was not kept');
    });
  });

  group('when the server says no', () {
    test('a refusal of the token ends the session, forgets everything and says so', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      await controller.loadSessions();
      service.onOverview =
          (String market, int? windowDays) async => refused<PlatformOverviewModel>('error_unauthenticated');

      await controller.loadOverview(force: true);

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isTrue);
      expect(controller.profile, isNull);
      expect(controller.overview, isNull);
      expect(controller.markets, isEmpty);
      expect(controller.sessions, isNull);
    });

    test('and so does a refusal met by any other screen', () async {
      final Map<String, Future<void> Function(PlatformAdminController)> screens =
          <String, Future<void> Function(PlatformAdminController)>{
        'alerts': (PlatformAdminController controller) {
          service.onAlerts =
              (String market, int page, String? severity) async => refused<PlatformAlertPage>('error_unauthenticated');
          return controller.loadAlerts();
        },
        'sessions': (PlatformAdminController controller) {
          service.onSessions = () async => refused<List<PlatformSessionModel>>('error_unauthenticated');
          return controller.loadSessions();
        },
        'audit log': (PlatformAdminController controller) {
          service.onAuditLogs = (int page) async => refused<PlatformAuditPage>('error_unauthenticated');
          return controller.loadAuditLog();
        },
        'ending a session': (PlatformAdminController controller) {
          service.onEndSession = (int id) async => refused<int>('error_unauthenticated');
          return controller.endSession(2);
        },
      };

      for (final MapEntry<String, Future<void> Function(PlatformAdminController)> screen in screens.entries) {
        final PlatformAdminController controller = await signedInOwnerWithOverview();

        await screen.value(controller);

        expect(controller.stage, PlatformAdminStage.signedOut, reason: screen.key);
        expect(controller.sessionEnded, isTrue, reason: screen.key);
        expect(controller.overview, isNull, reason: screen.key);
        expect(controller.profile, isNull, reason: screen.key);
      }
    });

    test('a market the grant does not hold is that market\'s failure, and the session goes on', () async {
      final PlatformAdminController controller = await signedIn(as: restrictedProfile());
      service.onOverview =
          (String market, int? windowDays) async => refused<PlatformOverviewModel>('error_market_not_allowed');

      await controller.loadOverview();

      expect(controller.overviewFailure!.kind, PlatformAdminFailureKind.marketNotAllowed);
      expect(controller.stage, PlatformAdminStage.signedIn);
      expect(controller.hasOverview, isFalse);
    });

    test('being throttled says when to try again, and keeps what was held', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      service.onOverview =
          (String market, int? windowDays) async => refused<PlatformOverviewModel>('error_login_throttled');

      await controller.loadOverview(force: true);

      expect(controller.overviewFailure!.kind, PlatformAdminFailureKind.throttled);
      expect(controller.overviewFailure!.retryAt, isNotNull);
      expect(controller.hasOverview, isTrue, reason: 'what was counted a moment ago is still the best the screen has');
    });

    test('the API turned off or not ready, or no connection, is each a failure and not the end of the session',
        () async {
      final Map<String, PlatformAdminFailureKind> expected = <String, PlatformAdminFailureKind>{
        'error_api_switched_off': PlatformAdminFailureKind.notAvailable,
        'error_not_ready': PlatformAdminFailureKind.notReady,
      };
      for (final MapEntry<String, PlatformAdminFailureKind> entry in expected.entries) {
        final PlatformAdminController controller = await signedIn();
        service.onOverview = (String market, int? windowDays) async => refused<PlatformOverviewModel>(entry.key);

        await controller.loadOverview();

        expect(controller.overviewFailure!.kind, entry.value, reason: entry.key);
        expect(controller.stage, PlatformAdminStage.signedIn, reason: entry.key);
      }
      final PlatformAdminController offline = await signedIn();
      service.onOverview = (String market, int? windowDays) async => unreachable<PlatformOverviewModel>();

      await offline.loadOverview();

      expect(offline.overviewFailure!.kind, PlatformAdminFailureKind.network);
      expect(offline.stage, PlatformAdminStage.signedIn);
    });

    test('the facts about the markets failing alone is a failure of the overview, and it can be asked for again',
        () async {
      final PlatformAdminController controller = await signedIn();
      service.onMarkets = () async => unreachable<PlatformMarketDirectory>();

      await controller.loadOverview();

      expect(controller.overviewFailure!.kind, PlatformAdminFailureKind.network);
      expect(controller.hasOverview, isFalse);

      service.onMarkets = () async => PlatformAdminResult<PlatformMarketDirectory>.success(
          PlatformMarketDirectory.fromJson(fixtureData('markets_owner')));
      await controller.loadOverview();

      expect(controller.hasOverview, isTrue);
      expect(controller.overviewFailure, isNull);
    });

    test('a failure is forgotten when the market is switched, so the new one is not shown the old one\'s', () async {
      final PlatformAdminController controller = await signedIn();
      service.onOverview = (String market, int? windowDays) async => unreachable<PlatformOverviewModel>();
      await controller.loadOverview();
      expect(controller.overviewFailure, isNotNull);

      controller.selectMarket('KW');

      expect(controller.overviewFailure, isNull);
    });
  });

  group('the alerts', () {
    test('load a page and say there is more, and the next page is added to it', () async {
      final PlatformAdminController controller = await signedIn();

      await controller.loadAlerts();
      expect(controller.alerts, hasLength(3));
      expect(controller.alertsHaveMore, isTrue);
      expect(controller.alertsTotal, 4);

      await controller.loadMoreAlerts();

      expect(controller.alerts, hasLength(4));
      expect(controller.alertsHaveMore, isFalse);
      expect(service.calls, <String>['markets', 'alerts all p1 null', 'alerts all p2 null']);
    });

    test('ask for the markets too when nothing has, because the market chips of the screen are the overview\'s',
        () async {
      final PlatformAdminController controller = await signedIn();

      await controller.loadAlerts();

      expect(service.calls, <String>['markets', 'alerts all p1 null']);
      expect(controller.markets.map((PlatformMarketModel market) => market.code),
          <String>['SA', 'AE', 'KW', 'QA', 'BH', 'OM']);
    });

    test('do not ask for the markets again when the overview already has them', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();

      await controller.loadAlerts();

      expect(service.calls, <String>['alerts all p1 null']);
    });

    test('and the overview does not ask for them again when the alerts have them', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadAlerts();
      service.calls.clear();

      await controller.loadOverview();

      expect(service.calls, <String>['overview all null']);
      expect(controller.hasOverview, isTrue);
    });

    test('a list of markets that cannot be had does not fail the alerts, and is asked for again next time', () async {
      service.onMarkets = () async => unreachable<PlatformMarketDirectory>();
      final PlatformAdminController controller = await signedIn();

      await controller.loadAlerts();

      expect(controller.alerts, hasLength(3));
      expect(controller.alertsFailure, isNull);
      expect(controller.markets, isEmpty);

      service.calls.clear();
      await controller.loadAlerts(force: true);
      expect(service.calls, <String>['markets', 'alerts all p1 null']);
    });

    test('a session the server refuses on the markets ends the session, and nothing of the alerts is kept', () async {
      service.onMarkets = () async => refused<PlatformMarketDirectory>('error_unauthenticated');
      final PlatformAdminController controller = await signedIn();

      await controller.loadAlerts();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isTrue);
      expect(controller.hasAlertList, isFalse);
      expect(controller.markets, isEmpty);
    });

    test('markets that were on their way when the admin signed out are not kept', () async {
      final Gate<PlatformAdminResult<PlatformMarketDirectory>> gate =
          Gate<PlatformAdminResult<PlatformMarketDirectory>>();
      service.onMarkets = () => gate.future;
      final PlatformAdminController controller = await signedIn();
      final Future<void> loading = controller.loadAlerts();

      await controller.signOut();
      gate.open(PlatformAdminResult<PlatformMarketDirectory>.success(
          PlatformMarketDirectory.fromJson(fixtureData('markets_owner'))));
      await loading;

      expect(controller.markets, isEmpty);
      expect(controller.hasAlertList, isFalse);
      expect(controller.stage, PlatformAdminStage.signedOut);
    });

    test('are not asked for again while held, and are when forced', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadAlerts();
      service.calls.clear();

      await controller.loadAlerts();
      expect(service.calls, isEmpty);

      await controller.loadAlerts(force: true);
      expect(service.calls, <String>['alerts all p1 null']);
    });

    test('a severity is asked for on its own, and each is held under its own key', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadAlerts();
      service.calls.clear();

      controller.selectAlertSeverity('critical');
      expect(controller.alerts, isEmpty, reason: 'every alert is not the critical ones');
      await controller.loadAlerts();
      expect(service.calls, <String>['alerts all p1 critical']);

      controller.selectAlertSeverity(null);
      expect(controller.alerts, hasLength(3), reason: 'and the first list is still held');
      expect(service.calls, hasLength(1));
    });

    test('a market is asked for alone, and what the old market had is forgotten', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadAlerts();
      service.calls.clear();

      controller.selectMarket('QA');
      await controller.loadAlerts();

      expect(service.calls, <String>['alerts QA p1 null']);
      expect(controller.alerts, isEmpty);
      expect(controller.hasAlertList, isTrue,
          reason: 'an empty list that was asked for is an answer, not a list still to load');
    });

    test('more of them is not asked for when there is no more', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadAlerts();
      await controller.loadMoreAlerts();
      service.calls.clear();

      await controller.loadMoreAlerts();

      expect(service.calls, isEmpty);
    });

    test('more of them is not asked for before the first page', () async {
      final PlatformAdminController controller = await signedIn();

      await controller.loadMoreAlerts();

      expect(service.calls, isEmpty);
    });

    test('a page that was on its way when the list was read again is not added to the new list', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadAlerts();
      final Gate<PlatformAdminResult<PlatformAlertPage>> late = Gate<PlatformAdminResult<PlatformAlertPage>>();
      service.onAlerts = (String market, int page, String? severity) => page == 2
          ? late.future
          : Future<PlatformAdminResult<PlatformAlertPage>>.value(PlatformAdminResult<PlatformAlertPage>.success(
              FakePlatformAdminService.alertsOf(market, page, severity)));
      final Future<void> loadingMore = controller.loadMoreAlerts();

      await controller.loadAlerts(force: true);
      late.open(PlatformAdminResult<PlatformAlertPage>.success(FakePlatformAdminService.alertsOf('all', 2, null)));
      await loadingMore;

      expect(controller.alerts, hasLength(3),
          reason: 'the first page again, and not the first page with the second added to the old one');
    });

    test('an alert can be opened when it links to a market this viewer may see', () async {
      final PlatformAdminController owner = await signedIn();
      final PlatformAdminController viewer = await signedIn(as: restrictedProfile());
      final List<PlatformAlertModel> alerts = FakePlatformAdminService.alertsOf('all', 1, null).alerts;
      final PlatformAlertModel saudi = alerts.firstWhere((PlatformAlertModel alert) => alert.market == 'SA');
      final PlatformAlertModel kuwait = alerts.firstWhere((PlatformAlertModel alert) => alert.market == 'KW');

      expect(owner.canOpen(saudi), isTrue);
      expect(viewer.canOpen(kuwait), isTrue);
      expect(viewer.canOpen(saudi), isFalse);
    });

    test('an alert with a link the app cannot route cannot be opened', () async {
      final PlatformAdminController controller = await signedIn();
      final PlatformAlertModel alert = PlatformAlertModel.fromJson(
          <String, dynamic>{...fixtureRows('alerts_owner').first, 'deep_link': 'orders/12'});

      expect(controller.canOpen(alert), isFalse);
    });

    test('a market can be opened when the server lists it for the viewer, in whatever case it is written', () async {
      final PlatformAdminController owner = await signedIn();
      final PlatformAdminController viewer = await signedIn(as: restrictedProfile());

      expect(owner.canOpenMarket('SA'), isTrue);
      expect(owner.canOpenMarket('sa'), isTrue);
      expect(viewer.canOpenMarket('KW'), isTrue);
      expect(viewer.canOpenMarket('kw'), isTrue);
      expect(viewer.canOpenMarket('SA'), isFalse);
      expect(viewer.canOpenMarket('ZZ'), isFalse);
    });

    test('before anyone is signed in, and after they sign out, no market can be opened', () async {
      final PlatformAdminController controller = newController();
      expect(controller.canOpenMarket('SA'), isFalse);

      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await controller.restoreSession();
      expect(controller.canOpenMarket('SA'), isTrue);

      await controller.signOut();
      expect(controller.canOpenMarket('SA'), isFalse);
    });
  });

  group('the sessions', () {
    test('load, and are not asked for again while held', () async {
      final PlatformAdminController controller = await signedIn();

      await controller.loadSessions();
      await controller.loadSessions();

      expect(controller.sessions, hasLength(3));
      expect(service.count('sessions'), 1);
    });

    test('ending one asks for it by its id, and reads the list again', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadSessions();
      service.calls.clear();

      final PlatformAdminFailure? failure = await controller.endSession(2);

      expect(failure, isNull);
      expect(service.calls, <String>['endSession 2', 'sessions']);
      expect(controller.endingSessionId, isNull);
    });

    test('ending one that is already over says so, and the list is read again so that it is gone from it', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadSessions();
      service.calls.clear();
      service.onEndSession = (int id) async => refused<int>('error_session_not_found');

      final PlatformAdminFailure? failure = await controller.endSession(2);

      expect(failure!.kind, PlatformAdminFailureKind.sessionNotFound);
      expect(service.calls, <String>['endSession 2', 'sessions']);
    });

    test('ending one that cannot be reached says why and does not read the list again', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadSessions();
      service.calls.clear();
      service.onEndSession = (int id) async => unreachable<int>();

      final PlatformAdminFailure? failure = await controller.endSession(2);

      expect(failure!.kind, PlatformAdminFailureKind.network);
      expect(service.calls, <String>['endSession 2']);
      expect(controller.endingSessionId, isNull);
    });

    test('shows which one is being ended, and does not end two at once', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadSessions();
      final Gate<PlatformAdminResult<int>> gate = Gate<PlatformAdminResult<int>>();
      service.onEndSession = (int id) => gate.future;

      final Future<PlatformAdminFailure?> first = controller.endSession(2);
      final PlatformAdminFailure? second = await controller.endSession(5);

      expect(controller.endingSessionId, 2);
      expect(second, isNull);
      gate.open(const PlatformAdminResult<int>.success(2));
      await first;
      expect(service.count('endSession'), 1);
    });

    test('a list that cannot be read is a failure of the list, and keeps the one that was held', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadSessions();
      service.onSessions = () async => unreachable<List<PlatformSessionModel>>();

      await controller.loadSessions(force: true);

      expect(controller.sessionsFailure!.kind, PlatformAdminFailureKind.network);
      expect(controller.sessions, hasLength(3));
    });
  });

  group('the audit log', () {
    test('loads the newest page, and the next is added to it', () async {
      final PlatformAdminController controller = await signedIn();

      await controller.loadAuditLog();
      expect(controller.auditLines, hasLength(5));
      expect(controller.auditHasMore, isTrue);

      await controller.loadMoreAuditLog();

      expect(controller.auditLines, hasLength(5 + 25));
      expect(service.calls, <String>['auditLogs p1', 'auditLogs p2']);
    });

    test('is not asked for again while held, and is when forced', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadAuditLog();
      service.calls.clear();

      await controller.loadAuditLog();
      await controller.loadAuditLog(force: true);

      expect(service.calls, <String>['auditLogs p1']);
    });

    test('more of it is not asked for when there is no more, or before the first page', () async {
      final PlatformAdminController controller = await signedIn();

      await controller.loadMoreAuditLog();
      expect(service.calls, isEmpty);

      service.onAuditLogs = (int page) async => PlatformAdminResult<PlatformAuditPage>.success(
          PlatformAuditPage.fromJson(fixtureRows('audit_logs_restricted'),
              <String, dynamic>{'scope': 'all', 'page': 1, 'per_page': 25, 'has_more': false}));
      await controller.loadAuditLog();
      service.calls.clear();
      await controller.loadMoreAuditLog();

      expect(service.calls, isEmpty);
    });
  });

  group('signing out', () {
    test('forgets everything at once, here, and then tells the server', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      await controller.loadAlerts();
      await controller.loadSessions();
      await controller.loadAuditLog();
      controller.selectMarket('KW');
      controller.selectWindow(7);
      controller.selectAlertSeverity('critical');
      final Gate<void> server = Gate<void>();
      service.onSignOut = () => server.future;

      final Future<void> signingOut = controller.signOut();

      expect(controller.stage, PlatformAdminStage.signedOut,
          reason: 'over on this phone before the server has answered');
      expect(controller.profile, isNull);
      expect(controller.market, 'all');
      expect(controller.windowDays, isNull);
      expect(controller.alertSeverity, isNull);
      expect(controller.overview, isNull);
      expect(controller.markets, isEmpty);
      expect(controller.alerts, isEmpty);
      expect(controller.sessions, isNull);
      expect(controller.auditLines, isNull);
      expect(controller.sessionEnded, isFalse, reason: 'a person ending their session is not a session that ended');
      server.open(null);
      await signingOut;
      expect(service.count('signOut'), 1);
    });

    test('and the next sign-in starts from nothing, as whoever signs in', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      controller.selectMarket('KW');
      await controller.signOut();

      await controller.signIn(email: 'viewer@example.test', password: 'x', deviceName: 'Pixel 9');

      expect(controller.market, 'all');
      expect(controller.overview, isNull);
      expect(controller.markets, isEmpty);
    });

    test('an answer that was on its way when the admin signed out does not bring anything back', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<PlatformOverviewModel>> late = Gate<PlatformAdminResult<PlatformOverviewModel>>();
      service.onOverview = (String market, int? windowDays) => late.future;
      final Future<void> loading = controller.loadOverview();

      await controller.signOut();
      late.open(PlatformAdminResult<PlatformOverviewModel>.success(FakePlatformAdminService.overviewOf('all', null)));
      await loading;

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.overview, isNull);
      expect(controller.markets, isEmpty);
      expect(controller.isLoadingOverview, isFalse);
    });

    test('nothing is asked for once signed out', () async {
      final PlatformAdminController controller = await signedIn();
      await controller.signOut();
      service.calls.clear();

      await controller.loadOverview();
      await controller.loadAlerts();
      await controller.loadSessions();
      await controller.loadAuditLog();
      await controller.endSession(2);

      expect(service.calls, isEmpty);
    });
  });

  group('leaving the app for a while', () {
    test('a short absence changes nothing', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();

      controller.onAppBackgrounded();
      now = now.add(const Duration(minutes: 4, seconds: 59));
      final bool cleared = await controller.onAppResumed();

      expect(cleared, isFalse);
      expect(controller.hasOverview, isTrue);
      expect(service.calls, isEmpty);
    });

    test(
        'a long one throws away everything that was held, reads who the admin is again, and keeps what had been chosen',
        () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      await controller.loadAlerts();
      await controller.loadSessions();
      await controller.loadAuditLog();
      controller.selectWindow(7);
      await controller.loadOverview();
      controller.selectAlertSeverity('critical');
      service.calls.clear();

      controller.onAppBackgrounded();
      now = now.add(const Duration(minutes: 5));
      final bool cleared = await controller.onAppResumed();

      expect(cleared, isTrue);
      expect(service.calls, <String>['profile']);
      expect(controller.overview, isNull);
      expect(controller.markets, isEmpty);
      expect(controller.alerts, isEmpty);
      expect(controller.sessions, isNull);
      expect(controller.auditLines, isNull);
      expect(controller.stage, PlatformAdminStage.signedIn);
      expect(controller.profile!.adminId, 4);
      expect(controller.windowDays, 7);
      expect(controller.alertSeverity, 'critical');
    });

    test('is counted from the first time the app left, not from every step of leaving it', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();

      controller.onAppBackgrounded();
      now = now.add(const Duration(minutes: 3));
      controller.onAppBackgrounded();
      now = now.add(const Duration(minutes: 3));
      final bool cleared = await controller.onAppResumed();

      expect(cleared, isTrue);
    });

    test('is not counted from an earlier absence', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      controller.onAppBackgrounded();
      now = now.add(const Duration(hours: 2));
      await controller.onAppResumed();
      await controller.loadOverview();
      service.calls.clear();

      now = now.add(const Duration(hours: 2));
      final bool cleared = await controller.onAppResumed();

      expect(cleared, isFalse, reason: 'the app did not leave again');
      expect(controller.hasOverview, isTrue);
    });

    test('a session the server has ended meanwhile is ended on the way back', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      service.onProfile = () async => refused<PlatformAdminProfile>('error_unauthenticated');

      controller.onAppBackgrounded();
      now = now.add(const Duration(hours: 1));
      final bool cleared = await controller.onAppResumed();

      expect(cleared, isFalse);
      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isTrue);
    });

    test(
        'a scope that changed meanwhile is the scope that is shown, and a market that is no longer the viewer\'s is left',
        () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      controller.selectMarket('SA');
      service.onProfile = () async => PlatformAdminResult<PlatformAdminProfile>.success(restrictedProfile());

      controller.onAppBackgrounded();
      now = now.add(const Duration(minutes: 30));
      await controller.onAppResumed();

      expect(controller.isRestricted, isTrue);
      expect(controller.profile!.markets, <String>['AE', 'KW']);
      expect(controller.market, 'all');
    });

    test('no connection on the way back is not the end of the session', () async {
      final PlatformAdminController controller = await signedInOwnerWithOverview();
      service.onProfile = () async => unreachable<PlatformAdminProfile>();

      controller.onAppBackgrounded();
      now = now.add(const Duration(hours: 1));
      final bool cleared = await controller.onAppResumed();

      expect(cleared, isTrue);
      expect(controller.stage, PlatformAdminStage.signedIn);
    });

    test('leaving while signed out means nothing', () async {
      final PlatformAdminController controller = newController();
      await controller.restoreSession();
      service.calls.clear();

      controller.onAppBackgrounded();
      now = now.add(const Duration(hours: 5));

      expect(await controller.onAppResumed(), isFalse);
      expect(service.calls, isEmpty);
    });

    test('an answer that was on its way while the app was away is not shown when it arrives', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<PlatformOverviewModel>> late = Gate<PlatformAdminResult<PlatformOverviewModel>>();
      service.onOverview = (String market, int? windowDays) => late.future;
      final Future<void> loading = controller.loadOverview();

      controller.onAppBackgrounded();
      now = now.add(const Duration(minutes: 10));
      await controller.onAppResumed();
      late.open(PlatformAdminResult<PlatformOverviewModel>.success(FakePlatformAdminService.overviewOf('all', null)));
      await loading;

      expect(controller.overview, isNull);
      expect(controller.markets, isEmpty);
    });
  });

  group('a late answer, for what was thrown away while it was on its way', () {
    PlatformAdminResult<List<PlatformSessionModel>> sessionsAnswer() =>
        PlatformAdminResult<List<PlatformSessionModel>>.success(
            fixtureRows('sessions_owner').map(PlatformSessionModel.fromJson).toList());

    test('a failure for the market that was left is not shown under the new market', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<PlatformOverviewModel>> late = Gate<PlatformAdminResult<PlatformOverviewModel>>();
      service.onOverview = (String market, int? windowDays) => market == 'all'
          ? late.future
          : Future<PlatformAdminResult<PlatformOverviewModel>>.value(PlatformAdminResult<PlatformOverviewModel>.success(
              FakePlatformAdminService.overviewOf(market, windowDays)));
      final Future<void> loadingAll = controller.loadOverview();

      controller.selectMarket('KW');
      await controller.loadOverview();
      late.open(unreachable<PlatformOverviewModel>());
      await loadingAll;

      expect(controller.overviewFailure, isNull);
      expect(controller.hasOverview, isTrue);
    });

    test('a failure of the alerts of the market that was left is not shown under the new market', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<PlatformAlertPage>> late = Gate<PlatformAdminResult<PlatformAlertPage>>();
      service.onAlerts = (String market, int page, String? severity) => market == 'all'
          ? late.future
          : Future<PlatformAdminResult<PlatformAlertPage>>.value(PlatformAdminResult<PlatformAlertPage>.success(
              FakePlatformAdminService.alertsOf(market, page, severity)));
      final Future<void> loadingAll = controller.loadAlerts();

      controller.selectMarket('KW');
      await controller.loadAlerts();
      late.open(unreachable<PlatformAlertPage>());
      await loadingAll;

      expect(controller.alertsFailure, isNull);
      expect(controller.hasAlertList, isTrue);
    });

    test('a failure of a further page of the alerts of the market that was left is not shown under the new market',
        () async {
      final PlatformAdminController controller = await signedIn();
      await controller.loadAlerts();
      final Gate<PlatformAdminResult<PlatformAlertPage>> late = Gate<PlatformAdminResult<PlatformAlertPage>>();
      service.onAlerts = (String market, int page, String? severity) => market == 'all' && page == 2
          ? late.future
          : Future<PlatformAdminResult<PlatformAlertPage>>.value(PlatformAdminResult<PlatformAlertPage>.success(
              FakePlatformAdminService.alertsOf(market, page, severity)));
      final Future<void> loadingMore = controller.loadMoreAlerts();

      controller.selectMarket('KW');
      await controller.loadAlerts();
      late.open(unreachable<PlatformAlertPage>());
      await loadingMore;

      expect(controller.alertsFailure, isNull);
      expect(controller.isLoadingMoreAlerts, isFalse);
    });

    test('sessions that arrive after the admin signed out are not kept', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<List<PlatformSessionModel>>> late =
          Gate<PlatformAdminResult<List<PlatformSessionModel>>>();
      service.onSessions = () => late.future;
      final Future<void> loading = controller.loadSessions();

      await controller.signOut();
      late.open(sessionsAnswer());
      await loading;

      expect(controller.sessions, isNull);
      expect(controller.isLoadingSessions, isFalse);
    });

    test('lines of the audit log that arrive after the admin signed out are not kept', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<PlatformAuditPage>> late = Gate<PlatformAdminResult<PlatformAuditPage>>();
      service.onAuditLogs = (int page) => late.future;
      final Future<void> loading = controller.loadAuditLog();

      await controller.signOut();
      late.open(PlatformAdminResult<PlatformAuditPage>.success(FakePlatformAdminService.auditOf(1)));
      await loading;

      expect(controller.auditLines, isNull);
      expect(controller.isLoadingAudit, isFalse);
    });

    group('a refusal that comes after the admin signed out is not the end of a session that already ended', () {
      final Map<String, Future<({Future<Object?> pending, void Function() release})> Function(PlatformAdminController)>
          starts =
          <String, Future<({Future<Object?> pending, void Function() release})> Function(PlatformAdminController)>{
        'the overview': (PlatformAdminController controller) async {
          final Gate<PlatformAdminResult<PlatformOverviewModel>> gate =
              Gate<PlatformAdminResult<PlatformOverviewModel>>();
          service.onOverview = (String market, int? windowDays) => gate.future;
          return (
            pending: controller.loadOverview(),
            release: () => gate.open(refused<PlatformOverviewModel>('error_unauthenticated')),
          );
        },
        'the alerts': (PlatformAdminController controller) async {
          final Gate<PlatformAdminResult<PlatformAlertPage>> gate = Gate<PlatformAdminResult<PlatformAlertPage>>();
          service.onAlerts = (String market, int page, String? severity) => gate.future;
          return (
            pending: controller.loadAlerts(),
            release: () => gate.open(refused<PlatformAlertPage>('error_unauthenticated')),
          );
        },
        'a further page of the alerts': (PlatformAdminController controller) async {
          await controller.loadAlerts();
          final Gate<PlatformAdminResult<PlatformAlertPage>> gate = Gate<PlatformAdminResult<PlatformAlertPage>>();
          service.onAlerts = (String market, int page, String? severity) => gate.future;
          return (
            pending: controller.loadMoreAlerts(),
            release: () => gate.open(refused<PlatformAlertPage>('error_unauthenticated')),
          );
        },
        'the sessions': (PlatformAdminController controller) async {
          final Gate<PlatformAdminResult<List<PlatformSessionModel>>> gate =
              Gate<PlatformAdminResult<List<PlatformSessionModel>>>();
          service.onSessions = () => gate.future;
          return (
            pending: controller.loadSessions(),
            release: () => gate.open(refused<List<PlatformSessionModel>>('error_unauthenticated')),
          );
        },
        'ending a session': (PlatformAdminController controller) async {
          await controller.loadSessions();
          final Gate<PlatformAdminResult<int>> gate = Gate<PlatformAdminResult<int>>();
          service.onEndSession = (int id) => gate.future;
          return (pending: controller.endSession(2), release: () => gate.open(refused<int>('error_unauthenticated')));
        },
        'the audit log': (PlatformAdminController controller) async {
          final Gate<PlatformAdminResult<PlatformAuditPage>> gate = Gate<PlatformAdminResult<PlatformAuditPage>>();
          service.onAuditLogs = (int page) => gate.future;
          return (
            pending: controller.loadAuditLog(),
            release: () => gate.open(refused<PlatformAuditPage>('error_unauthenticated')),
          );
        },
        'a further page of the audit log': (PlatformAdminController controller) async {
          await controller.loadAuditLog();
          final Gate<PlatformAdminResult<PlatformAuditPage>> gate = Gate<PlatformAdminResult<PlatformAuditPage>>();
          service.onAuditLogs = (int page) => gate.future;
          return (
            pending: controller.loadMoreAuditLog(),
            release: () => gate.open(refused<PlatformAuditPage>('error_unauthenticated')),
          );
        },
        'who the admin is, read after a long time away': (PlatformAdminController controller) async {
          final Gate<PlatformAdminResult<PlatformAdminProfile>> gate =
              Gate<PlatformAdminResult<PlatformAdminProfile>>();
          service.onProfile = () => gate.future;
          controller.onAppBackgrounded();
          now = now.add(const Duration(minutes: 10));
          return (
            pending: controller.onAppResumed(),
            release: () => gate.open(refused<PlatformAdminProfile>('error_unauthenticated')),
          );
        },
      };

      for (final MapEntry<String,
              Future<({Future<Object?> pending, void Function() release})> Function(PlatformAdminController)> entry
          in starts.entries) {
        test('asked for: ${entry.key}', () async {
          final PlatformAdminController controller = await signedIn();
          final ({Future<Object?> pending, void Function() release}) late = await entry.value(controller);

          await controller.signOut();
          late.release();
          await late.pending;

          expect(controller.stage, PlatformAdminStage.signedOut);
          expect(controller.sessionEnded, isFalse, reason: 'the admin signed out; the server did not end anything');
        });
      }
    });
  });

  group('the scope of the viewer', () {
    test('is read from the server and never from the app: a restricted viewer is restricted', () async {
      final PlatformAdminController controller = await signedIn(as: restrictedProfile());

      expect(controller.isRestricted, isTrue);
      expect(controller.profile!.canSee('SA'), isFalse);
    });

    test('is restricted until it is known, so that nothing wide is shown by default', () {
      expect(newController().isRestricted, isTrue);
    });
  });

  group('leaving the shell', () {
    test('throws away what was held, and an answer that comes after is not an error', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<PlatformOverviewModel>> late = Gate<PlatformAdminResult<PlatformOverviewModel>>();
      service.onOverview = (String market, int? windowDays) => late.future;
      final Future<void> loading = controller.loadOverview();

      controller.dispose();
      late.open(PlatformAdminResult<PlatformOverviewModel>.success(FakePlatformAdminService.overviewOf('all', null)));
      await loading;

      expect(controller.overview, isNull);
      expect(controller.profile, isNull);
    });
  });
}
