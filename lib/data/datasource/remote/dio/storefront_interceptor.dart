import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';

/// Names the storefront on every request at the moment it is sent, so a market chosen while the app is running reaches the very next
/// request without a restart. A request that names a storefront of its own keeps it.
class StorefrontInterceptor extends Interceptor {
  StorefrontInterceptor({required SellerMarketChoice marketChoice}) : _marketChoice = marketChoice;

  final SellerMarketChoice _marketChoice;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    for (final MapEntry<String, String> header in _marketChoice.requestHeaders().entries) {
      options.headers.putIfAbsent(header.key, () => header.value);
    }
    handler.next(options);
  }
}
