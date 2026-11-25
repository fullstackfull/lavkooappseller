import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// The push topics this device is subscribed to (K-11, K-V4).
///
/// The platform has had one seller maintenance topic since it had one market, and with six markets that is wrong in both directions: a
/// maintenance of Kuwait on the platform-wide topic tells every Saudi seller to stop working, and a seller who works in both is told the same
/// thing whichever market they are looking at. So a market has a topic of its own, and the device is subscribed to the one for the market it
/// is working in.
///
/// **The platform-wide topics stay.** They carry what is true of the whole platform, and dropping them would silence a message the server
/// still sends there. They are listed first and are the same list the app has always subscribed to, so a build on a server that knows nothing
/// of market topics behaves exactly as before.
///
/// The name is built the same way the server builds it ([StorefrontPushTopics] there): the platform topic with the market code appended. A
/// mismatch between the two is silent -- the message goes nowhere and nobody is told -- which is why both sides build it from one rule rather
/// than writing the string twice.
///
/// `switching` is what the app has to do when the seller changes market: unsubscribe what only the old market needed, subscribe what the new
/// one needs, and leave the platform-wide topics alone. Unsubscribing everything and resubscribing would briefly leave a device hearing
/// nothing, and a maintenance message sent in that window would be lost.
class SellerPushTopics {
  const SellerPushTopics._();

  /// The topics every seller's device is subscribed to whatever market they work in.
  static const List<String> platformWide = <String>[AppConstants.topic, AppConstants.maintenanceModeTopic];

  /// The maintenance topic of one market, or null while storefronts are off or the scope names no market (All Markets).
  static String? maintenanceOf(MarketScope? scope, {bool storefrontsEnabled = StorefrontConfig.enabled}) {
    final String? code = scope?.countryCode;

    return !storefrontsEnabled || code == null ? null : '${AppConstants.maintenanceModeTopic}_$code';
  }

  /// Every topic a device working in [scope] should be subscribed to, platform-wide ones first.
  static List<String> forMarket(MarketScope? scope, {bool storefrontsEnabled = StorefrontConfig.enabled}) {
    final String? market = maintenanceOf(scope, storefrontsEnabled: storefrontsEnabled);

    return <String>[...platformWide, if (market != null) market];
  }

  /// What a change of market means for the subscriptions: what to leave, and what to take up.
  ///
  /// The platform-wide topics are in neither list, because they are not the market's to drop. A move to or from All Markets, and every move
  /// while storefronts are off, leaves the subscriptions exactly as they are.
  static TopicChange switching({
    required MarketScope? from,
    required MarketScope? to,
    bool storefrontsEnabled = StorefrontConfig.enabled,
  }) {
    final String? leaving = maintenanceOf(from, storefrontsEnabled: storefrontsEnabled);
    final String? joining = maintenanceOf(to, storefrontsEnabled: storefrontsEnabled);

    if (leaving == joining) {
      return const TopicChange();
    }

    return TopicChange(
      unsubscribe: <String>[if (leaving != null) leaving],
      subscribe: <String>[if (joining != null) joining],
    );
  }
}

/// The topics to leave and the topics to take up, for one change of market.
class TopicChange {
  const TopicChange({this.unsubscribe = const <String>[], this.subscribe = const <String>[]});

  final List<String> unsubscribe;
  final List<String> subscribe;

  bool get isEmpty => unsubscribe.isEmpty && subscribe.isEmpty;
}
