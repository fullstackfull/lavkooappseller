import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// The GCC market a seller works in. While storefronts are off there is no market to choose: every read answers All Markets and
/// nothing is written. While they are on, a seller works in one market at a time, because a request always targets one storefront.
class SellerMarketChoice {
  const SellerMarketChoice(
    this._preferences, {
    this.enabled = StorefrontConfig.enabled,
  });

  final SharedPreferences _preferences;
  final bool enabled;

  MarketScope current() {
    if (!enabled) {
      return MarketScope.allMarkets;
    }

    final Object? stored = _preferences.get(AppConstants.storefrontCountry);
    return MarketScope.fromCountryCode(stored is String ? stored : null) ??
        MarketScope.defaultScope;
  }

  /// Saves [scope] as the market to work in. All Markets is not a market a request can target, so it is refused.
  Future<bool> choose(MarketScope scope) {
    final String? countryCode = scope.countryCode;
    if (!enabled || countryCode == null) {
      return Future<bool>.value(false);
    }

    return _preferences.setString(AppConstants.storefrontCountry, countryCode);
  }
}
