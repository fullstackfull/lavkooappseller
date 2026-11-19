/// The market a seller is working in.
///
/// Each GCC market trades in its own currency, so amounts from different
/// markets are never added together. [allMarkets] is a viewing scope only: it
/// has no country code and no currency, and never selects a storefront.
enum MarketScope {
  allMarkets(countryCode: null, currencyCode: null, decimals: null),
  saudiArabia(countryCode: 'SA', currencyCode: 'SAR', decimals: 2),
  unitedArabEmirates(countryCode: 'AE', currencyCode: 'AED', decimals: 2),
  kuwait(countryCode: 'KW', currencyCode: 'KWD', decimals: 3),
  qatar(countryCode: 'QA', currencyCode: 'QAR', decimals: 2),
  bahrain(countryCode: 'BH', currencyCode: 'BHD', decimals: 3),
  oman(countryCode: 'OM', currencyCode: 'OMR', decimals: 3);

  const MarketScope({
    required this.countryCode,
    required this.currencyCode,
    required this.decimals,
  });

  final String? countryCode;
  final String? currencyCode;

  /// The digits after the decimal point that [currencyCode] is written with:
  /// three for the dinars and the rial of Kuwait, Bahrain and Oman, two for the
  /// others. Like the currency, it is null for All Markets.
  final int? decimals;

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
