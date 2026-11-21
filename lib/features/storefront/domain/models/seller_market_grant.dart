import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';

/// The markets the signed-in token carries, exactly as the server answers them (K-09).
///
/// The grant belongs to the seller or staff record on the server and is read from `allowed_markets` of
/// `GET api/v3/seller/seller-center/security/me`. The app does not decide it and cannot widen it: narrowing the picker to these
/// markets is a courtesy to the person using it, never the security boundary. The boundary is the server, which checks every
/// request against the same rows and answers 403 with no data for a market it does not hold — so an app build that offered a
/// market it was not granted would be refused rather than served.
///
/// `markets` is null when no grant exists, which is every seller while market scopes are off. Null is "no limit", and is never the
/// same thing as an empty list: a grant that names nothing reaches nothing.
class SellerMarketGrant {
  const SellerMarketGrant(this.markets);

  /// No grant: the seller works in every market the app offers, which is what the app has always done.
  const SellerMarketGrant.unrestricted() : markets = null;

  /// Reads the grant out of the `me` answer. Anything that is not a list of market codes is read as no grant, because a malformed
  /// answer must not quietly narrow a seller to nothing; a code the app does not know is dropped.
  factory SellerMarketGrant.fromPrincipal(Map<String, dynamic>? principal) {
    final Object? allowed = principal?['allowed_markets'];
    if (allowed is! List) {
      return const SellerMarketGrant.unrestricted();
    }

    final List<MarketScope> granted = <MarketScope>[];
    for (final Object? code in allowed) {
      final MarketScope? scope = MarketScope.fromCountryCode(code is String ? code : null);
      if (scope != null && !granted.contains(scope)) {
        granted.add(scope);
      }
    }

    return SellerMarketGrant(granted);
  }

  final List<MarketScope>? markets;

  bool get restricts => markets != null;

  bool allows(MarketScope scope) => markets == null || markets!.contains(scope);

  /// The markets of [offered] this grant holds, in the order they were offered. Everything while no grant exists.
  List<MarketScope> narrow(List<MarketScope> offered) {
    final List<MarketScope>? granted = markets;

    return granted == null ? offered : offered.where(granted.contains).toList();
  }
}
