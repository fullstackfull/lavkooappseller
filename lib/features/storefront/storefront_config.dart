import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';

class StorefrontConfig {
  /// Off unless the build is made with
  /// `--dart-define=GCC_STOREFRONTS_ENABLED=true`, so existing builds send
  /// exactly the requests they always have.
  static const bool enabled = bool.fromEnvironment('GCC_STOREFRONTS_ENABLED', defaultValue: false);

  /// The storefront header value for the seller's stored market choice.
  ///
  /// A missing, unknown or All Markets choice falls back to the default market,
  /// because a request always targets exactly one storefront.
  static String resolveHeaderValue(String? storedCountryCode) {
    final MarketScope scope = MarketScope.fromCountryCode(storedCountryCode) ?? MarketScope.defaultScope;
    return scope.countryCode!;
  }
}
