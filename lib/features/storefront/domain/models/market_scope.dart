/// The market a seller is working in.
///
/// Each GCC market trades in its own currency, so amounts from different
/// markets are never added together. [allMarkets] is a viewing scope only: it
/// has no country code and no currency, and never selects a storefront.
enum MarketScope {
  allMarkets(countryCode: null, currencyCode: null),
  saudiArabia(countryCode: 'SA', currencyCode: 'SAR'),
  unitedArabEmirates(countryCode: 'AE', currencyCode: 'AED'),
  kuwait(countryCode: 'KW', currencyCode: 'KWD'),
  qatar(countryCode: 'QA', currencyCode: 'QAR'),
  bahrain(countryCode: 'BH', currencyCode: 'BHD'),
  oman(countryCode: 'OM', currencyCode: 'OMR');

  const MarketScope({required this.countryCode, required this.currencyCode});

  final String? countryCode;
  final String? currencyCode;

  static const MarketScope defaultScope = MarketScope.saudiArabia;

  static List<MarketScope> get gccMarkets =>
      values.where((MarketScope scope) => scope.countryCode != null).toList();

  /// The GCC market for [code], or null when [code] is missing or names no
  /// GCC market.
  static MarketScope? fromCountryCode(String? code) {
    final String normalized = (code ?? '').trim().toUpperCase();
    for (final MarketScope scope in gccMarkets) {
      if (scope.countryCode == normalized) {
        return scope;
      }
    }
    return null;
  }
}
