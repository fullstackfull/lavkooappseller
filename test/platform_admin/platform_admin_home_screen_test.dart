import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_alerts_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_audit_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_home_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_overview_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_sessions_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_alert_tile.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_market_card.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

/// The platform admin's home: one tab for each screen of the shell.
void main() {
  late FakePlatformAdminService service;
  late PlatformAdminController controller;
  late DateTime clock;

  setUp(() async {
    service = FakePlatformAdminService();
    clock = DateTime.utc(2026, 11, 17, 10);
    controller = PlatformAdminController(platformAdminServiceInterface: service, now: () => clock);
    service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
    await controller.restoreSession();
    service.calls.clear();
  });

  Future<void> pumpHome(WidgetTester tester,
      {Locale locale = PlatformAdminHarness.english,
      double textScale = 1.0,
      Size size = PlatformAdminHarness.phone}) async {
    PlatformAdminHarness.useScreen(tester, size);
    await tester.pumpWidget(await PlatformAdminHarness.app(tester,
        home: const PlatformAdminHomeScreen(), controller: controller, locale: locale, textScale: textScale));
    await tester.pump();
    await tester.pump();
  }

  Finder tab(String label) => find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label));

  Finder card(String code) =>
      find.byWidgetPredicate((Widget widget) => widget is PlatformMarketCard && widget.overview.market == code);

  Finder alertOf(String id) =>
      find.byWidgetPredicate((Widget widget) => widget is PlatformAlertTile && widget.alert.id == id);

  Finder inTitle(String title) => find.descendant(of: find.byType(AppBar), matching: find.text(title));

  /// Opens a tab and lets what it asks for arrive.
  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(tab(label));
    await tester.pump();
    await tester.pump();
  }

  group('opening', () {
    testWidgets('shows the overview first, and asks for it and for the facts about the markets, and for nothing else',
        (WidgetTester tester) async {
      await pumpHome(tester);

      expect(find.byType(PlatformAdminOverviewScreen), findsOneWidget);
      expect(service.calls, containsAll(<String>['markets', 'overview all null']));
      expect(service.count('sessions'), 0);
      expect(find.byType(PlatformAdminSessionsScreen), findsNothing,
          reason: 'a tab that has not been opened has not been built');
    });

    testWidgets('has a tab for each screen, which are the platform\'s and nobody else\'s', (WidgetTester tester) async {
      await pumpHome(tester);

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(
          find.descendant(of: find.byType(BottomNavigationBar), matching: find.byType(InkResponse)), findsNWidgets(4));
      expect(tab('Overview'), findsOneWidget);
      expect(tab('Alerts'), findsOneWidget);
      expect(tab('Sessions'), findsOneWidget);
      expect(tab('Audit log'), findsOneWidget);
    });

    testWidgets('names the screen in front in its title', (WidgetTester tester) async {
      await pumpHome(tester);

      expect(inTitle('Overview'), findsOneWidget);
      for (final String title in <String>['Alerts', 'Sessions', 'Audit log']) {
        await tester.tap(tab(title));
        await tester.pump();

        expect(inTitle(title), findsOneWidget, reason: title);
      }
    });
  });

  group('moving between tabs', () {
    testWidgets('a tab asks for what it shows the first time it is opened', (WidgetTester tester) async {
      await pumpHome(tester);
      service.calls.clear();

      await tester.tap(tab('Sessions'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['sessions']);
      expect(find.byType(PlatformAdminSessionsScreen), findsOneWidget);
    });

    testWidgets('and is not asked for again when it is opened again, because what it holds is still held',
        (WidgetTester tester) async {
      await pumpHome(tester);
      await tester.tap(tab('Sessions'));
      await tester.pump();
      await tester.pump();
      service.calls.clear();

      await tester.tap(tab('Overview'));
      await tester.pump();
      await tester.tap(tab('Sessions'));
      await tester.pump();

      expect(service.calls, isEmpty);
    });

    testWidgets('a market chosen on one tab is the market of the next one, and the figures of the old market are gone',
        (WidgetTester tester) async {
      await pumpHome(tester);
      await tester.tap(find.widgetWithText(InkWell, 'Kuwait'));
      await tester.pump();
      await tester.pump();

      await tester.tap(tab('Sessions'));
      await tester.pump();
      await tester.tap(tab('Overview'));
      await tester.pump();

      expect(controller.market, 'KW');
      expect(controller.overview!.markets.map((market) => market.market), <String>['KW']);
    });
  });

  group('the alerts and the audit log', () {
    testWidgets('the alerts are asked for the first time their tab is opened, and then they are held',
        (WidgetTester tester) async {
      await pumpHome(tester, size: PlatformAdminHarness.tallPhone);
      expect(find.byType(PlatformAdminAlertsScreen), findsNothing);
      service.calls.clear();

      await openTab(tester, 'Alerts');

      expect(service.calls, <String>['alerts all p1 null'], reason: 'the markets are already held');
      expect(find.byType(PlatformAlertTile), findsNWidgets(3));
      service.calls.clear();

      await openTab(tester, 'Overview');
      await openTab(tester, 'Alerts');

      expect(service.calls, isEmpty);
    });

    testWidgets('the alerts ask for the markets too when the overview has not got them', (WidgetTester tester) async {
      service.onMarkets = () async => unreachable<PlatformMarketDirectory>();
      await pumpHome(tester, size: PlatformAdminHarness.tallPhone);
      expect(controller.markets, isEmpty);
      service.onMarkets = () async => PlatformAdminResult<PlatformMarketDirectory>.success(
          PlatformMarketDirectory.fromJson(fixtureData('markets_owner')));
      service.calls.clear();

      await openTab(tester, 'Alerts');

      expect(service.calls, <String>['markets', 'alerts all p1 null']);
      expect(controller.markets, hasLength(6));
    });

    testWidgets('the audit log is asked for the first time its tab is opened, and then it is held',
        (WidgetTester tester) async {
      await pumpHome(tester, size: PlatformAdminHarness.tallPhone);
      service.calls.clear();

      await openTab(tester, 'Audit log');

      expect(service.calls, <String>['auditLogs p1']);
      expect(find.byType(PlatformAdminAuditScreen), findsOneWidget);
      service.calls.clear();

      await openTab(tester, 'Overview');
      await openTab(tester, 'Audit log');

      expect(service.calls, isEmpty);
    });

    testWidgets('the market chosen on the overview is the market of the alerts', (WidgetTester tester) async {
      await pumpHome(tester, size: PlatformAdminHarness.tallPhone);
      await tester.tap(find.widgetWithText(InkWell, 'Kuwait'));
      await tester.pump();
      await tester.pump();
      service.calls.clear();

      await openTab(tester, 'Alerts');

      expect(service.calls, <String>['alerts KW p1 null']);
      expect(find.descendant(of: find.byType(PlatformAdminAlertsScreen), matching: find.byType(PlatformAlertTile)),
          findsNWidgets(3));
    });
  });

  group('moving from an alert to its market, and from a market to its alerts', () {
    testWidgets(
        'the alert counts of a market card open the alerts of that market, with every severity, whichever one was looked at before',
        (WidgetTester tester) async {
      await pumpHome(tester, size: PlatformAdminHarness.tallPhone);
      controller.selectAlertSeverity('critical');
      service.calls.clear();

      await tester.tap(find.descendant(of: card('KW'), matching: find.text('Critical 1')));
      await tester.pump();
      await tester.pump();

      expect(controller.market, 'KW');
      expect(controller.alertSeverity, isNull);
      expect(inTitle('Alerts'), findsOneWidget);
      expect(find.byType(PlatformAdminAlertsScreen), findsOneWidget);
      expect(service.calls, <String>['alerts KW p1 null']);
    });

    testWidgets('only a card that has alerts can be opened, and it says so with an arrow', (WidgetTester tester) async {
      await pumpHome(tester, size: PlatformAdminHarness.tallPhone);

      expect(find.descendant(of: card('KW'), matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
      expect(find.descendant(of: card('SA'), matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
      expect(find.descendant(of: card('QA'), matching: find.byIcon(Icons.chevron_right)), findsNothing);

      await tester.tap(find.descendant(of: card('QA'), matching: find.text('No alerts')));
      await tester.pump();

      expect(inTitle('Overview'), findsOneWidget);
      expect(controller.market, 'all');
    });

    testWidgets('an alert opens the overview of its market, with the window that was chosen kept',
        (WidgetTester tester) async {
      await pumpHome(tester, size: PlatformAdminHarness.tallPhone);
      await tester.tap(find.widgetWithText(InkWell, '7 days'));
      await tester.pump();
      await tester.pump();
      await openTab(tester, 'Alerts');
      service.calls.clear();

      await tester.tap(alertOf('a4882d780c5c00a1'));
      await tester.pump();
      await tester.pump();

      expect(controller.market, 'KW');
      expect(inTitle('Overview'), findsOneWidget);
      expect(service.calls, <String>['overview KW 7']);
      expect(find.byType(PlatformMarketCard), findsOneWidget);
      expect(card('KW'), findsOneWidget);
    });

    testWidgets('and then the alerts are those of that market, and are asked for once', (WidgetTester tester) async {
      await pumpHome(tester, size: PlatformAdminHarness.tallPhone);
      await openTab(tester, 'Alerts');
      await tester.tap(alertOf('ec9a46872bbdb300'));
      await tester.pump();
      await tester.pump();
      service.calls.clear();

      await openTab(tester, 'Alerts');

      expect(controller.market, 'SA');
      expect(service.calls, <String>['alerts SA p1 null']);
    });

    testWidgets(
        'the card of the market that was opened from the alerts is the only one, and nothing of the others is left',
        (WidgetTester tester) async {
      await pumpHome(tester, size: PlatformAdminHarness.tallPhone);
      await openTab(tester, 'Alerts');

      await tester.tap(alertOf('a4882d780c5c00a1'));
      await tester.pump();
      await tester.pump();

      expect(controller.overview!.markets.map((market) => market.market), <String>['KW']);
      expect(find.byType(PlatformMarketCard), findsOneWidget);
    });
  });

  group('when the app is left and comes back', () {
    Future<void> leaveFor(WidgetTester tester, Duration away) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock = clock.add(away);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('after a few minutes nothing is asked again and nothing is thrown away', (WidgetTester tester) async {
      await pumpHome(tester);
      service.calls.clear();

      await leaveFor(tester, const Duration(minutes: 4));

      expect(service.calls, isEmpty);
      expect(controller.hasOverview, isTrue);
    });

    testWidgets(
        'after a long time everything that was held is thrown away, who the admin is is read again, and the screen in front counts again',
        (WidgetTester tester) async {
      await pumpHome(tester);
      service.calls.clear();

      await leaveFor(tester, const Duration(minutes: 30));

      expect(service.calls, <String>['profile', 'markets', 'overview all null']);
      expect(controller.hasOverview, isTrue);
      expect(find.byType(PlatformAdminOverviewScreen), findsOneWidget);
    });

    testWidgets('a tab that is not in front is not asked for until it is opened', (WidgetTester tester) async {
      await pumpHome(tester);
      await tester.tap(tab('Sessions'));
      await tester.pump();
      await tester.pump();
      service.calls.clear();

      await leaveFor(tester, const Duration(minutes: 30));

      expect(service.calls, <String>['profile', 'sessions']);
      expect(controller.hasOverview, isFalse, reason: 'the overview was thrown away and nobody is looking at it');
      service.calls.clear();
      await tester.tap(tab('Overview'));
      await tester.pump();
      await tester.pump();
      expect(service.calls, containsAll(<String>['markets', 'overview all null']));
    });

    testWidgets('the alerts tab in front is thrown away and asked for again, markets and all',
        (WidgetTester tester) async {
      await pumpHome(tester, size: PlatformAdminHarness.tallPhone);
      await openTab(tester, 'Alerts');
      service.calls.clear();

      await leaveFor(tester, const Duration(minutes: 30));

      expect(service.calls, <String>['profile', 'markets', 'alerts all p1 null']);
      expect(find.byType(PlatformAlertTile), findsNWidgets(3));
    });

    testWidgets('a session the server has ended meanwhile puts the admin back at the sign-in, and asks for nothing',
        (WidgetTester tester) async {
      await pumpHome(tester);
      service.calls.clear();
      service.onProfile = () async => refused<PlatformAdminProfile>('error_unauthenticated');

      await leaveFor(tester, const Duration(hours: 2));

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(service.calls, <String>['profile']);
    });

    testWidgets('leaving the screen stops it listening to the app', (WidgetTester tester) async {
      await pumpHome(tester);
      await tester.pumpWidget(const SizedBox());
      service.calls.clear();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock = clock.add(const Duration(hours: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(service.calls, isEmpty);
    });
  });

  group('in Arabic', () {
    testWidgets('reads from the right, in Arabic, with no key showing through', (WidgetTester tester) async {
      await pumpHome(tester, locale: PlatformAdminHarness.arabic);

      expect(Directionality.of(tester.element(find.byType(PlatformAdminHomeScreen))), TextDirection.rtl);
      expect(tab('ملخص'), findsOneWidget);
      expect(tab('التنبيهات'), findsOneWidget);
      expect(tab('الجلسات'), findsOneWidget);
      expect(tab('سجل التدقيق'), findsOneWidget);
      expect(PlatformAdminHarness.texts(tester).where((String text) => text.startsWith('platform_admin_')), isEmpty);
    });
  });

  group('on a small phone with large text', () {
    testWidgets('the tabs fit at the narrowest width with the text at twice its size, in either language',
        (WidgetTester tester) async {
      for (final Locale locale in <Locale>[PlatformAdminHarness.english, PlatformAdminHarness.arabic]) {
        await pumpHome(tester, locale: locale, textScale: 2.0, size: PlatformAdminHarness.narrowPhone);

        expect(tester.takeException(), isNull, reason: locale.languageCode);
        final Finder tabs = find.descendant(of: find.byType(BottomNavigationBar), matching: find.byType(InkResponse));
        for (int index = 1; index < 4; index++) {
          await tester.tap(tabs.at(index));
          await tester.pump();
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${locale.languageCode} on tab $index');
        }
      }
    });
  });
}
