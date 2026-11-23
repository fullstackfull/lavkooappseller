import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_alerts_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_alert_tile.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_choice_chips.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

/// The alerts, as the platform owner and a country manager meet them.
void main() {
  late FakePlatformAdminService service;
  late PlatformAdminController controller;
  late List<String> opened;

  setUp(() {
    service = FakePlatformAdminService();
    controller = PlatformAdminController(platformAdminServiceInterface: service);
    opened = <String>[];
  });

  Future<void> signIn({PlatformAdminProfile? as}) async {
    service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(as ?? ownerProfile());
    await controller.restoreSession();
  }

  /// The alerts screen, with what it asks for already answered.
  Future<void> pumpAlerts(
    WidgetTester tester, {
    Locale locale = PlatformAdminHarness.english,
    double textScale = 1.0,
    Size size = PlatformAdminHarness.tallPhone,
    bool loaded = true,
  }) async {
    if (loaded) await controller.loadAlerts();
    service.calls.clear();
    PlatformAdminHarness.useScreen(tester, size);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      home: Scaffold(body: PlatformAdminAlertsScreen(onOpenMarket: opened.add)),
      controller: controller,
      locale: locale,
      textScale: textScale,
    ));
    await tester.pump();
  }

  Finder tile(String id) =>
      find.byWidgetPredicate((Widget widget) => widget is PlatformAlertTile && widget.alert.id == id);

  Finder inTile(String id, Finder what) => find.descendant(of: tile(id), matching: what);

  List<String> shownIds(WidgetTester tester) => tester
      .widgetList<PlatformAlertTile>(find.byType(PlatformAlertTile))
      .map((PlatformAlertTile t) => t.alert.id)
      .toList();

  Finder severityChip(String label) =>
      find.descendant(of: find.byType(PlatformChipRow<String?>), matching: find.widgetWithText(InkWell, label));

  Finder marketChip(String label) =>
      find.descendant(of: find.byType(PlatformChipRow<String>), matching: find.widgetWithText(InkWell, label));

  Finder litChip() =>
      find.byWidgetPredicate((Widget widget) => widget is Semantics && widget.properties.selected == true);

  const String legal = 'a4882d780c5c00a1';
  const String stock = '3361a4f39417561e';
  const String pendingSaudi = 'ec9a46872bbdb300';
  const String pendingKuwait = '389667746dde9c43';

  /// Answers every request with the same page of alerts.
  void answerWith(List<Map<String, dynamic>> rows, {bool hasMore = false}) {
    service.onAlerts = (String market, int page, String? severity) async =>
        PlatformAdminResult<PlatformAlertPage>.success(PlatformAlertPage.fromJson(rows, <String, dynamic>{
          ...fixtureMeta('alerts_owner'),
          'total': rows.length,
          'has_more': hasMore,
        }));
  }

  group('the platform owner', () {
    setUp(signIn);

    testWidgets('sees the alerts in the order the server gave them, worst first', (WidgetTester tester) async {
      await pumpAlerts(tester);

      expect(shownIds(tester), <String>[legal, stock, pendingSaudi]);
    });

    testWidgets(
        'reads each as what it is about in the viewer\'s words, with the server\'s own sentence under it, how serious it is and the market',
        (WidgetTester tester) async {
      await pumpAlerts(tester);

      expect(inTile(legal, find.text('Legal documents not approved')), findsOneWidget);
      expect(
          inTile(
              legal,
              find.text(
                  'The KW storefront is active but its legal documents are not approved, so it cannot take orders.')),
          findsOneWidget);
      expect(inTile(legal, find.text('Critical')), findsOneWidget);
      expect(inTile(legal, find.text('Kuwait')), findsOneWidget);
      expect(inTile(stock, find.text('Products out of stock')), findsOneWidget);
      expect(inTile(stock, find.text('Warning')), findsOneWidget);
      expect(inTile(pendingSaudi, find.text('Orders pending for too long')), findsOneWidget);
      expect(inTile(pendingSaudi, find.text('Info')), findsOneWidget);
      expect(inTile(pendingSaudi, find.text('Saudi Arabia')), findsOneWidget);
    });

    testWidgets('the severity is told by an icon as well as by colour and words', (WidgetTester tester) async {
      await pumpAlerts(tester);

      expect(inTile(legal, find.byIcon(Icons.priority_high_rounded)), findsOneWidget);
      expect(inTile(stock, find.byIcon(Icons.warning_amber_rounded)), findsOneWidget);
      expect(inTile(pendingSaudi, find.byIcon(Icons.info_outline)), findsOneWidget);
    });

    testWidgets('drawing the list asks for nothing: the home asks', (WidgetTester tester) async {
      await pumpAlerts(tester);

      expect(service.calls, isEmpty);
    });

    testWidgets('an alert that links to a market opens that market, whichever market it is',
        (WidgetTester tester) async {
      await pumpAlerts(tester);

      await tester.tap(tile(legal));
      await tester.tap(tile(pendingSaudi));

      expect(opened, <String>['KW', 'SA']);
      expect(inTile(legal, find.byIcon(Icons.chevron_right)), findsOneWidget);
    });

    testWidgets('an alert whose link the app cannot route, or that has none, is read and not opened',
        (WidgetTester tester) async {
      final List<Map<String, dynamic>> rows = fixtureRows('alerts_owner');
      answerWith(<Map<String, dynamic>>[
        <String, dynamic>{...rows[0], 'deep_link': 'orders/12'},
        <String, dynamic>{...rows[1], 'deep_link': null},
        <String, dynamic>{...rows[2], 'deep_link': 'markets/KW/orders'},
      ]);
      await pumpAlerts(tester);

      await tester.tap(tile(legal));
      await tester.tap(tile(stock));
      await tester.tap(tile(pendingSaudi));

      expect(opened, isEmpty);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('a code or a severity the app has never heard of is written out from its own name',
        (WidgetTester tester) async {
      final List<Map<String, dynamic>> rows = fixtureRows('alerts_owner');
      answerWith(<Map<String, dynamic>>[
        <String, dynamic>{...rows[0], 'code': 'cart_abandoned_spike', 'severity': 'notice'},
      ]);
      await pumpAlerts(tester);

      expect(inTile(legal, find.text('Cart Abandoned Spike')), findsOneWidget);
      expect(inTile(legal, find.text('Notice')), findsOneWidget);
    });

    testWidgets('an alert of a market the app has no name for shows the market\'s code', (WidgetTester tester) async {
      final List<Map<String, dynamic>> rows = fixtureRows('alerts_owner');
      answerWith(<Map<String, dynamic>>[
        <String, dynamic>{...rows[0], 'market': 'EG', 'deep_link': 'markets/EG'},
      ]);
      await pumpAlerts(tester);

      expect(inTile(legal, find.text('EG')), findsOneWidget);
    });

    testWidgets('a market that has nothing wrong says so instead of showing an empty page',
        (WidgetTester tester) async {
      await pumpAlerts(tester);

      await tester.tap(marketChip('Qatar'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No alerts for this view.'), findsOneWidget);
      expect(find.byType(PlatformAlertTile), findsNothing);
    });
  });

  group('choosing what to look at', () {
    setUp(signIn);

    testWidgets('offers every alert and each severity, worst first, with all of them lit', (WidgetTester tester) async {
      await pumpAlerts(tester);

      final List<String> labels = tester
          .widgetList<PlatformChipRow<String?>>(find.byType(PlatformChipRow<String?>))
          .single
          .options
          .map((PlatformChipOption<String?> option) => option.label)
          .toList();

      expect(labels, <String>['All', 'Critical', 'Warning', 'Info']);
      expect(find.descendant(of: litChip(), matching: find.text('All')), findsOneWidget);
    });

    testWidgets('asks for a severity on its own, shows only those, and lights its chip', (WidgetTester tester) async {
      await pumpAlerts(tester);

      await tester.tap(severityChip('Critical'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['alerts all p1 critical']);
      expect(shownIds(tester), <String>[legal]);
      expect(find.descendant(of: litChip(), matching: find.text('Critical')), findsOneWidget);
    });

    testWidgets('going back to all of them shows the list that was held and asks for nothing',
        (WidgetTester tester) async {
      await pumpAlerts(tester);
      await tester.tap(severityChip('Critical'));
      await tester.pump();
      await tester.pump();
      service.calls.clear();

      await tester.tap(severityChip('All'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, isEmpty);
      expect(shownIds(tester), <String>[legal, stock, pendingSaudi]);
    });

    testWidgets('offers all markets and each market the server listed, by name', (WidgetTester tester) async {
      await pumpAlerts(tester);

      for (final String name in <String>['All markets', 'Saudi Arabia', 'UAE', 'Kuwait', 'Qatar', 'Bahrain', 'Oman']) {
        expect(marketChip(name), findsOneWidget, reason: name);
      }
    });

    testWidgets('a market is asked for alone, with the severity that was chosen, and is the market of the whole shell',
        (WidgetTester tester) async {
      await pumpAlerts(tester);
      await tester.tap(severityChip('Critical'));
      await tester.pump();
      await tester.pump();
      service.calls.clear();

      await tester.tap(marketChip('Kuwait'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['alerts KW p1 critical']);
      expect(controller.market, 'KW');
      expect(find.descendant(of: litChip(), matching: find.text('Kuwait')), findsOneWidget);
    });

    testWidgets('shows that it is asking, and nothing of the old market, while the new market\'s alerts are on the way',
        (WidgetTester tester) async {
      await pumpAlerts(tester);
      final Gate<PlatformAdminResult<PlatformAlertPage>> gate = Gate<PlatformAdminResult<PlatformAlertPage>>();
      service.onAlerts = (String market, int page, String? severity) => gate.future;

      await tester.tap(marketChip('Kuwait'));
      await tester.pump();

      expect(find.byType(PlatformAlertTile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.open(PlatformAdminResult<PlatformAlertPage>.success(FakePlatformAdminService.alertsOf('KW', 1, null)));
      await tester.pump();
      expect(find.byType(PlatformAlertTile), findsNWidgets(3));
    });
  });

  group('more of them', () {
    setUp(signIn);

    testWidgets('are offered when the server says there are more, and added under the first, and then not offered',
        (WidgetTester tester) async {
      await pumpAlerts(tester);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['alerts all p2 null']);
      expect(shownIds(tester), <String>[legal, stock, pendingSaudi, pendingKuwait]);
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('are not offered when there are none', (WidgetTester tester) async {
      answerWith(fixtureRows('alerts_owner'));

      await pumpAlerts(tester);

      expect(find.byType(PlatformAlertTile), findsNWidgets(4));
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('show that they are on the way, in the place of the button', (WidgetTester tester) async {
      await pumpAlerts(tester);
      final Gate<PlatformAdminResult<PlatformAlertPage>> gate = Gate<PlatformAdminResult<PlatformAlertPage>>();
      service.onAlerts = (String market, int page, String? severity) => gate.future;

      await tester.tap(find.text('Load more'));
      await tester.pump();

      expect(find.text('Load more'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PlatformAlertTile), findsNWidgets(3));
      gate.open(PlatformAdminResult<PlatformAlertPage>.success(FakePlatformAdminService.alertsOf('all', 2, null)));
      await tester.pump();
      expect(find.byType(PlatformAlertTile), findsNWidgets(4));
    });

    testWidgets('a page that cannot be had says so above the list, keeps the list, and can be asked for again',
        (WidgetTester tester) async {
      await pumpAlerts(tester);
      service.onAlerts = (String market, int page, String? severity) async => unreachable<PlatformAlertPage>();

      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.byType(PlatformAlertTile), findsNWidgets(3));
      expect(find.text('Load more'), findsOneWidget);
    });
  });

  group('when they cannot be had', () {
    setUp(signIn);

    testWidgets('no connection says so the way the app does elsewhere, and asking again works',
        (WidgetTester tester) async {
      service.onAlerts = (String market, int page, String? severity) async => unreachable<PlatformAlertPage>();
      await pumpAlerts(tester);

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.text('Check your internet connection and try again'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.byType(PlatformAlertTile), findsNothing);

      service.onAlerts = (String market, int page, String? severity) async =>
          PlatformAdminResult<PlatformAlertPage>.success(FakePlatformAdminService.alertsOf(market, page, severity));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PlatformAlertTile), findsNWidgets(3));
    });

    testWidgets('a market the grant does not hold says so, and offers the way back to all markets',
        (WidgetTester tester) async {
      service.onAlerts = (String market, int page, String? severity) async => market == 'all'
          ? PlatformAdminResult<PlatformAlertPage>.success(FakePlatformAdminService.alertsOf('all', page, severity))
          : refused<PlatformAlertPage>('error_market_not_allowed');
      await pumpAlerts(tester);
      await tester.tap(marketChip('Kuwait'));
      await tester.pump();
      await tester.pump();

      expect(find.text('You do not have access to this market.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing, reason: 'asking again would be refused again');

      await tester.tap(find.text('Back to all markets'));
      await tester.pump();
      await tester.pump();

      expect(controller.market, 'all');
      expect(find.byType(PlatformAlertTile), findsNWidgets(3));
    });

    testWidgets('a failure on top of a list that is already there says so above it, and leaves the list',
        (WidgetTester tester) async {
      await pumpAlerts(tester);
      service.onAlerts = (String market, int page, String? severity) async => unreachable<PlatformAlertPage>();

      await controller.loadAlerts(force: true);
      await tester.pump();

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.byType(PlatformAlertTile), findsNWidgets(3));
    });

    testWidgets('shows that it is asking, and nothing of an alert until it has the answer',
        (WidgetTester tester) async {
      final Gate<PlatformAdminResult<PlatformAlertPage>> gate = Gate<PlatformAdminResult<PlatformAlertPage>>();
      service.onAlerts = (String market, int page, String? severity) => gate.future;
      final Future<void> loading = controller.loadAlerts();

      await pumpAlerts(tester, loaded: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PlatformAlertTile), findsNothing);
      expect(find.text('No alerts for this view.'), findsNothing, reason: 'not yet known to be none');
      gate.open(PlatformAdminResult<PlatformAlertPage>.success(FakePlatformAdminService.alertsOf('all', 1, null)));
      await loading;
      await tester.pump();
      expect(find.byType(PlatformAlertTile), findsNWidgets(3));
    });

    testWidgets('pulling down asks for the first page again', (WidgetTester tester) async {
      await pumpAlerts(tester, size: PlatformAdminHarness.phone);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(service.calls, <String>['alerts all p1 null']);
    });
  });

  group('a country manager', () {
    setUp(() => signIn(as: restrictedProfile()));

    setUp(() {
      service.onMarkets = () async => PlatformAdminResult<PlatformMarketDirectory>.success(
          PlatformMarketDirectory.fromJson(fixtureData('markets_restricted')));
      service.onAlerts = (String market, int page, String? severity) async =>
          PlatformAdminResult<PlatformAlertPage>.success(
              PlatformAlertPage.fromJson(fixtureRows('alerts_restricted'), fixtureMeta('alerts_restricted')));
    });

    testWidgets('is offered the markets of the grant and not the others, and sees the alerts of those',
        (WidgetTester tester) async {
      await pumpAlerts(tester);

      expect(marketChip('My markets'), findsOneWidget);
      expect(marketChip('UAE'), findsOneWidget);
      expect(marketChip('Kuwait'), findsOneWidget);
      expect(marketChip('All markets'), findsNothing);
      expect(marketChip('Saudi Arabia'), findsNothing);
      expect(shownIds(tester), <String>[legal, stock, pendingKuwait]);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
    });

    testWidgets('cannot open an alert of a market that is not theirs, even if one was sent',
        (WidgetTester tester) async {
      final List<Map<String, dynamic>> rows = fixtureRows('alerts_restricted');
      answerWith(<Map<String, dynamic>>[
        ...rows,
        <String, dynamic>{...fixtureRows('alerts_owner')[2]},
      ]);
      await pumpAlerts(tester);

      await tester.tap(tile(pendingSaudi));
      await tester.tap(tile(legal));

      expect(opened, <String>['KW']);
      expect(inTile(pendingSaudi, find.byIcon(Icons.chevron_right)), findsNothing);
      expect(inTile(legal, find.byIcon(Icons.chevron_right)), findsOneWidget);
    });
  });

  group('in Arabic', () {
    setUp(signIn);

    testWidgets('reads from the right, in Arabic, and no key shows through', (WidgetTester tester) async {
      await pumpAlerts(tester, locale: PlatformAdminHarness.arabic);

      expect(Directionality.of(tester.element(find.byType(PlatformAdminAlertsScreen))), TextDirection.rtl);
      expect(inTile(legal, find.text('المستندات القانونية غير معتمدة')), findsOneWidget);
      expect(inTile(legal, find.text('حرج')), findsOneWidget);
      expect(inTile(legal, find.text('الكويت')), findsOneWidget);
      expect(inTile(stock, find.text('منتجات نفدت من المخزون')), findsOneWidget);
      expect(inTile(pendingSaudi, find.text('طلبات معلّقة منذ وقت طويل')), findsOneWidget);
      expect(severityChip('الكل'), findsOneWidget);
      expect(find.text('عرض المزيد'), findsOneWidget);
      expect(PlatformAdminHarness.texts(tester).where((String text) => text.startsWith('platform_admin_')), isEmpty);
    });

    testWidgets('the chips and the tiles start at the right edge, and the arrow of an alert points the way it reads',
        (WidgetTester tester) async {
      await pumpAlerts(tester, locale: PlatformAdminHarness.arabic);

      final double screenRight = tester.getTopRight(find.byType(PlatformAdminAlertsScreen)).dx;
      expect(tester.getTopRight(marketChip('كل الأسواق')).dx, greaterThan(screenRight - 60));
      expect(tester.getTopRight(tile(legal)).dx, greaterThan(screenRight - 40));
      expect(tester.getCenter(inTile(legal, find.byIcon(Icons.chevron_right))).dx,
          lessThan(tester.getCenter(inTile(legal, find.text('المستندات القانونية غير معتمدة'))).dx),
          reason: 'the arrow is at the end of the line, which in Arabic is on the left');
      expect(tester.widget<Icon>(inTile(legal, find.byIcon(Icons.chevron_right))).icon!.matchTextDirection, isTrue,
          reason: 'and it is drawn turned the other way there');
    });
  });

  group('on a small phone with large text', () {
    setUp(signIn);

    testWidgets('fits at the narrowest width with the text at twice its size, in either language, all the way down',
        (WidgetTester tester) async {
      for (final Locale locale in <Locale>[PlatformAdminHarness.english, PlatformAdminHarness.arabic]) {
        await pumpAlerts(tester, locale: locale, textScale: 2.0, size: PlatformAdminHarness.narrowPhone);

        expect(tester.takeException(), isNull, reason: locale.languageCode);
        for (int step = 0; step < 8; step++) {
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${locale.languageCode} after scrolling $step times');
        }
      }
    });

    testWidgets('and with a failure above the list, a market that has no name in the app and a long unknown code',
        (WidgetTester tester) async {
      final List<Map<String, dynamic>> rows = fixtureRows('alerts_owner');
      answerWith(<Map<String, dynamic>>[
        <String, dynamic>{
          ...rows[0],
          'market': 'EG',
          'code': 'a_very_long_code_the_app_has_never_heard_of_before',
          'deep_link': 'markets/EG',
        },
      ], hasMore: true);
      await pumpAlerts(tester, textScale: 2.0, size: const Size(320, 3000));
      service.onAlerts = (String market, int page, String? severity) async => unreachable<PlatformAlertPage>();
      await controller.loadMoreAlerts();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Could not reach the server'), findsOneWidget);
    });
  });
}
