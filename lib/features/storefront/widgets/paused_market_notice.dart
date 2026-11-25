import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/storefront_pause.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_names.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Which market is stopped, said on the screen that stops the seller (K-V4).
///
/// The maintenance screen had no market in it at all, so a seller who works in Kuwait and in Saudi Arabia saw the same screen whichever of
/// them had been stopped, and could not tell which. This names the market the seller is working in and the operator's own words about it,
/// when they wrote any.
///
/// It draws NOTHING unless the server named THAT market as stopped: with storefronts off, on a platform whose markets are all selling, for a
/// seller on All Markets (which is no one market and so cannot be stopped), and on a build whose server does not send the per-market block,
/// the screen is exactly what it was.
class PausedMarketNotice extends StatelessWidget {
  const PausedMarketNotice({super.key, this.marketController, this.pauses});

  /// Passed in by a test. The app reads the one controller the container holds, and nothing at all when storefronts are off, because the
  /// container registers none then.
  final SellerMarketController? marketController;

  /// Passed in by a test, in place of the config answer.
  final Map<String, StorefrontPause>? pauses;

  @override
  Widget build(BuildContext context) {
    final StorefrontPause? pause = _stopOfTheSellersMarket(context);

    if (pause == null) {
      return const SizedBox.shrink();
    }

    final MarketScope? scope = MarketScope.fromCountryCode(pause.country);
    final String? market = scope == null ? null : MarketNames.of(scope, context);

    return Padding(
      padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
      child: Column(
        children: <Widget>[
          Text(
            market == null
                ? getTranslated('this_market_is_paused', context)!
                : '${getTranslated('market_paused', context)!}: $market',
            textAlign: TextAlign.center,
            style: titilliumBold.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          if (pause.message != null) ...<Widget>[
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            Text(pause.message!, textAlign: TextAlign.center, style: titilliumRegular),
          ],
        ],
      ),
    );
  }

  StorefrontPause? _stopOfTheSellersMarket(BuildContext context) {
    final Map<String, StorefrontPause> stopped =
        pauses ?? Provider.of<SplashController>(context, listen: false).configModel?.storefrontPause ?? const <String, StorefrontPause>{};

    if (stopped.isEmpty) {
      return null;
    }

    final SellerMarketController? markets = marketController
        ?? (GetIt.instance.isRegistered<SellerMarketController>() ? GetIt.instance<SellerMarketController>() : null);

    return stopped.ofMarket(markets?.market);
  }
}
