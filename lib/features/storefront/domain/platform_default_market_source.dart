import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/platform_default_market.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Asks the server which market the platform serves whoever has chosen none (A1-03).
///
/// The default market is a decision an administrator records on the server, not a constant in a build: moving it must move a seller who
/// has chosen no market of their own, without shipping a new app. `GET api/v1/storefronts` answers it in `default_country`, needs no
/// token, and is the same answer the customer app reads.
///
/// It never throws and never guesses. A request that fails, a route the server does not know and a body that is not an object answer
/// [PlatformDefaultMarket.noAnswer], and the app keeps the market it had; an object whose `default_country` is missing, is not text, or
/// names a market this build does not list answers a market of null, which forgets a default the server has withdrawn.
class PlatformDefaultMarketSource {
  const PlatformDefaultMarketSource(this._client);

  final DioClient _client;

  Future<PlatformDefaultMarket> defaultMarket() async {
    try {
      final Response<dynamic> response = await _client.get(AppConstants.storefrontsUri);
      final dynamic body = response.data;
      if (body is! Map<String, dynamic>) {
        return const PlatformDefaultMarket.noAnswer();
      }

      final Object? named = body['default_country'];

      return PlatformDefaultMarket.answered(named is String ? MarketScope.fromCountryCode(named) : null);
    } catch (_) {
      return const PlatformDefaultMarket.noAnswer();
    }
  }
}
