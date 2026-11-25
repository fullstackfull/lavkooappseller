import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/storefront_pause.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/paused_market_notice.dart';

import 'market_selector/support/harness.dart';
import 'market_selector/support/market_support.dart';

/// K-V4: a paused market, and the seller being told WHICH market it is.
///
/// The platform has had one maintenance switch since it had one market, and the maintenance screen of this app had no market in it at all. A
/// seller who works in Kuwait and in Saudi Arabia saw the same screen whichever of them had been stopped, and could not tell which.
///
/// The first tests are the ones that protect what exists: an answer with no per-market block, and a platform whose markets are all selling,
/// read as no markets stopped, and the notice draws nothing -- so the screen a single-market platform shows is byte for byte what it was.
void main() {
  Map<String, dynamic> pauseOf(String country, {String? message, String? mode = 'maintenance', String state = 'paused'}) => <String, dynamic>{
        'country': country,
        'state': state,
        'mode': mode,
        'message': message,
        'until': null,
      };

  group('reading what the server sent', () {
    test('an answer with no block at all is no markets stopped', () {
      expect(StorefrontPause.mapFromJson(null), isEmpty);
      expect(StorefrontPause.mapFromJson(<String, dynamic>{}), isEmpty);
    });

    test('an answer this build cannot read is no markets stopped, and never an exception', () {
      expect(StorefrontPause.mapFromJson('paused'), isEmpty);
      expect(StorefrontPause.mapFromJson(<String, dynamic>{'KW': 'paused'}), isEmpty);
      expect(StorefrontPause.mapFromJson(<String, dynamic>{'KW': <String, dynamic>{'state': 'paused'}}), isEmpty, reason: 'an entry with no country names no market');
    });

    test('a stopped market is read with its mode, its message and its country in one case', () {
      final Map<String, StorefrontPause> stopped = StorefrontPause.mapFromJson(<String, dynamic>{
        'kw': pauseOf(' kw ', message: 'Back on Sunday'),
      });

      expect(stopped.keys, <String>['KW']);
      expect(stopped['KW']!.state, 'paused');
      expect(stopped['KW']!.mode, 'maintenance');
      expect(stopped['KW']!.message, 'Back on Sunday');
      expect(stopped['KW']!.until, isNull);
    });

    test('a message the operator did not write is null and not an empty line', () {
      expect(StorefrontPause.mapFromJson(<String, dynamic>{'KW': pauseOf('KW', message: '   ')})['KW']!.message, isNull);
      expect(StorefrontPause.mapFromJson(<String, dynamic>{'KW': pauseOf('KW', mode: null)})['KW']!.mode, isNull);
    });
  });

  group('the market the seller is working in', () {
    final Map<String, StorefrontPause> stopped = StorefrontPause.mapFromJson(<String, dynamic>{'KW': pauseOf('KW')});

    test('is found when it is the one that stopped', () {
      expect(stopped.ofMarket(MarketScope.kuwait)?.country, 'KW');
    });

    test('is not found when that market is selling', () {
      expect(stopped.ofMarket(MarketScope.saudiArabia), isNull);
    });

    test('All Markets is no one market, so it can never be the one that stopped', () {
      expect(stopped.ofMarket(MarketScope.allMarkets), isNull);
      expect(stopped.ofMarket(null), isNull);
    });
  });

  group('what the seller is shown', () {
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferences = await SharedPreferences.getInstance();
    });

    Future<void> show(WidgetTester tester, {required Map<String, StorefrontPause> stopped, required MarketScope market}) async {
      final SellerMarketController controller = controllerOn(preferences);
      await controller.choose(market);

      await tester.pumpWidget(await MarketHarness.app(
        tester,
        home: Scaffold(body: Center(child: PausedMarketNotice(marketController: controller, pauses: stopped))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('nothing at all when no market is stopped', (WidgetTester tester) async {
      await show(tester, stopped: const <String, StorefrontPause>{}, market: MarketScope.kuwait);

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('nothing when the market the seller works in is selling', (WidgetTester tester) async {
      await show(tester, stopped: StorefrontPause.mapFromJson(<String, dynamic>{'KW': pauseOf('KW')}), market: MarketScope.saudiArabia);

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('the market by name when it is the one that stopped', (WidgetTester tester) async {
      await show(tester, stopped: StorefrontPause.mapFromJson(<String, dynamic>{'KW': pauseOf('KW')}), market: MarketScope.kuwait);

      expect(find.textContaining('Kuwait'), findsOneWidget);
    });

    testWidgets('and the operator\'s own words about it, when they wrote any', (WidgetTester tester) async {
      await show(
        tester,
        stopped: StorefrontPause.mapFromJson(<String, dynamic>{'KW': pauseOf('KW', message: 'Back on Sunday')}),
        market: MarketScope.kuwait,
      );

      expect(find.text('Back on Sunday'), findsOneWidget);
    });

    testWidgets('a market this build does not know is still said to be paused, without a name it cannot give', (WidgetTester tester) async {
      await show(tester, stopped: StorefrontPause.mapFromJson(<String, dynamic>{'ZZ': pauseOf('ZZ')}), market: MarketScope.kuwait);

      expect(find.byType(Text), findsNothing, reason: 'it is not the market the seller works in, so there is nothing to say');
    });
  });
}
