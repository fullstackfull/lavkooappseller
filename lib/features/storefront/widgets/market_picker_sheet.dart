import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_names.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The markets a seller can work in, the one worked in now marked. Choosing one closes the sheet and saves the choice, and says so when
/// the choice could not be saved.
class MarketPickerSheet extends StatelessWidget {
  const MarketPickerSheet({super.key, required this.marketController});

  final SellerMarketController marketController;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? theme.cardColor : theme.highlightColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusDefault)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: Text(
                getTranslated('select_market', context)!,
                textAlign: TextAlign.center,
                style: titilliumSemiBold.copyWith(color: theme.textTheme.bodyLarge?.color),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final MarketScope scope in marketController.markets)
                    _MarketOption(
                      scope: scope,
                      selected: scope == marketController.market,
                      onTap: () => _choose(context, scope),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, MarketScope scope) async {
    Navigator.of(context).pop();
    final bool saved = await marketController.choose(scope);
    if (!saved && Get.context != null) {
      showCustomSnackBarWidget(getTranslated('market_not_changed', Get.context!), Get.context, sanckBarType: SnackBarType.error);
    }
  }
}

class _MarketOption extends StatelessWidget {
  const _MarketOption({required this.scope, required this.selected, required this.onTap});

  final MarketScope scope;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSize,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MarketNames.of(scope, context)!,
                      style: titilliumRegular.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      '${scope.countryCode} · ${scope.currencyCode}',
                      style: titilliumRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: theme.primaryColor, size: Dimensions.iconSizeLarge),
            ],
          ),
        ),
      ),
    );
  }
}
