import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The code and currency of the market the seller works in, for the title area of the screens that show money. Its text grows with
/// the text size of the phone only up to one and three tenths, as the title of an app bar does, so that on a narrow phone it never
/// takes the room of the title.
class MarketLabel extends StatelessWidget {
  static const double _maxTextScaleFactor = 1.3;

  const MarketLabel({super.key, this.marketController});

  /// The market controller to follow; the one of the app when none is given.
  final SellerMarketController? marketController;

  @override
  Widget build(BuildContext context) {
    final SellerMarketController controller = marketController ?? GetIt.instance<SellerMarketController>();

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final MarketScope market = controller.market;
        if (market.countryCode == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsetsDirectional.only(end: Dimensions.paddingSizeSmall),
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
            vertical: Dimensions.paddingSizeVeryTiny,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Dimensions.radiusPill),
          ),
          child: Text(
            '${market.countryCode} · ${market.currencyCode}',
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _maxTextScaleFactor),
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
          ),
        );
      },
    );
  }
}
