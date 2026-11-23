import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/seller_market_grant.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Asks the server who is signed in, and reads the markets the token carries out of the answer (K-09).
///
/// The grant is never inferred from anything the app holds: it is whatever `allowed_markets` of
/// `GET api/v3/seller/seller-center/security/me` says. An answer that cannot be read, a request that fails and a server that does
/// not know the route all leave the app unrestricted, which is what it has always been — the server still refuses a market it did
/// not grant, so failing open here widens nothing.
class SellerPrincipalSource {
  const SellerPrincipalSource(this._client);

  final DioClient _client;

  Future<SellerMarketGrant> grant() async {
    try {
      final Response<dynamic> response = await _client.get(AppConstants.sellerPrincipalUri);
      final dynamic body = response.data;

      return body is Map<String, dynamic>
          ? SellerMarketGrant.fromPrincipal(body)
          : const SellerMarketGrant.unrestricted();
    } catch (_) {
      return const SellerMarketGrant.unrestricted();
    }
  }
}
