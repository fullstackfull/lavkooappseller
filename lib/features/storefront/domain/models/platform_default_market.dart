import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';

/// What the server said about the market the platform serves whoever has chosen none (A1-03).
///
/// Two different silences, which the app must not confuse. **No answer** is a request that failed, a route the server does not know, or
/// a body that is not an answer at all: the app learns nothing and keeps the market it had. **An answer naming no market** is the
/// server saying there is no recorded default — because none was ever recorded, or because it was withdrawn — and what the app
/// remembered is then forgotten, so a withdrawn default stops moving sellers.
class PlatformDefaultMarket {
  /// The server answered. [market] is the market it named, or null when its answer named none this build can serve.
  const PlatformDefaultMarket.answered(this.market) : answered = true;

  /// The server said nothing that can be read.
  const PlatformDefaultMarket.noAnswer()
      : market = null,
        answered = false;

  final MarketScope? market;

  final bool answered;
}
