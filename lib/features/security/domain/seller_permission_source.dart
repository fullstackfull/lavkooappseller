import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/features/security/domain/models/seller_permission_scope.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Asks the server who is signed in, and reads the role and the permission keys out of the answer (K-08).
///
/// The same answer carries the markets the token was granted, which the market half of the app reads for itself
/// (`SellerPrincipalSource`). The two are not one object because they do not exist in the same builds: a build without
/// storefronts has no market controller at all, while a role still has to be able to hide a screen. The cost is one extra GET of
/// a small answer on a Home load in a build that has both.
///
/// A request that fails, a server that does not know the route and an answer that cannot be read all leave the scope unread, and
/// an unread scope hides nothing — the server refuses what the role may not reach whether or not a button was drawn for it.
class SellerPermissionSource {
  const SellerPermissionSource(this._client);

  final DioClient _client;

  Future<SellerPermissionScope> scope() async {
    try {
      final Response<dynamic> response = await _client.get(AppConstants.sellerPrincipalUri);
      final dynamic body = response.data;

      return body is Map<String, dynamic>
          ? SellerPermissionScope.fromPrincipal(body)
          : const SellerPermissionScope.unrestricted();
    } catch (_) {
      return const SellerPermissionScope.unrestricted();
    }
  }
}
