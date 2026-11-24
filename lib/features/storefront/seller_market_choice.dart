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

    return MarketScope.fromCountryCode(_storedCountryCode()) ??
        MarketScope.fromCountryCode(_storedDefaultCountryCode()) ??
        MarketScope.defaultScope;
  }

  /// Remembers the market the server says the platform serves whoever has chosen none, so that moving the default moves a seller who
  /// has chosen nothing (A1-03). An answer that names no market, or one this build does not know, forgets what was remembered rather
  /// than keeping an answer the server has withdrawn. Nothing is written while storefronts are off.
  Future<bool> rememberPlatformDefault(MarketScope? scope) {
    final String? countryCode = scope?.countryCode;
    if (!enabled) {
      return Future<bool>.value(false);
    }

    return countryCode == null
        ? _preferences.remove(AppConstants.storefrontDefaultCountry)
        : _preferences.setString(AppConstants.storefrontDefaultCountry, countryCode);
  }

  /// The headers that name the storefront a request is for, read when they are asked for: the market the seller works in now, and
  /// none while storefronts are off.
  ///
  /// It names what [current] answers, so a request can never target a different market from the one the screens are showing — which it
  /// would the moment the market a seller works in comes from the server's default rather than from their own choice (A1-03).
  Map<String, String> requestHeaders() => <String, String>{
        if (enabled)
          AppConstants.storefrontHeader:
              current().countryCode ?? StorefrontConfig.resolveHeaderValue(_storedCountryCode()),
      };

  /// The storefront a request sent now names, which is also the market a sale queued now was taken in; none while storefronts are off.
  String? storefrontCode() => requestHeaders()[AppConstants.storefrontHeader];

  /// Saves [scope] as the market to work in. All Markets is not a market a request can target, so it is refused.
  Future<bool> choose(MarketScope scope) {
    final String? countryCode = scope.countryCode;
    if (!enabled || countryCode == null) {
      return Future<bool>.value(false);
    }

    return _preferences.setString(AppConstants.storefrontCountry, countryCode);
  }

  String? _storedCountryCode() {
    final Object? stored = _preferences.get(AppConstants.storefrontCountry);
    return stored is String ? stored : null;
  }

  String? _storedDefaultCountryCode() {
    final Object? stored = _preferences.get(AppConstants.storefrontDefaultCountry);
    return stored is String ? stored : null;
  }
}
