import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';

void main() {
  group('MarketScope', () {
    test('lists the six GCC markets with their own currencies', () {
      final Map<String?, String?> currencyByCountry = <String?, String?>{
        for (final MarketScope scope in MarketScope.gccMarkets) scope.countryCode: scope.currencyCode,
      };

      expect(currencyByCountry, <String, String>{
        'SA': 'SAR',
        'AE': 'AED',
        'KW': 'KWD',
        'QA': 'QAR',
        'BH': 'BHD',
        'OM': 'OMR',
      });
    });

    test('offers All Markets alongside the six GCC markets', () {
      expect(MarketScope.values, hasLength(7));
      expect(MarketScope.values, contains(MarketScope.allMarkets));
      expect(MarketScope.gccMarkets, isNot(contains(MarketScope.allMarkets)));
    });

    test('defaults to Saudi Arabia', () {
      expect(MarketScope.defaultScope, MarketScope.saudiArabia);
      expect(MarketScope.defaultScope.countryCode, 'SA');
      expect(MarketScope.defaultScope.currencyCode, 'SAR');
    });

    test('All Markets has no country code and no currency, so amounts are never summed into one', () {
      expect(MarketScope.allMarkets.countryCode, isNull);
      expect(MarketScope.allMarkets.currencyCode, isNull);

      final Set<String?> currencies = MarketScope.gccMarkets.map((MarketScope scope) => scope.currencyCode).toSet();
      expect(currencies, hasLength(MarketScope.gccMarkets.length));
    });

    test('fromCountryCode matches GCC codes only', () {
      expect(MarketScope.fromCountryCode('AE'), MarketScope.unitedArabEmirates);
      expect(MarketScope.fromCountryCode(' om '), MarketScope.oman);
      expect(MarketScope.fromCountryCode('US'), isNull);
      expect(MarketScope.fromCountryCode(''), isNull);
      expect(MarketScope.fromCountryCode(null), isNull);
      expect(MarketScope.fromCountryCode(MarketScope.allMarkets.name), isNull);
    });
  });
}
