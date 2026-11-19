import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/market_support.dart';

/// The headers that name a storefront are read from the saved choice each time they are asked for, so the market a seller moves to is
/// the market the next request names.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('while storefronts are on', () {
    test('nothing chosen yet names Saudi Arabia', () async {
      final SellerMarketChoice choice = SellerMarketChoice(await preferencesWith(), enabled: true);

      expect(choice.requestHeaders(), <String, String>{AppConstants.storefrontHeader: 'SA'});
    });

    test('names the market chosen, for each of the six, the moment it is chosen', () async {
      final SellerMarketChoice choice = SellerMarketChoice(await preferencesWith(), enabled: true);

      for (final MarketScope scope in MarketScope.gccMarkets) {
        await choice.choose(scope);

        expect(choice.requestHeaders(), <String, String>{AppConstants.storefrontHeader: scope.countryCode!});
      }
    });

    test('names a stored code in capitals whatever way it was written', () async {
      final SellerMarketChoice choice = SellerMarketChoice(
        await preferencesWith(<String, Object>{AppConstants.storefrontCountry: ' kw '}),
        enabled: true,
      );

      expect(choice.requestHeaders(), <String, String>{AppConstants.storefrontHeader: 'KW'});
    });

    test('names Saudi Arabia for a stored value that is no market, and for one that is not even text', () async {
      for (final Object stored in <Object>['US', 'allMarkets', '', 7]) {
        final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: stored});

        expect(
          SellerMarketChoice(preferences, enabled: true).requestHeaders(),
          <String, String>{AppConstants.storefrontHeader: 'SA'},
          reason: '$stored',
        );
      }
    });

    test('hands out a map of its own each time, so a caller that adds to it changes nothing for the next', () async {
      final SellerMarketChoice choice = SellerMarketChoice(await preferencesWith(), enabled: true);

      choice.requestHeaders()['Authorization'] = 'Bearer something';

      expect(choice.requestHeaders(), <String, String>{AppConstants.storefrontHeader: 'SA'});
    });
  });

  group('while storefronts are off', () {
    test('names no storefront, whatever market is stored', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});

      expect(SellerMarketChoice(preferences, enabled: false).requestHeaders(), isEmpty);
    });
  });
}
