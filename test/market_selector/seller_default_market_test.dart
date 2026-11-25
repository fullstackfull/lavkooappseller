import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/platform_default_market_source.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/market_support.dart';

/// A1-03, the seller app's half: the market a seller who has chosen none works in is the one the SERVER names, not a constant in the
/// build.
///
/// Which market the platform serves whoever has chosen none is a decision an administrator records on the server, and moving it must
/// not need a new release of this app. The customer app already reads it; this app fell back to `MarketScope.defaultScope`, which is
/// Saudi Arabia compiled in.
///
/// Three rules hold it together. A seller's own choice outranks the default and is never touched by it. An answer the app cannot read
/// — a failed request, a route the server does not know, a market this build does not list — leaves the market as it was rather than
/// guessing. And while storefronts are off nothing is asked, nothing is written, and every read answers All Markets, which is the app
/// as it shipped.
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

SellerMarketController _controllerAnswering(
  SharedPreferences preferences,
  _AnsweringAdapter adapter, {
  bool enabled = true,
}) {
  return SellerMarketController(
    marketChoice: SellerMarketChoice(preferences, enabled: enabled),
    onMarketSwitched: () async {},
    defaultMarketSource: PlatformDefaultMarketSource(_clientAnswering(preferences, adapter)),
  );
}

String _answerNaming(String? defaultCountry) {
  final String named = defaultCountry == null ? 'null' : '"$defaultCountry"';
  return '{"storefronts":[{"code":"SA"},{"code":"KW"}],"default_country":$named}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the default market as the server names it', () {
    test('a seller who has chosen nothing works in the market the server names', () async {
      final _AnsweringAdapter adapter = _AnsweringAdapter(body: _answerNaming('KW'));
      final SharedPreferences preferences = await preferencesWith();
      final SellerMarketController controller = _controllerAnswering(preferences, adapter);

      expect(controller.market, MarketScope.saudiArabia, reason: 'the build defaults to Saudi Arabia until the server says otherwise');

      await controller.refreshPlatformDefault();

      expect(adapter.asked.single.path, AppConstants.storefrontsUri);
      expect(controller.market, MarketScope.kuwait);
      expect(preferences.getString(AppConstants.storefrontDefaultCountry), 'KW');
      expect(preferences.getString(AppConstants.storefrontCountry), isNull, reason: 'and nothing was chosen on the seller\'s behalf');
    });

    test('a seller who chose a market keeps it, whatever the default becomes', () async {
      final _AnsweringAdapter adapter = _AnsweringAdapter(body: _answerNaming('KW'));
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontCountry: 'OM'});
      final SellerMarketController controller = _controllerAnswering(preferences, adapter);

      await controller.refreshPlatformDefault();

      expect(controller.market, MarketScope.oman, reason: 'a choice outranks the default');
      expect(preferences.getString(AppConstants.storefrontDefaultCountry), 'KW', reason: 'which is still remembered for the day they clear it');
    });

    test('an answer that names no market the app can serve forgets the one it remembered', () async {
      for (final String body in <String>[
        _answerNaming(null),
        _answerNaming('ZZ'),
        '{"default_country":7}',
        '{"storefronts":[]}',
      ]) {
        final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontDefaultCountry: 'KW'});
        final SellerMarketController controller = _controllerAnswering(preferences, _AnsweringAdapter(body: body));

        await controller.refreshPlatformDefault();

        expect(controller.market, MarketScope.saudiArabia, reason: 'a withdrawn default stops moving sellers: [$body]');
        expect(preferences.getString(AppConstants.storefrontDefaultCountry), isNull, reason: body);
      }
    });

    test('a body that is not an answer at all leaves the market as it was', () async {
      for (final String body in <String>['[]', 'not json at all', '']) {
        final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontDefaultCountry: 'KW'});
        final SellerMarketController controller = _controllerAnswering(preferences, _AnsweringAdapter(body: body));

        await controller.refreshPlatformDefault();

        expect(controller.market, MarketScope.kuwait, reason: 'nothing was learned, so nothing changes: [$body]');
        expect(preferences.getString(AppConstants.storefrontDefaultCountry), 'KW', reason: body);
      }
    });

    test('a request that fails leaves the market as it was', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontDefaultCountry: 'KW'});
      final SellerMarketController controller = _controllerAnswering(
        preferences,
        _AnsweringAdapter(body: 'Service Unavailable', statusCode: 503),
      );

      await controller.refreshPlatformDefault();

      expect(controller.market, MarketScope.kuwait, reason: 'a server that did not answer says nothing about the default');
      expect(preferences.getString(AppConstants.storefrontDefaultCountry), 'KW');
    });

    test('a build with no source never asks', () async {
      final SellerMarketController controller = controllerOn(await preferencesWith());

      await controller.refreshPlatformDefault();

      expect(controller.market, MarketScope.saudiArabia);
    });

    test('while storefronts are off nothing is asked for, written or answered but All Markets', () async {
      final _AnsweringAdapter adapter = _AnsweringAdapter(body: _answerNaming('KW'));
      final SharedPreferences preferences = await preferencesWith();
      final SellerMarketController controller = _controllerAnswering(preferences, adapter, enabled: false);

      await controller.refreshPlatformDefault();

      expect(controller.market, MarketScope.allMarkets);
      expect(preferences.getString(AppConstants.storefrontDefaultCountry), isNull, reason: 'the answer is not written while markets are off');
    });

    test('the header a request carries is the market the screens show, default included', () async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{AppConstants.storefrontDefaultCountry: 'KW'});
      final SellerMarketChoice choice = SellerMarketChoice(preferences, enabled: true);

      expect(choice.current(), MarketScope.kuwait);
      expect(choice.storefrontCode(), 'KW', reason: 'a request must not target a market other than the one being shown');

      await choice.choose(MarketScope.oman);

      expect(choice.storefrontCode(), 'OM', reason: 'and a choice still outranks the default');
    });

    test('the listeners are told only when the market the seller works in actually moves', () async {
      final SharedPreferences preferences = await preferencesWith();
      final SellerMarketController controller = _controllerAnswering(preferences, _AnsweringAdapter(body: _answerNaming('KW')));
      int told = 0;
      controller.addListener(() => told++);

      await controller.refreshPlatformDefault();
      expect(told, 1);

      await controller.refreshPlatformDefault();
      expect(told, 1, reason: 'the same answer moves nobody');
    });

    test('a store that refuses every write leaves the app working, in the market it had', () async {
      final SellerMarketController controller = SellerMarketController(
        marketChoice: SellerMarketChoice(RefusingPreferences(), enabled: true),
        onMarketSwitched: () async {},
        defaultMarketSource: null,
      );

      await controller.refreshPlatformDefault();

      expect(controller.market, MarketScope.saudiArabia);
    });
  });
}
