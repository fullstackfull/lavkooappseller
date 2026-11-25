import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/seller_market_grant.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';
import 'package:syriacosmeticsmanger/notification/notification_market.dart';

/// K-11: a push notification says which market its order was sold in, and the app opens that market rather than the one it happens to be
/// showing.
///
/// Without this the app guessed, and the guess it made was the market the seller was looking at: a tap on a Kuwaiti order asked the server
/// for that order id under a Saudi header, and the server answered that no such order exists -- correctly, because in Saudi Arabia it does
/// not. The seller saw an error on a notification about a real order of theirs.
///
/// Three of the four answers are deliberately "do nothing", and they are what the first tests here pin: with storefronts off, with no market
/// in the push, and with the market already in force, every push opens exactly as it did before any of this existed.
void main() {
  NotificationBody pushFrom(String? market) => NotificationBody.fromJson(<String, dynamic>{
        'order_id': '4242',
        'type': 'order',
        if (market != null) 'storefront': market,
      });

  NotificationMarketDecision decide(
    NotificationBody? payload, {
    bool storefrontsEnabled = true,
    MarketScope current = MarketScope.saudiArabia,
    SellerMarketGrant grant = const SellerMarketGrant.unrestricted(),
  }) =>
      NotificationMarket.decide(payload, storefrontsEnabled: storefrontsEnabled, current: current, grant: grant);

  group('reading the market out of a push', () {
    test('the market the server named is read, upper-cased and trimmed', () {
      expect(pushFrom('KW').storefront, 'KW');
      expect(pushFrom(' kw ').storefront, 'KW', reason: 'a market is compared in one case everywhere');
      expect(pushFrom(null).storefront, isNull);
      expect(pushFrom('').storefront, isNull, reason: 'an empty string is not a market');
    });

    test('the rest of the payload is read exactly as before', () {
      final NotificationBody push = pushFrom('KW');

      expect(push.orderId, 4242);
      expect(push.type, 'order');
    });
  });

  group('what the app does about it', () {
    test('with storefronts off every push opens where it is', () {
      expect(
        decide(pushFrom('KW'), storefrontsEnabled: false).verdict,
        MarketVerdict.openHere,
        reason: 'there is no market to switch to, so nothing changes',
      );
    });

    test('a push that names no market opens where it is', () {
      expect(
        decide(pushFrom(null)).verdict,
        MarketVerdict.openHere,
        reason: 'an older server, or a push about something that is not an order: the app must not switch on no information',
      );
      expect(decide(null).verdict, MarketVerdict.openHere, reason: 'and neither must a message with no data at all');
    });

    test('a push of the market already in force opens where it is', () {
      expect(decide(pushFrom('SA'), current: MarketScope.saudiArabia).verdict, MarketVerdict.openHere);
    });

    test('a push of another market switches to it first', () {
      final NotificationMarketDecision decision = decide(pushFrom('KW'), current: MarketScope.saudiArabia);

      expect(decision.verdict, MarketVerdict.switchFirst);
      expect(decision.market, MarketScope.kuwait);
      expect(decision.mustSwitch, isTrue);
      expect(decision.mayOpen, isTrue);
    });

    test('a push of a market the seller is not granted opens nothing', () {
      final NotificationMarketDecision decision = decide(
        pushFrom('KW'),
        current: MarketScope.saudiArabia,
        grant: const SellerMarketGrant(<MarketScope>[MarketScope.saudiArabia]),
      );

      expect(decision.verdict, MarketVerdict.notGranted);
      expect(decision.mayOpen, isFalse, reason: 'switching would set a header the server refuses, and not switching would ask the wrong market');
      expect(decision.market, isNull);
    });

    test('a grant that holds the market switches to it', () {
      expect(
        decide(
          pushFrom('KW'),
          current: MarketScope.saudiArabia,
          grant: const SellerMarketGrant(<MarketScope>[MarketScope.saudiArabia, MarketScope.kuwait]),
        ).market,
        MarketScope.kuwait,
      );
    });

    test('a market this build does not know is read as naming none', () {
      expect(
        decide(pushFrom('ZZ'), current: MarketScope.saudiArabia).verdict,
        MarketVerdict.openHere,
        reason: 'it is not a market this build can switch to, so it opens where it is rather than refusing a notification it cannot place',
      );
    });

    test('the grant is asked about the market in the PUSH and not the one in force', () {
      // A seller granted Kuwait alone, looking at Kuwait, tapping a Saudi order: the push is refused, not the market they are in.
      expect(
        decide(
          pushFrom('SA'),
          current: MarketScope.kuwait,
          grant: const SellerMarketGrant(<MarketScope>[MarketScope.kuwait]),
        ).verdict,
        MarketVerdict.notGranted,
      );
    });
  });
}
