import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// The storefront header is off by default, so a default build must send the
/// same headers it always has, even for a seller who has a market stored.
Future<DioClient> _client({String? storedToken, String? storedCountry}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (storedToken != null) AppConstants.token: storedToken,
    if (storedCountry != null) AppConstants.storefrontCountry: storedCountry,
  });

  return DioClient(
    AppConstants.baseUrl,
    Dio(),
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: await SharedPreferences.getInstance(),
  );
}

Set<String> _headerNames(DioClient client) =>
    client.dio!.options.headers.keys.map((String name) => name.toLowerCase()).toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DioClient storefront header', () {
    test('the storefront flag is off by default', () {
      expect(StorefrontConfig.enabled, isFalse);
    });

    test('flag off sends no storefront header, even with a stored market', () async {
      final DioClient client = await _client(storedCountry: 'AE');

      expect(client.dio!.options.headers.containsKey(AppConstants.storefrontHeader), isFalse);
    });

    test('flag off keeps the auth and language headers exactly as before', () async {
      final DioClient client = await _client(storedToken: 'a-real-looking-session-token-value', storedCountry: 'KW');

      expect(_headerNames(client), <String>{
        'content-type',
        'accept',
        'authorization',
        AppConstants.langKey,
        'x-localization',
        'accept-language',
      });
      expect(client.dio!.options.headers['Authorization'], 'Bearer a-real-looking-session-token-value');
      expect(client.dio!.options.headers[AppConstants.langKey], 'en');
      expect(client.dio!.options.headers['X-localization'], 'en');
      expect(client.dio!.options.headers['Accept-Language'], 'en');
    });

    test('updateAuthToken neither adds nor drops the storefront header', () async {
      final DioClient client = await _client(storedToken: 'first-session-token', storedCountry: 'QA');
      final Set<String> namesBefore = _headerNames(client);

      client.updateAuthToken('second-session-token');

      expect(_headerNames(client), namesBefore);
      expect(client.dio!.options.headers.containsKey(AppConstants.storefrontHeader), isFalse);
      expect(client.dio!.options.headers['Authorization'], 'Bearer second-session-token');
    });
  });

  group('StorefrontConfig.resolveHeaderValue', () {
    test('falls back to SA when nothing is stored', () {
      expect(StorefrontConfig.resolveHeaderValue(null), 'SA');
      expect(StorefrontConfig.resolveHeaderValue(''), 'SA');
    });

    test('falls back to SA for an unknown code', () {
      expect(StorefrontConfig.resolveHeaderValue('US'), 'SA');
    });

    test('falls back to SA for All Markets, which never selects a storefront', () {
      expect(StorefrontConfig.resolveHeaderValue(MarketScope.allMarkets.name), 'SA');
    });

    test('returns the stored code when it names a GCC market', () {
      for (final MarketScope scope in MarketScope.gccMarkets) {
        expect(StorefrontConfig.resolveHeaderValue(scope.countryCode), scope.countryCode);
      }
      expect(StorefrontConfig.resolveHeaderValue('bh'), 'BH');
    });
  });
}
