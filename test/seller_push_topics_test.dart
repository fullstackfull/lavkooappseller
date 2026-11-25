import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/notification/seller_push_topics.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// K-11 and K-V4: a seller's device is subscribed to the maintenance topic of the market it is working in, as well as to the platform-wide
/// ones.
///
/// The platform has had one seller maintenance topic since it had one market. With six markets that is wrong in both directions: a
/// maintenance of Kuwait on the platform-wide topic tells every Saudi seller to stop working, and a seller who works in both is told the same
/// thing whichever market they are looking at.
///
/// The first test is the one that protects what exists: with storefronts off the list is exactly the list the app has always subscribed to.
///
/// The server builds the same name from its own rule (`StorefrontPushTopics`). A mismatch between the two is SILENT -- the message goes
/// nowhere and nobody is told -- so the name is pinned here in full rather than built from the same expression the code uses.
void main() {
  group('the topics of a market', () {
    test('with storefronts off the list is the one the app has always subscribed to', () {
      expect(
        SellerPushTopics.forMarket(MarketScope.kuwait, storefrontsEnabled: false),
        <String>[AppConstants.topic, AppConstants.maintenanceModeTopic],
      );
      expect(SellerPushTopics.maintenanceOf(MarketScope.kuwait, storefrontsEnabled: false), isNull);
    });

    test('a market adds its own maintenance topic and keeps the platform-wide ones', () {
      expect(
        SellerPushTopics.forMarket(MarketScope.kuwait, storefrontsEnabled: true),
        <String>['lavkoo_seller', 'maintenance_mode_start_vendor', 'maintenance_mode_start_vendor_KW'],
        reason: 'the platform-wide topics still carry what is true of the whole platform',
      );
    });

    test('the market topic is the platform topic with the market code appended', () {
      expect(SellerPushTopics.maintenanceOf(MarketScope.kuwait, storefrontsEnabled: true), 'maintenance_mode_start_vendor_KW');
      expect(SellerPushTopics.maintenanceOf(MarketScope.bahrain, storefrontsEnabled: true), 'maintenance_mode_start_vendor_BH');
    });

    test('All Markets names no market, so it adds nothing', () {
      expect(SellerPushTopics.maintenanceOf(MarketScope.allMarkets, storefrontsEnabled: true), isNull);
      expect(
        SellerPushTopics.forMarket(MarketScope.allMarkets, storefrontsEnabled: true),
        <String>[AppConstants.topic, AppConstants.maintenanceModeTopic],
      );
      expect(SellerPushTopics.maintenanceOf(null, storefrontsEnabled: true), isNull);
    });
  });

  group('changing market', () {
    test('leaves the old market and takes up the new one, and touches nothing else', () {
      final TopicChange change = SellerPushTopics.switching(
        from: MarketScope.saudiArabia,
        to: MarketScope.kuwait,
        storefrontsEnabled: true,
      );

      expect(change.unsubscribe, <String>['maintenance_mode_start_vendor_SA']);
      expect(change.subscribe, <String>['maintenance_mode_start_vendor_KW']);
      expect(
        change.unsubscribe,
        isNot(contains(AppConstants.maintenanceModeTopic)),
        reason: 'the platform-wide topic is not the market\'s to drop',
      );
      expect(change.unsubscribe, isNot(contains(AppConstants.topic)));
    });

    test('a change to the same market changes nothing', () {
      expect(
        SellerPushTopics.switching(from: MarketScope.kuwait, to: MarketScope.kuwait, storefrontsEnabled: true).isEmpty,
        isTrue,
      );
    });

    test('with storefronts off a change of market changes no subscription', () {
      expect(
        SellerPushTopics.switching(from: MarketScope.saudiArabia, to: MarketScope.kuwait, storefrontsEnabled: false).isEmpty,
        isTrue,
      );
    });

    test('a move from or to All Markets only takes up or leaves the one market', () {
      final TopicChange intoAMarket = SellerPushTopics.switching(
        from: MarketScope.allMarkets,
        to: MarketScope.kuwait,
        storefrontsEnabled: true,
      );
      expect(intoAMarket.unsubscribe, isEmpty, reason: 'there was no market topic to leave');
      expect(intoAMarket.subscribe, <String>['maintenance_mode_start_vendor_KW']);

      final TopicChange outOfAMarket = SellerPushTopics.switching(
        from: MarketScope.kuwait,
        to: MarketScope.allMarkets,
        storefrontsEnabled: true,
      );
      expect(outOfAMarket.unsubscribe, <String>['maintenance_mode_start_vendor_KW']);
      expect(outOfAMarket.subscribe, isEmpty);
    });

    test('a first sign-in with no previous market takes up the new market only', () {
      final TopicChange change = SellerPushTopics.switching(from: null, to: MarketScope.bahrain, storefrontsEnabled: true);

      expect(change.unsubscribe, isEmpty);
      expect(change.subscribe, <String>['maintenance_mode_start_vendor_BH']);
    });
  });
}
