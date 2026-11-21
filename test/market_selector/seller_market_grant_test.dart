import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/seller_market_grant.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/seller_principal_source.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/market_support.dart';

/// The app offers the markets the token carries, and no others (K-09, the app half).
///
/// The grant is the server's: it is read out of the `me` answer and never decided here. Narrowing the picker is a courtesy, so a
/// seller is not shown a market every screen of which would answer 403; the refusal itself belongs to the server and is proved
/// there, against the real middleware, in the backend's SellerMarketScopeTest.
/// A Dio adapter with nothing behind it that answers one prepared body, so a test of the grant reaches no network.
class _AnsweringAdapter implements HttpClientAdapter {
  _AnsweringAdapter({required this.body, this.statusCode = 200});

  final String body;
  final int statusCode;
  final List<Uri> asked = <Uri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    asked.add(options.uri);

    return ResponseBody.fromString(body, statusCode, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// A real client of the app with nothing behind it but [adapter], as the market support builds one for its own adapter.
DioClient _clientAnswering(SharedPreferences preferences, _AnsweringAdapter adapter) {
  final DioClient client = DioClient(
    AppConstants.baseUrl,
    Dio(),
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: preferences,
    storefrontsEnabled: true,
  );
  client.dio!.httpClientAdapter = adapter;
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the grant as the server answers it', () {
    test('a list of market codes is the grant', () {
      final SellerMarketGrant grant = SellerMarketGrant.fromPrincipal(<String, dynamic>{
        'allowed_markets': <dynamic>['AE', 'SA'],
      });

      expect(grant.restricts, isTrue);
      expect(grant.markets, <MarketScope>[MarketScope.unitedArabEmirates, MarketScope.saudiArabia]);
    });

    test('null is no grant, and no grant is no limit', () {
      final SellerMarketGrant grant = SellerMarketGrant.fromPrincipal(<String, dynamic>{'allowed_markets': null});

      expect(grant.restricts, isFalse);
      expect(grant.narrow(MarketScope.gccMarkets), MarketScope.gccMarkets);
      expect(grant.allows(MarketScope.oman), isTrue);
    });

    test('an answer with no grant key at all, and no answer at all, are no limit', () {
      expect(SellerMarketGrant.fromPrincipal(<String, dynamic>{}).restricts, isFalse);
      expect(SellerMarketGrant.fromPrincipal(null).restricts, isFalse);
    });

    test('a code the app does not know is dropped, and a repeated code is kept once', () {
      final SellerMarketGrant grant = SellerMarketGrant.fromPrincipal(<String, dynamic>{
        'allowed_markets': <dynamic>['SA', 'ZZ', 'SAU', 7, null, 'sa'],
      });

      expect(grant.markets, <MarketScope>[MarketScope.saudiArabia]);
    });

    test('a grant of nothing reaches nothing, and is not read as no limit', () {
      final SellerMarketGrant grant = SellerMarketGrant.fromPrincipal(<String, dynamic>{'allowed_markets': <dynamic>[]});

      expect(grant.restricts, isTrue);
      expect(grant.narrow(MarketScope.gccMarkets), isEmpty);
      expect(grant.allows(MarketScope.saudiArabia), isFalse);
    });

    test('All Markets is never granted, because it is no market a request can target', () {
      final SellerMarketGrant grant = SellerMarketGrant.fromPrincipal(<String, dynamic>{
        'allowed_markets': <dynamic>['SA', 'AE'],
      });

      expect(grant.allows(MarketScope.allMarkets), isFalse);
    });
  });

  group('the grant is asked of the server', () {
    test('a build with no source never asks, and stays as the app always was', () async {
      final SellerMarketController controller = controllerOn(await preferencesWith());

      await controller.refreshGrant();

      expect(controller.grant.restricts, isFalse);
      expect(controller.markets, MarketScope.gccMarkets);
    });

    test('the markets the server answers become the markets the app offers', () async {
      final _AnsweringAdapter adapter = _AnsweringAdapter(
        body: '{"principal_type":"owner","allowed_markets":["AE","BH"],"market_scope":"limited"}',
      );
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});
      final SellerMarketController controller = SellerMarketController(
        marketChoice: SellerMarketChoice(preferences, enabled: true),
        onMarketSwitched: () async {},
        principalSource: SellerPrincipalSource(_clientAnswering(preferences, adapter)),
      );

      await controller.refreshGrant();

      expect(adapter.asked.single.path, AppConstants.sellerPrincipalUri);
      expect(controller.markets, <MarketScope>[MarketScope.unitedArabEmirates, MarketScope.bahrain]);
    });

