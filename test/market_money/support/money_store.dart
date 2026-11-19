import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/services/splash_service_interface.dart';

/// The config endpoint's answer for a store, as far as the money formatter reads it.
Map<String, dynamic> moneyStoreConfig({
  required String currencyModel,
  required String symbolPosition,
  required List<Map<String, dynamic>> currencies,
  int? decimals,
}) =>
    <String, dynamic>{
      'system_default_currency': 1,
      'currency_list': currencies,
      'colors': <Object>[],
      'unit': <Object>[],
      'currency_model': currencyModel,
      'currency_symbol_position': symbolPosition,
      if (decimals != null) 'decimal_point_settings': decimals,
    };

Map<String, dynamic> moneyStoreCurrency(int id, String symbol, String code, num exchangeRate) =>
    <String, dynamic>{'id': id, 'name': code, 'symbol': symbol, 'code': code, 'exchange_rate': exchangeRate};

/// A real [SplashController] that has read [config], with [shownCurrencyCode] as the currency the seller reads amounts in.
Future<SplashController> loadedSplashController({required Map<String, dynamic> config, required String shownCurrencyCode}) async {
  final SplashController splash = SplashController(serviceInterface: _FakeSplashService(config: config, shownCurrencyCode: shownCurrencyCode));
  await splash.initConfig();
  return splash;
}

class _FakeSplashService implements SplashServiceInterface {
  _FakeSplashService({required this.config, required this.shownCurrencyCode});

  final Map<String, dynamic> config;
  final String shownCurrencyCode;

  @override
  Future<dynamic> getConfig() async =>
      ApiResponse.withSuccess(Response<Map<String, dynamic>>(requestOptions: RequestOptions(path: '/config'), statusCode: 200, data: config));

  @override
  String getCurrency() => shownCurrencyCode;

  @override
  Future<dynamic> getBusinessPages(String type) => throw UnimplementedError();

  @override
  Future<dynamic> getShippingTypeList(BuildContext context, String type) => throw UnimplementedError();

  @override
  void initSharedData() => throw UnimplementedError();

  @override
  void setCurrency(String currencyCode) => throw UnimplementedError();

  @override
  void setShippingType(String shippingType) => throw UnimplementedError();
}
