import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The code and currency of the market the seller works in, for the title area of the screens that show money.
class MarketLabel extends StatelessWidget {
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
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
          ),
        );
      },
    );
  }
}
