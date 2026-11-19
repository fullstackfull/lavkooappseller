import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_label.dart';

/// An action of a title area with the market label in front of it, and the action alone while storefronts are off.
class MarketLabeledAction extends StatelessWidget {
  const MarketLabeledAction({
    super.key,
    required this.action,
    this.enabled = StorefrontConfig.enabled,
    this.marketController,
  });

  final Widget action;
  final bool enabled;

  /// The market controller the label follows; the one of the app when none is given.
  final SellerMarketController? marketController;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return action;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MarketLabel(marketController: marketController),
        action,
      ],
    );
  }
}
