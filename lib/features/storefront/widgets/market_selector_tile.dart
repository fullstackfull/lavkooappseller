import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_names.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_picker_sheet.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The entry of the "more" screen that shows the market the seller works in and opens the list of markets to change it.
class MarketSelectorTile extends StatelessWidget {
  const MarketSelectorTile({super.key, this.marketController});

  /// The market controller to follow and change; the one of the app when none is given.
  final SellerMarketController? marketController;

  @override
  Widget build(BuildContext context) {
    final SellerMarketController controller = marketController ?? GetIt.instance<SellerMarketController>();

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final ThemeData theme = Theme.of(context);
        final BorderRadius borderRadius = BorderRadius.circular(12);

        return Padding(
          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeLarge),
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () => _openMarkets(context, controller),
            child: Container(
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(
                color: theme.highlightColor,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey[theme.brightness == Brightness.dark ? 800 : 200]!,
                    spreadRadius: 0.5,
                    blurRadius: 0.3,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Image.asset(Images.countryIconAddress, width: Dimensions.iconSizeLarge, height: Dimensions.iconSizeLarge),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getTranslated('market', context)!,
                          style: titilliumRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
                        ),
                        Text(
                          MarketNames.of(controller.market, context) ?? '',
                          style: titilliumSemiBold.copyWith(color: theme.textTheme.bodyLarge?.color),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: theme.primaryColor, size: Dimensions.iconSizeSmall),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openMarkets(BuildContext context, SellerMarketController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => MarketPickerSheet(marketController: controller),
    );
  }
}
