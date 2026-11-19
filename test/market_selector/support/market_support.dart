import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'recording_adapter.dart';

/// A store that refuses every write, as a phone with a full disk does.
class RefusingPreferences extends Fake implements SharedPreferences {
  @override
  Object? get(String key) => null;

  @override
  Future<bool> setString(String key, String value) async => false;
}

Future<SharedPreferences> preferencesWith([Map<String, Object> values = const <String, Object>{}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// A real client of the app with nothing behind it but [adapter].
DioClient clientOn(SharedPreferences preferences, RecordingAdapter adapter, {bool storefrontsEnabled = true}) {
  final DioClient client = DioClient(
    AppConstants.baseUrl,
    Dio(),
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: preferences,
    storefrontsEnabled: storefrontsEnabled,
  );
  client.dio!.httpClientAdapter = adapter;
  return client;
}

/// The controller of the market as the container makes it, with [onMarketSwitched] standing in for the reload of the screens.
SellerMarketController controllerOn(
  SharedPreferences preferences, {
  MarketSwitchHandler? onMarketSwitched,
  bool enabled = true,
}) {
  return SellerMarketController(
    marketChoice: SellerMarketChoice(preferences, enabled: enabled),
    onMarketSwitched: onMarketSwitched ?? () async {},
  );
}
