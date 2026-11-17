import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_overview_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_market_card.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

/// The overview, as the platform owner and a country manager meet it.
void main() {
  late FakePlatformAdminService service;
  late PlatformAdminController controller;

  setUp(() {
    service = FakePlatformAdminService();
    controller = PlatformAdminController(platformAdminServiceInterface: service);
  });

  Future<void> signIn({PlatformAdminProfile? as}) async {
    service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(as ?? ownerProfile());
    await controller.restoreSession();
  }

  /// The overview screen, with what it asks for already answered.
  Future<void> pumpOverview(
    WidgetTester tester, {
    Locale locale = PlatformAdminHarness.english,
    double textScale = 1.0,
    Size size = PlatformAdminHarness.tallPhone,
    bool loaded = true,
  }) async {
    if (loaded) await controller.loadOverview();
    service.calls.clear();
    PlatformAdminHarness.useScreen(tester, size);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      home: const Scaffold(body: PlatformAdminOverviewScreen()),
      controller: controller,
      locale: locale,
      textScale: textScale,
    ));
    await tester.pump();
  }

  Finder card(String code) =>
      find.byWidgetPredicate((Widget widget) => widget is PlatformMarketCard && widget.overview.market == code);

  Finder inCard(String code, Finder what) => find.descendant(of: card(code), matching: what);

  /// The figure a card gives under a label.
  String figureOf(WidgetTester tester, String code, String label) {
    final Finder row = find.descendant(
        of: card(code),
        matching: find.byWidgetPredicate((Widget widget) => widget is PlatformFigureRow && widget.label == label));
    return tester.widget<PlatformFigureRow>(row).value;
  }

  group('the platform owner', () {
    setUp(signIn);

    testWidgets('sees a card for every market, in the order the platform configured them, and the facts about each',
        (WidgetTester tester) async {
      await pumpOverview(tester);

      final List<String> codes = tester
          .widgetList<PlatformMarketCard>(find.byType(PlatformMarketCard))
          .map((PlatformMarketCard card) => card.overview.market)
          .toList();
      expect(codes, <String>['SA', 'AE', 'KW', 'QA', 'BH', 'OM']);
      expect(inCard('SA', find.text('Saudi Arabia')), findsOneWidget);
      expect(inCard('KW', find.text('Kuwait')), findsOneWidget);
      expect(inCard('KW', find.text('KWD')), findsOneWidget,
          reason: 'the currency of the market is a label of the market');
      expect(inCard('SA', find.text('Active')), findsOneWidget);
      expect(inCard('QA', find.text('Not active')), findsOneWidget);
      expect(inCard('SA', find.text('Legal documents ready')), findsOneWidget);
      expect(inCard('KW', find.text('Legal documents not ready')), findsOneWidget,
          reason: 'active, but not allowed to sell');
    });

    testWidgets(
        'reads each market\'s orders by status, what waits, the refund requests and the stock, as the server counted them',
        (WidgetTester tester) async {
      await pumpOverview(tester);

      expect(inCard('SA', find.text('Pending 1')), findsOneWidget);
      expect(inCard('SA', find.text('Confirmed 1')), findsOneWidget);
      expect(inCard('SA', find.text('Delivered 2')), findsOneWidget);
      expect(inCard('SA', find.text('Canceled 1')), findsNothing, reason: 'a status with no order is not drawn');
      expect(inCard('KW', find.text('Canceled 1')), findsOneWidget);
      expect(inCard('SA', find.text('Latest order')), findsOneWidget);
      expect(inCard('SA', find.text(PlatformAdminTexts.moment(DateTime.utc(2026, 11, 17, 12)))), findsOneWidget);
      expect(figureOf(tester, 'SA', 'Orders in this window'), '5');
      expect(figureOf(tester, 'SA', 'Waiting to be fulfilled'), '4');
      expect(figureOf(tester, 'SA', 'Refund requests'), '2');
      expect(figureOf(tester, 'SA', 'Refund requests pending'), '1');
      expect(figureOf(tester, 'SA', 'Products out of stock'), '1');
      expect(figureOf(tester, 'SA', 'Products low in stock'), '3');
      expect(figureOf(tester, 'KW', 'Products out of stock'), '2');
    });

    testWidgets('a market with nothing in it still has its card, with zeros, no latest order and no alert',
        (WidgetTester tester) async {
      await pumpOverview(tester);

      expect(inCard('QA', find.text('Orders in this window')), findsOneWidget);
      expect(inCard('QA', find.text('Latest order')), findsNothing);
      expect(inCard('QA', find.text('No alerts')), findsOneWidget);
      expect(inCard('QA', find.textContaining('Pending')), findsNothing);
    });

    testWidgets('says how many alerts a market has, by how serious, in words as well as colour',
        (WidgetTester tester) async {
      await pumpOverview(tester);

      expect(inCard('KW', find.text('Critical 1')), findsOneWidget);
      expect(inCard('KW', find.text('Warning 1')), findsOneWidget);
      expect(inCard('KW', find.text('Info 1')), findsOneWidget);
      expect(inCard('SA', find.text('Info 1')), findsOneWidget);
      expect(inCard('SA', find.textContaining('Critical')), findsNothing);
    });

    testWidgets('a status the app has never heard of is shown under its own name', (WidgetTester tester) async {
      service.onOverview = (String market, int? windowDays) async => PlatformAdminResult<PlatformOverviewModel>.success(
          PlatformOverviewModel.fromJson(fixtureData('overview_owner_unknown_status')));

      await pumpOverview(tester);

      expect(inCard('SA', find.text('On Hold 1')), findsOneWidget);
    });

    testWidgets(
        'keeps the orders that belong to no single market in a card of their own, and says what they are in one line',
        (WidgetTester tester) async {
      await pumpOverview(tester);
      await tester.scrollUntilVisible(find.byType(PlatformUnattributedCard), 300,
          scrollable: find.byType(Scrollable).first);

      expect(find.text('Orders without a single market'), findsOneWidget);
      expect(
          find.text(
              'Not counted in any market: orders with no products, deleted products, or products from more than one market.'),
          findsOneWidget);
      expect(
          find.descendant(of: find.byType(PlatformUnattributedCard), matching: find.text('Pending 2')), findsOneWidget);
    });

    testWidgets(
        'says why there is no sales figure, once for every card and once for the orders without a market, and shows no amount',
        (WidgetTester tester) async {
      await pumpOverview(tester);
      await tester.scrollUntilVisible(find.byType(PlatformUnattributedCard), 300,
          scrollable: find.byType(Scrollable).first);

      expect(find.text('Sales are not shown: orders do not record their currency yet.', skipOffstage: false),
          findsNWidgets(7));
    });

    testWidgets('shows the window the server counted, and how fresh the figures are', (WidgetTester tester) async {
      await pumpOverview(tester);

      expect(find.textContaining('30 days'), findsWidgets);
      expect(find.textContaining('19 Oct 2026'), findsOneWidget);
      expect(find.textContaining('17 Nov 2026'), findsOneWidget);
      expect(find.text('Live · Updated ${PlatformAdminTexts.moment(DateTime.utc(2026, 11, 17, 6))}'), findsOneWidget);
      expect(find.text('Shortened to the longest window the server allows.'), findsNothing);
    });

    testWidgets('says when the server cut the window it was asked for', (WidgetTester tester) async {
      service.onOverview = (String market, int? windowDays) async => PlatformAdminResult<PlatformOverviewModel>.success(
          PlatformOverviewModel.fromJson(fixtureData('overview_owner_window_clamped')));

      await pumpOverview(tester);

      expect(find.text('Shortened to the longest window the server allows.'), findsOneWidget);
    });

    testWidgets('a saved copy says it is not live', (WidgetTester tester) async {
      service.onOverview = (String market, int? windowDays) async {
        final Map<String, dynamic> body = fixtureData('overview_owner_all')
          ..['freshness'] = <String, dynamic>{'mode': 'cached', 'cached': true};
        return PlatformAdminResult<PlatformOverviewModel>.success(PlatformOverviewModel.fromJson(body));
      };

      await pumpOverview(tester);

      expect(find.textContaining('Saved copy'), findsOneWidget);
      expect(find.textContaining('Live'), findsNothing);
    });

    testWidgets('has no restricted-view note', (WidgetTester tester) async {
      await pumpOverview(tester);

      expect(find.text('Restricted view: you see only the markets assigned to you.'), findsNothing);
      expect(find.text('All markets'), findsOneWidget);
      expect(find.text('My markets'), findsNothing);
    });
  });

  group('choosing a market', () {
    setUp(signIn);

    testWidgets('offers all markets and each market the server listed, by name', (WidgetTester tester) async {
      await pumpOverview(tester);

      for (final String name in <String>['All markets', 'Saudi Arabia', 'UAE', 'Kuwait', 'Qatar', 'Bahrain', 'Oman']) {
        expect(find.widgetWithText(InkWell, name), findsOneWidget, reason: name);
      }
    });

    testWidgets('asks for that market alone, and no card of any other market is left on the screen',
        (WidgetTester tester) async {
      await pumpOverview(tester);

      await tester.tap(find.widgetWithText(InkWell, 'Kuwait'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['overview KW null']);
      expect(find.byType(PlatformMarketCard), findsOneWidget);
      expect(card('KW'), findsOneWidget);
      expect(find.text('Saudi Arabia'), findsOneWidget, reason: 'only as the name of a chip');
      expect(find.byType(PlatformUnattributedCard), findsNothing,
          reason: 'a single market has no bucket of orders that belong to none');
    });

    testWidgets('shows what it is doing while the new market is being counted, and not the old one\'s figures',
        (WidgetTester tester) async {
      await pumpOverview(tester);
      final Gate<PlatformAdminResult<PlatformOverviewModel>> gate = Gate<PlatformAdminResult<PlatformOverviewModel>>();
      service.onOverview = (String market, int? windowDays) => gate.future;

      await tester.tap(find.widgetWithText(InkWell, 'Kuwait'));
      await tester.pump();

      expect(find.byType(PlatformMarketCard), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.open(PlatformAdminResult<PlatformOverviewModel>.success(FakePlatformAdminService.overviewOf('KW', null)));
      await tester.pump();
      expect(card('KW'), findsOneWidget);
    });

    testWidgets('going back to all markets counts them again, and does not remember them', (WidgetTester tester) async {
      await pumpOverview(tester);
      await tester.tap(find.widgetWithText(InkWell, 'Kuwait'));
      await tester.pump();
      await tester.pump();
      service.calls.clear();

      await tester.tap(find.widgetWithText(InkWell, 'All markets'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['overview all null']);
      expect(find.byType(PlatformMarketCard), findsNWidgets(6));
    });

    testWidgets('the chip that is chosen is the one that is lit', (WidgetTester tester) async {
      await pumpOverview(tester);
      final Finder chosen =
          find.byWidgetPredicate((Widget widget) => widget is Semantics && widget.properties.selected == true);

      expect(find.descendant(of: chosen, matching: find.text('All markets')), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, 'Kuwait'));
      await tester.pump();
      await tester.pump();

      expect(find.descendant(of: chosen, matching: find.text('Kuwait')), findsOneWidget);
      expect(find.descendant(of: chosen, matching: find.text('All markets')), findsNothing);
    });
  });

  group('choosing a window', () {
    setUp(signIn);

    testWidgets('offers a week, a month and the longest, with the month lit because that is what the server counted',
        (WidgetTester tester) async {
      await pumpOverview(tester);
      final Finder chosen =
          find.byWidgetPredicate((Widget widget) => widget is Semantics && widget.properties.selected == true);

      expect(find.widgetWithText(InkWell, '7 days'), findsOneWidget);
      expect(find.widgetWithText(InkWell, '30 days'), findsOneWidget);
      expect(find.widgetWithText(InkWell, '92 days'), findsOneWidget);
      expect(find.descendant(of: chosen, matching: find.text('30 days')), findsOneWidget);
    });

    testWidgets('a week is asked for as a week, and what the server counted is what is written under the chips',
        (WidgetTester tester) async {
      await pumpOverview(tester);

      await tester.tap(find.widgetWithText(InkWell, '7 days'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['overview all 7']);
      expect(find.textContaining('11 Nov 2026'), findsOneWidget);
      expect(find.textContaining('7 days'), findsWidgets);
    });

    testWidgets('the longest window is asked for as 92 days', (WidgetTester tester) async {
      await pumpOverview(tester);

      await tester.tap(find.widgetWithText(InkWell, '92 days'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['overview all 92']);
    });

    testWidgets('changing the window does not forget the market that was chosen', (WidgetTester tester) async {
      await pumpOverview(tester);
      await tester.tap(find.widgetWithText(InkWell, 'Kuwait'));
      await tester.pump();
      await tester.pump();
      service.calls.clear();

      await tester.tap(find.widgetWithText(InkWell, '7 days'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['overview KW 7']);
    });
  });

  group('a country manager', () {
    setUp(() => signIn(as: restrictedProfile()));

    setUp(() {
      service.onMarkets = () async => PlatformAdminResult<PlatformMarketDirectory>.success(
          PlatformMarketDirectory.fromJson(fixtureData('markets_restricted')));
      service.onOverview = (String market, int? windowDays) async => PlatformAdminResult<PlatformOverviewModel>.success(
          PlatformOverviewModel.fromJson(fixtureData('overview_restricted_all')));
    });

    testWidgets('is told it is a restricted view, and that these are their markets and not all of them',
        (WidgetTester tester) async {
      await pumpOverview(tester);

      expect(find.text('Restricted view: you see only the markets assigned to you.'), findsOneWidget);
      expect(find.text('My markets'), findsOneWidget);
      expect(find.text('All markets'), findsNothing);
    });

    testWidgets(
        'is offered only the markets of the grant, and sees only their cards, and no bucket of orders without a market',
        (WidgetTester tester) async {
      await pumpOverview(tester);

      expect(find.widgetWithText(InkWell, 'UAE'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Kuwait'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Saudi Arabia'), findsNothing);
      expect(find.byType(PlatformMarketCard), findsNWidgets(2));
      expect(find.byType(PlatformUnattributedCard), findsNothing);
      expect(find.text('Saudi Arabia'), findsNothing);
    });

    testWidgets('a grant with no market that exists says so, instead of showing nothing', (WidgetTester tester) async {
      service.onMarkets = () async => PlatformAdminResult<PlatformMarketDirectory>.success(
          PlatformMarketDirectory.fromJson(fixtureData('markets_none')));
      service.onOverview = (String market, int? windowDays) async => PlatformAdminResult<PlatformOverviewModel>.success(
          PlatformOverviewModel.fromJson(fixtureData('overview_no_markets')));

      await pumpOverview(tester);

      expect(find.text('No market is assigned to this account yet.'), findsOneWidget);
      expect(find.byType(PlatformMarketCard), findsNothing);
    });
  });

  group('when it cannot be counted', () {
    setUp(signIn);

    testWidgets('no connection says so the way the app does elsewhere, and asking again works',
        (WidgetTester tester) async {
      service.onOverview = (String market, int? windowDays) async => unreachable<PlatformOverviewModel>();
      await pumpOverview(tester);

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.text('Check your internet connection and try again'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.byType(PlatformMarketCard), findsNothing);

      service.onOverview = (String market, int? windowDays) async =>
          PlatformAdminResult<PlatformOverviewModel>.success(FakePlatformAdminService.overviewOf(market, windowDays));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PlatformMarketCard), findsNWidgets(6));
    });

    testWidgets('a market the grant does not hold says so, and offers the way back to all markets',
        (WidgetTester tester) async {
      service.onOverview = (String market, int? windowDays) async => market == 'all'
          ? PlatformAdminResult<PlatformOverviewModel>.success(FakePlatformAdminService.overviewOf('all', null))
          : refused<PlatformOverviewModel>('error_market_not_allowed');
      await pumpOverview(tester);
      await tester.tap(find.widgetWithText(InkWell, 'Kuwait'));
      await tester.pump();
      await tester.pump();

      expect(find.text('You do not have access to this market.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing, reason: 'asking again would be refused again');

      await tester.tap(find.text('Back to all markets'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PlatformMarketCard), findsNWidgets(6));
    });

    testWidgets('being asked to wait says when to try again', (WidgetTester tester) async {
      service.onOverview =
          (String market, int? windowDays) async => refused<PlatformOverviewModel>('error_login_throttled');
      await pumpOverview(tester);

      final String clock = PlatformAdminTexts.tryAgainClock(controller.overviewFailure!.retryAt!);
      expect(find.text('Too many attempts. Try again at $clock'), findsOneWidget);
    });

    testWidgets('an API that is not available, or not ready, says that', (WidgetTester tester) async {
      service.onOverview =
          (String market, int? windowDays) async => refused<PlatformOverviewModel>('error_api_switched_off');
      await pumpOverview(tester);
      expect(find.text('Platform admin is not available right now.'), findsOneWidget);

      service.onOverview = (String market, int? windowDays) async => refused<PlatformOverviewModel>('error_not_ready');
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Platform admin is not ready yet. Try again later.'), findsOneWidget);
    });

    testWidgets('a failure on top of figures that are already there says so above them, and leaves them where they are',
        (WidgetTester tester) async {
      await pumpOverview(tester);
      service.onOverview = (String market, int? windowDays) async => unreachable<PlatformOverviewModel>();

      await controller.loadOverview(force: true);
      await tester.pump();

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.byType(PlatformMarketCard), findsNWidgets(6));
    });

    testWidgets('shows that it is counting, and nothing of a market until it has', (WidgetTester tester) async {
      final Gate<PlatformAdminResult<PlatformOverviewModel>> gate = Gate<PlatformAdminResult<PlatformOverviewModel>>();
      service.onOverview = (String market, int? windowDays) => gate.future;
      final Future<void> loading = controller.loadOverview();

      await pumpOverview(tester, loaded: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PlatformMarketCard), findsNothing);
      gate.open(PlatformAdminResult<PlatformOverviewModel>.success(FakePlatformAdminService.overviewOf('all', null)));
      await loading;
      await tester.pump();
      expect(find.byType(PlatformMarketCard), findsNWidgets(6));
    });

    testWidgets('pulling down counts again, both the markets and their figures', (WidgetTester tester) async {
      await pumpOverview(tester, size: PlatformAdminHarness.phone);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(service.calls, containsAll(<String>['markets', 'overview all null']));
    });
  });

  group('in Arabic', () {
    setUp(signIn);

    testWidgets('reads from the right, in Arabic, with the names of the markets and no key showing through',
        (WidgetTester tester) async {
      await pumpOverview(tester, locale: PlatformAdminHarness.arabic);

      expect(Directionality.of(tester.element(find.byType(PlatformAdminOverviewScreen))), TextDirection.rtl);
      expect(find.widgetWithText(InkWell, 'كل الأسواق'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'الكويت'), findsOneWidget);
      expect(find.widgetWithText(InkWell, '7 أيام'), findsOneWidget);
      expect(find.text('المبيعات غير معروضة: الطلبات لا تسجّل عملتها بعد.', skipOffstage: false), findsNWidgets(7));
      expect(PlatformAdminHarness.texts(tester).where((String text) => text.startsWith('platform_admin_')), isEmpty);
    });

    testWidgets('the chips and the cards start at the right edge', (WidgetTester tester) async {
      await pumpOverview(tester, locale: PlatformAdminHarness.arabic);

      final double screenRight = tester.getTopRight(find.byType(PlatformAdminOverviewScreen)).dx;
      expect(tester.getTopRight(find.widgetWithText(InkWell, 'كل الأسواق')).dx, greaterThan(screenRight - 60));
      expect(tester.getTopRight(card('SA')).dx, greaterThan(screenRight - 40));
    });
  });

  group('on a small phone with large text', () {
    setUp(signIn);

    testWidgets('fits at the narrowest width with the text at twice its size, in either language, all the way down',
        (WidgetTester tester) async {
      for (final Locale locale in <Locale>[PlatformAdminHarness.english, PlatformAdminHarness.arabic]) {
        await pumpOverview(tester, locale: locale, textScale: 2.0, size: PlatformAdminHarness.narrowPhone);

        expect(tester.takeException(), isNull, reason: locale.languageCode);
        for (int step = 0; step < 14; step++) {
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${locale.languageCode} after scrolling $step times');
        }
      }
    });

    testWidgets('and with a market that has every kind of figure and the longest status names',
        (WidgetTester tester) async {
      service.onOverview = (String market, int? windowDays) async => PlatformAdminResult<PlatformOverviewModel>.success(
          PlatformOverviewModel.fromJson(fixtureData('overview_owner_unknown_status')));
      await pumpOverview(tester, textScale: 2.0, size: PlatformAdminHarness.narrowPhone);

      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the screen only draws what the controller holds', () {
    setUp(signIn);

    testWidgets(
        'showing the overview asks for nothing: the home asks, and the sessions are not the overview\'s business',
        (WidgetTester tester) async {
      await controller.loadOverview();
      service.calls.clear();
      PlatformAdminHarness.useScreen(tester, PlatformAdminHarness.phone);
      await tester.pumpWidget(await PlatformAdminHarness.app(tester,
          home: const Scaffold(body: PlatformAdminOverviewScreen()), controller: controller));
      await tester.pump();

      expect(service.calls, isEmpty, reason: 'the screen draws what the controller holds; the home asks');
      expect(controller.sessions, isNull);
    });
  });
}
