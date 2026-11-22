import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// A seller works in one GCC market at a time while storefronts are on, and in no market while they are off.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> preferencesWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('while storefronts are off', () {
    test('the scope is All Markets whatever is stored', () async {
      final preferences =
          await preferencesWith({AppConstants.storefrontCountry: 'AE'});

      final choice = SellerMarketChoice(preferences, enabled: false);

      expect(choice.current(), MarketScope.allMarkets);
    });

    test('choosing a market writes nothing', () async {
      final preferences = await preferencesWith({});
      final choice = SellerMarketChoice(preferences, enabled: false);

      expect(await choice.choose(MarketScope.oman), isFalse);
      expect(preferences.containsKey(AppConstants.storefrontCountry), isFalse);
    });
  });

  group('while storefronts are on', () {
    test('nothing chosen yet works in Saudi Arabia', () async {
      final preferences = await preferencesWith({});

      final choice = SellerMarketChoice(preferences, enabled: true);

      expect(choice.current(), MarketScope.saudiArabia);
    });

    test('choosing a market saves it, and it survives a new instance',
        () async {
      final preferences = await preferencesWith({});

      final saved =
          await SellerMarketChoice(preferences, enabled: true).choose(
        MarketScope.kuwait,
      );
      final reopened = SellerMarketChoice(preferences, enabled: true);

      expect(saved, isTrue);
      expect(preferences.getString(AppConstants.storefrontCountry), 'KW');
      expect(reopened.current(), MarketScope.kuwait);
    });

    test('All Markets is refused and writes nothing', () async {
      final preferences = await preferencesWith({});
      final choice = SellerMarketChoice(preferences, enabled: true);

      expect(await choice.choose(MarketScope.allMarkets), isFalse);
      expect(preferences.containsKey(AppConstants.storefrontCountry), isFalse);
    });

    test('an unknown stored code falls back to Saudi Arabia', () async {
      final preferences =
          await preferencesWith({AppConstants.storefrontCountry: 'US'});

      final choice = SellerMarketChoice(preferences, enabled: true);

      expect(choice.current(), MarketScope.saudiArabia);
    });

    test('a stored value that is not text falls back to Saudi Arabia',
        () async {
      final preferences =
          await preferencesWith({AppConstants.storefrontCountry: 7});

      final choice = SellerMarketChoice(preferences, enabled: true);

      expect(choice.current(), MarketScope.saudiArabia);
    });
  });
}