    test('a server that refuses the route leaves the app unrestricted, because the server still refuses the market', () async {
      final _AnsweringAdapter adapter = _AnsweringAdapter(statusCode: 404, body: '{"message":"not found"}');
      final SharedPreferences preferences = await preferencesWith();
      final SellerMarketController controller = SellerMarketController(
        marketChoice: SellerMarketChoice(preferences, enabled: true),
        onMarketSwitched: () async {},
        principalSource: SellerPrincipalSource(_clientAnswering(preferences, adapter)),
      );

      await controller.refreshGrant();

      expect(controller.grant.restricts, isFalse);
      expect(controller.markets, MarketScope.gccMarkets);
    });
  });

  group('the controller once the grant arrives', () {
    test('it offers every GCC market until a grant arrives, as the app always has', () async {
      final SellerMarketController controller = controllerOn(await preferencesWith());

      expect(controller.markets, MarketScope.gccMarkets);
    });

    test('it offers the granted markets only, in the order the app offers them', () async {
      final SellerMarketController controller = controllerOn(await preferencesWith());

      await controller.applyGrant(SellerMarketGrant.fromPrincipal(<String, dynamic>{
        'allowed_markets': <dynamic>['OM', 'AE'],
      }));

      expect(controller.markets, <MarketScope>[MarketScope.unitedArabEmirates, MarketScope.oman]);
    });

    test('a seller working in a market the grant does not hold is moved to one it does', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'KW'});
      final List<String> reloads = <String>[];
      final SellerMarketController controller = controllerOn(preferences, onMarketSwitched: () async => reloads.add('reloaded'));

      expect(controller.market, MarketScope.kuwait);

      await controller.applyGrant(SellerMarketGrant.fromPrincipal(<String, dynamic>{
        'allowed_markets': <dynamic>['AE', 'BH'],
      }));

      expect(controller.market, MarketScope.unitedArabEmirates);
      expect(reloads, <String>['reloaded'], reason: 'the screens are reloaded for the market the seller was moved to');
      expect(preferences.getString(AppConstants.storefrontCountry), 'AE', reason: 'and the move is saved, so the next start begins there');
    });

    test('a seller already in a granted market is left where they are, and nothing is reloaded', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'AE'});
      final List<String> reloads = <String>[];
      final SellerMarketController controller = controllerOn(preferences, onMarketSwitched: () async => reloads.add('reloaded'));

      await controller.applyGrant(SellerMarketGrant.fromPrincipal(<String, dynamic>{
        'allowed_markets': <dynamic>['AE', 'SA'],
      }));

      expect(controller.market, MarketScope.unitedArabEmirates);
      expect(reloads, isEmpty);
    });

    test('a market outside the grant cannot be chosen, and nothing is saved for it', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'SA'});
      final SellerMarketController controller = controllerOn(preferences);

      await controller.applyGrant(SellerMarketGrant.fromPrincipal(<String, dynamic>{'allowed_markets': <dynamic>['SA']}));

      expect(await controller.choose(MarketScope.qatar), isFalse);
      expect(controller.market, MarketScope.saudiArabia);
      expect(preferences.getString(AppConstants.storefrontCountry), 'SA');
    });

    test('a grant of nothing offers nothing and moves nobody, because there is nowhere to move to', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'SA'});
      final List<String> reloads = <String>[];
      final SellerMarketController controller = controllerOn(preferences, onMarketSwitched: () async => reloads.add('reloaded'));

      await controller.applyGrant(SellerMarketGrant.fromPrincipal(<String, dynamic>{'allowed_markets': <dynamic>[]}));

      expect(controller.markets, isEmpty);
      expect(controller.market, MarketScope.saudiArabia);
      expect(reloads, isEmpty);
    });

    test('a single-market Saudi seller is offered Saudi Arabia and is left exactly where they were', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'SA'});
      final List<String> reloads = <String>[];
      final SellerMarketController controller = controllerOn(preferences, onMarketSwitched: () async => reloads.add('reloaded'));

      await controller.applyGrant(SellerMarketGrant.fromPrincipal(<String, dynamic>{'allowed_markets': <dynamic>['SA']}));

      expect(controller.markets, <MarketScope>[MarketScope.saudiArabia]);
      expect(controller.market, MarketScope.saudiArabia);
      expect(reloads, isEmpty, reason: 'nothing is reloaded, so the screens of a Saudi-only seller are the screens they had');
    });
  });
}
