import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_health_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_health_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_state_widgets.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_health_card.dart';

import 'support/fake_service.dart';
import 'support/harness.dart';

/// Operational health, as the platform owner meets it (L-09).
///
/// What is pinned here is what a monitor must never get wrong: a market's rows
/// are its own, the rows whose market is not recorded are shown apart and said
/// to be apart, and the sentence under a figure is the server's and not the
/// app's.
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

  Future<void> pumpHealth(
    WidgetTester tester, {
    Locale locale = PlatformAdminHarness.english,
    Size size = PlatformAdminHarness.tallPhone,
    bool loaded = true,
  }) async {
    if (loaded) await controller.loadHealth();
    service.calls.clear();
    PlatformAdminHarness.useScreen(tester, size);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      home: const Scaffold(body: PlatformAdminHealthScreen()),
      controller: controller,
      locale: locale,
    ));
    await tester.pump();
  }

  List<PlatformHealthCard> cards(WidgetTester tester) =>
      tester.widgetList<PlatformHealthCard>(find.byType(PlatformHealthCard)).toList();

  Finder card(String? market) => find.byWidgetPredicate(
        (Widget widget) => widget is PlatformHealthCard && widget.health.market == market,
      );

  Finder inCard(String? market, Finder what) => find.descendant(of: card(market), matching: what);

  group('the platform owner', () {
    setUp(signIn);

    testWidgets('sees a card per market and the unattributed rows last', (WidgetTester tester) async {
      await pumpHealth(tester);

      expect(
        cards(tester).map((PlatformHealthCard card) => card.health.market).toList(),
        <String?>['SA', 'KW', null],
        reason: 'the markets in the order the server sent them, and what it could not attribute after them',
      );
      expect(inCard(null, find.text('Market not recorded')), findsOneWidget);
    });

    testWidgets('sees each market\'s own figures and nothing added across them', (WidgetTester tester) async {
      await pumpHealth(tester);

      final PlatformHealthCard saudi = tester.widget<PlatformHealthCard>(card('SA'));
      final PlatformHealthCard kuwait = tester.widget<PlatformHealthCard>(card('KW'));

      expect(saudi.health.payments.stuckAttempts, 2);
      expect(kuwait.health.payments.stuckAttempts, 0);
      expect(saudi.health.payments.reconciliationBreaks, 2, reason: 'a backlog of its own, counted apart from the attempts');
      expect(kuwait.health.payments.reconciliationBreaks, 0);
      expect(saudi.health.channels.failingResources, 1);
      expect(kuwait.health.channels.lateResources, 1);
      expect(saudi.health.carriers.failingCapabilities, 1);
      expect(kuwait.health.carriers.connections, 0);
      expect(saudi.health.issues.openShopIssues, 3, reason: 'the shops of that market that are out of policy');
      expect(saudi.health.issues.pendingApprovals, 1);
      expect(kuwait.health.issues.openShopIssues, 0, reason: 'a market with nothing open reads zero, not nothing');
    });

    testWidgets('a market with issues open and payments fine is still marked as needing attention', (WidgetTester tester) async {
      await pumpHealth(tester);

      final PlatformHealthCard kuwait = tester.widget<PlatformHealthCard>(card('KW'));

      expect(kuwait.health.needsAttention, isTrue, reason: 'its channel resource is late');
      expect(
        const PlatformMarketHealth(
          payments: PlatformPaymentHealth(),
          channels: PlatformChannelHealth(),
          carriers: PlatformCarrierHealth(),
          issues: PlatformIssueHealth(openShopIssues: 1),
          market: 'BH',
        ).needsAttention,
        isTrue,
        reason: 'issues alone are enough: a market whose shops are out of policy is not a market with nothing on it',
      );
    });

    testWidgets('the screen says the issue figures are a backlog and that staff issues are not recorded', (WidgetTester tester) async {
      await pumpHealth(tester);

      expect(inCard('SA', find.textContaining('A BACKLOG and not a window')), findsWidgets);
      expect(
        inCard('SA', find.textContaining('keeps no record of either')),
        findsOneWidget,
        reason: 'staff issues and escalations are not sent, and the screen passes on the server\'s reason rather than drawing a zero',
      );
    });

    testWidgets('is told what a figure means in the words of the server that counted it', (WidgetTester tester) async {
      await pumpHealth(tester);

      expect(
        inCard('SA', find.textContaining('closed the tab')),
        findsOneWidget,
        reason: 'a stuck attempt is not a failure, and the screen must say so rather than imply one',
      );
      expect(
        inCard('SA', find.textContaining('different test from the channels')),
        findsOneWidget,
        reason: 'the carrier figure is not made the way the channel figure is',
      );
      expect(inCard(null, find.textContaining('never counted as the default market')), findsOneWidget);
      expect(
        inCard('SA', find.textContaining('does not fall when the window moves')),
        findsOneWidget,
        reason: 'the reconciliation figure is a backlog, and the screen says so in the server\'s words',
      );
    });

    testWidgets('a market with nothing wrong reads zero rather than nothing at all', (WidgetTester tester) async {
      await pumpHealth(tester);

      expect(inCard('KW', find.text('0')), findsWidgets);
    });

    testWidgets('asks the server again when the market in view changes', (WidgetTester tester) async {
      await pumpHealth(tester);

      controller.selectMarket('KW');
      await controller.loadHealth();

      expect(service.calls.where((String call) => call.startsWith('health')).toList(), <String>['health KW null']);
      await tester.pump();
      expect(
        cards(tester).map((PlatformHealthCard card) => card.health.market).toList(),
        <String?>['KW'],
        reason: 'one market asked for is one market shown, with no unattributed row',
      );
    });

    testWidgets('shows the loader until the first answer comes', (WidgetTester tester) async {
      await pumpHealth(tester, loaded: false);

      expect(find.byType(PlatformHealthCard), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('a refusal is shown instead of an empty screen, with a way to try again',
        (WidgetTester tester) async {
      service.onHealth = (String market, int? windowDays) async =>
          const PlatformAdminResult<PlatformHealthModel>.failure(PlatformAdminFailure.network());
      await pumpHealth(tester);

      expect(find.byType(PlatformHealthCard), findsNothing);
      expect(find.byType(PlatformAdminFailureView), findsOneWidget);
      expect(find.byType(ElevatedButton), findsWidgets, reason: 'the failure view offers a retry');
    });
  });

  group('in Arabic', () {
    setUp(signIn);

    testWidgets('the market names and the labels are translated', (WidgetTester tester) async {
      await pumpHealth(tester, locale: PlatformAdminHarness.arabic);

      expect(inCard('SA', find.text('السعودية')), findsOneWidget);
      expect(find.text('قنوات البيع'), findsWidgets);
      expect(find.text('شركات الشحن'), findsWidgets);
    });
  });
}
