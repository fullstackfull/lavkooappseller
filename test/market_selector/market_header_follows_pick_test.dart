import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/storefront_interceptor.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/market_support.dart';
import 'support/recording_adapter.dart';

/// The storefront a request names is the market the seller works in when the request is sent, not the one the app started with:
/// a seller who changes market is served for it by the very next request, with no restart and no new client.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String ordersPath = '/api/v3/seller/orders';

  group('while storefronts are on', () {
    test('the next request after a switch names the new market, from the same client', () async {
      final SharedPreferences preferences = await preferencesWith();
      final RecordingAdapter adapter = RecordingAdapter();
      final DioClient client = clientOn(preferences, adapter);
      final SellerMarketController controller = controllerOn(preferences);

      await client.get(ordersPath);
      expect(adapter.last.header(AppConstants.storefrontHeader), 'SA');

      await controller.choose(MarketScope.kuwait);
      await client.get(ordersPath);
      expect(adapter.last.header(AppConstants.storefrontHeader), 'KW');

      await controller.choose(MarketScope.oman);
      await client.get(ordersPath);
      expect(adapter.last.header(AppConstants.storefrontHeader), 'OM');

      await controller.choose(MarketScope.saudiArabia);
      await client.post(ordersPath, data: <String, Object>{'status': 'confirmed'});
      expect(adapter.last.header(AppConstants.storefrontHeader), 'SA');
      expect(adapter.requests, hasLength(4));
    });

    test('the requests that reload the screens after a switch already name the new market', () async {
      final SharedPreferences preferences = await preferencesWith();
      final RecordingAdapter adapter = RecordingAdapter();
      final DioClient client = clientOn(preferences, adapter);
      final SellerMarketController controller = controllerOn(
        preferences,
        onMarketSwitched: () => client.get(ordersPath),
      );

      await controller.choose(MarketScope.unitedArabEmirates);

      expect(adapter.requests, hasLength(1));
      expect(adapter.last.header(AppConstants.storefrontHeader), 'AE');
    });

    test('a market written to the preferences by anyone is the one the next request names', () async {
      final SharedPreferences preferences = await preferencesWith();
      final RecordingAdapter adapter = RecordingAdapter();
      final DioClient client = clientOn(preferences, adapter);

      await preferences.setString(AppConstants.storefrontCountry, 'QA');
      await client.get(ordersPath);

      expect(adapter.last.header(AppConstants.storefrontHeader), 'QA');
    });

    test('a stored value that is not a market never stops a request: it goes to Saudi Arabia', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 7});
      final RecordingAdapter adapter = RecordingAdapter();
      final DioClient client = clientOn(preferences, adapter);

      await client.get(ordersPath);

      expect(adapter.last.header(AppConstants.storefrontHeader), 'SA');
    });

    test('a call that sends files through the same client names the market too', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'BH'});
      final RecordingAdapter adapter = RecordingAdapter();
      final DioClient client = clientOn(preferences, adapter);

      await client.postMultipart('/api/v3/seller/shop/update', data: <String, dynamic>{'name': 'Shop'});

      expect(adapter.last.header(AppConstants.storefrontHeader), 'BH');
    });

    test('the credential and the language still go with it, and a new token changes nothing else', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{
        AppConstants.token: 'dummy-session-token-for-the-tests',
        AppConstants.storefrontCountry: 'KW',
      });
      final RecordingAdapter adapter = RecordingAdapter();
      final DioClient client = clientOn(preferences, adapter);

      client.updateAuthToken('dummy-second-session-token-for-the-tests');
      await client.get(ordersPath);

      expect(adapter.last.header('Authorization'), 'Bearer dummy-second-session-token-for-the-tests');
      expect(adapter.last.header('Accept-Language'), 'en');
      expect(adapter.last.header(AppConstants.storefrontHeader), 'KW');
    });

    test('a request that names a storefront of its own keeps it, and the next one names the market of the seller again', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'KW'});
      final RecordingAdapter adapter = RecordingAdapter();
      final DioClient client = clientOn(preferences, adapter);

      await client.post(
        ordersPath,
        data: <String, Object>{'status': 'confirmed'},
        options: Options(headers: <String, Object>{AppConstants.storefrontHeader: 'AE'}),
      );
      expect(adapter.last.header(AppConstants.storefrontHeader), 'AE');

      await client.post(ordersPath, data: <String, Object>{'status': 'confirmed'});
      expect(adapter.last.header(AppConstants.storefrontHeader), 'KW');
    });

    test('exactly one interceptor does it', () async {
      final DioClient client = clientOn(await preferencesWith(), RecordingAdapter());

      expect(client.dio!.interceptors.whereType<StorefrontInterceptor>(), hasLength(1));
    });
  });

  group('while storefronts are off', () {
    test('no request names a storefront, whatever market is stored', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});
      final RecordingAdapter adapter = RecordingAdapter();
      final DioClient client = clientOn(preferences, adapter, storefrontsEnabled: false);

      await client.get(ordersPath);
      await client.post(ordersPath, data: <String, Object>{'status': 'confirmed'});
      await client.postMultipart('/api/v3/seller/shop/update', data: <String, dynamic>{'name': 'Shop'});

      expect(adapter.requests, hasLength(3));
      for (final RecordedRequest request in adapter.requests) {
        expect(request.headers.containsKey(AppConstants.storefrontHeader.toLowerCase()), isFalse);
      }
    });

    test('the client gets no interceptor for it, and the headers of the client are the ones it always had', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});
      final DioClient client = clientOn(preferences, RecordingAdapter(), storefrontsEnabled: false);

      expect(client.dio!.interceptors.whereType<StorefrontInterceptor>(), isEmpty);
      expect(
        client.dio!.options.headers.keys.map((String name) => name.toLowerCase()).toSet(),
        <String>{'content-type', 'accept', 'authorization', AppConstants.langKey, 'x-localization', 'accept-language'},
      );
    });

    test('a client made as the container makes it follows the build flag, which is off', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});
      final RecordingAdapter adapter = RecordingAdapter();
      final DioClient client = DioClient(
        AppConstants.baseUrl,
        Dio(),
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: preferences,
      );
      client.dio!.httpClientAdapter = adapter;

      await client.get(ordersPath);

      expect(adapter.last.headers.containsKey(AppConstants.storefrontHeader.toLowerCase()), isFalse);
      expect(client.dio!.interceptors.whereType<StorefrontInterceptor>(), isEmpty);
    }, skip: StorefrontConfig.enabled ? 'a pin of the build without the storefront flag' : null);
  });
}
