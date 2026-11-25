import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/seller_market_grant.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';

/// What a push notification's market means for the app that is about to open it (K-11).
enum MarketVerdict {
  /// Open the screen in the market the app is already working in. Nothing to switch: storefronts are off, the push names no market, or it
  /// names the one in force.
  openHere,

  /// Switch to the push's market first, then open. Where [NotificationMarketDecision.market] is the market to switch to.
  switchFirst,

  /// Open nothing. The push belongs to a market this seller is not granted, so the screen would ask the server with a header it may not use.
  notGranted,
}

/// A verdict and, where there is one, the market it is about.
class NotificationMarketDecision {
  const NotificationMarketDecision(this.verdict, [this.market]);

  final MarketVerdict verdict;

  /// The market to switch to, set only for [MarketVerdict.switchFirst].
  final MarketScope? market;

  bool get mustSwitch => verdict == MarketVerdict.switchFirst;

  bool get mayOpen => verdict != MarketVerdict.notGranted;
}

/// Which market a push notification opens in, and whether the app has to switch to it first (K-11).
///
/// The server now names the market of the order a push is about. Without that the app had to guess, and the guess it made was the market the
/// seller happened to be looking at: a tap on a Kuwaiti order opened the Kuwaiti order id under a Saudi header, and the server answered that
/// no such order exists -- correctly, because in Saudi Arabia it does not.
///
/// Four answers, and three of them are deliberately "do nothing":
///
///  - storefronts off: there is no market to switch to, and every push opens exactly as it always did.
///  - the push names NO market: an older server, or a push about something that is not an order. The app must not switch on no information;
///    it opens where it is, which is what it did before this existed.
///  - the push names the market already in force: nothing to do.
///  - the push names a market the seller is NOT granted: nothing is opened. Switching would set a header the server refuses, and opening
///    without switching would ask for another market's order under this market's header; both end in a refusal the seller cannot act on, and
///    one of them would silently show them the wrong market's screen. The grant is a courtesy here as everywhere -- the server is the
///    boundary -- but obeying it is how the app avoids walking into a 403 it could see coming.
///
/// A market the app does not know (a code from a newer server, a typo) is the same as naming none: it is not a market this build can switch
/// to, so it opens where it is rather than refusing a notification it simply cannot place.
class NotificationMarket {
  const NotificationMarket._();

  static NotificationMarketDecision decide(
    NotificationBody? payload, {
    // Defaults to the build flag so no caller in the app states it: a screen or a handler that says whether storefronts are on is a
    // second answer to a question the build already answers (the market source rule forbids it). A test names it to drive both ways.
    bool storefrontsEnabled = StorefrontConfig.enabled,
    required MarketScope current,
    required SellerMarketGrant grant,
  }) {
    if (!storefrontsEnabled) {
      return const NotificationMarketDecision(MarketVerdict.openHere);
    }

    final MarketScope? named = MarketScope.fromCountryCode(payload?.storefront);

    if (named == null || named == current) {
      return const NotificationMarketDecision(MarketVerdict.openHere);
    }

    if (!grant.allows(named)) {
      return const NotificationMarketDecision(MarketVerdict.notGranted);
    }

    return NotificationMarketDecision(MarketVerdict.switchFirst, named);
  }
}
