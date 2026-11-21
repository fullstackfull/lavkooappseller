import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/seller_principal_source.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_scoped_state.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';

/// Registers the market the seller works in, and nothing at all while storefronts are off, so that an ordinary build has no market
/// controller, screen or listener to speak of.
///
/// The controller is one for the app, because the tile that changes the market and the labels that show it must read the same one.
void registerStorefrontDependencies(GetIt locator, {bool enabled = StorefrontConfig.enabled}) {
  if (!enabled) {
    return;
  }

  locator.registerLazySingleton<SellerMarketController>(
    () => SellerMarketController(
      marketChoice: SellerMarketChoice(locator<SharedPreferences>(), enabled: enabled),
      onMarketSwitched: reloadMarketScopedState,
      // The markets the token carries come from the server and nowhere else, so the picker offers what the seller was granted
      // rather than every market the build knows (K-09). A container with no client has no source, and the controller then holds
      // no grant at all, which is the app as it was before markets existed.
      principalSource: locator.isRegistered<DioClient>() ? SellerPrincipalSource(locator<DioClient>()) : null,
    ),
  );
}
