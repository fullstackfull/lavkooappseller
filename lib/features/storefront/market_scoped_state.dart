import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/features/action_center/controllers/action_center_controller.dart';
import 'package:syriacosmeticsmanger/features/home/controllers/seller_analytics_controller.dart';
import 'package:syriacosmeticsmanger/features/notification/controllers/notification_controller.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/statement/controllers/statement_controller.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';

/// Drops what belonged to the market the seller left and loads what belongs to the market entered, with the refresh each screen
/// already has. What a screen loads only when it is opened is left to the screen.
///
/// The queue of sales made offline is not touched: a sale taken in a market is still owed to it.
Future<void> reloadMarketScopedState() async {
  final BuildContext? context = Get.context;
  if (context == null) {
    return;
  }

  _dropPosCart(context);
  _reloadOrders(context);
  await Future.wait<void>(<Future<void>>[
    _reloadNotifications(context),
    _reloadDashboard(context),
    _reloadProducts(context),
    _reloadStatement(context),
  ]);
}

void _dropPosCart(BuildContext context) {
  final CartController cart = Provider.of<CartController>(context, listen: false);
  cart.removeAllCartList();
  cart.clearCardForCancel();
  cart.removeModifiedTax();
  cart.resetUserCard();
  cart.saveCardData();
}

void _reloadOrders(BuildContext context) {
  final OrderController orders = Provider.of<OrderController>(context, listen: false);
  orders.setIndex(context, orders.orderTypeIndex);
}

Future<void> _reloadNotifications(BuildContext context) {
  return Provider.of<NotificationController>(context, listen: false).getNotificationList(1);
}

Future<void> _reloadDashboard(BuildContext context) {
  final SellerAnalyticsController analytics = Provider.of<SellerAnalyticsController>(context, listen: false);
  final SellerCenterController sellerCenter = Provider.of<SellerCenterController>(context, listen: false);
  analytics.setAnalyticsFilterType(0);
  analytics.setRevenueFilterType(0);

  return Future.wait<void>(<Future<void>>[
    analytics.getAnalyticsFilterData('overall'),
    analytics.getDashboardRevenueData('yearEarn'),
    sellerCenter.getSellerCenterOverview(),
    sellerCenter.getActivities(),
    Provider.of<ActionCenterController>(context, listen: false).getInsights(clearSeverity: true),
  ]);
}

Future<void> _reloadProducts(BuildContext context) {
  final ProductController products = Provider.of<ProductController>(context, listen: false);
  final ProfileController profile = Provider.of<ProfileController>(context, listen: false);
  final String languageCode = LocalizationController.apiLanguageCode(context);

  return Future.wait<void>(<Future<void>>[
    products.getStockOutProductList(1, languageCode, reload: true),
    products.getTopSellingProductList(1, context, languageCode, reload: true),
    products.getMostPopularProductList(1, context, languageCode, reload: true),
    products.getStockLimitStatus(context),
    if (products.posProductModel != null) products.getPosProductList(1, context, products.posSelectedCategoryIds),
    if (products.sellerProductModel != null)
      products.getSellerProductList(profile.userId.toString(), 1, languageCode, '', filterSearchModel: products.filterModel),
  ]);
}

Future<void> _reloadStatement(BuildContext context) {
  final StatementController statements = Provider.of<StatementController>(context, listen: false);
  return statements.statement == null ? Future<void>.value() : statements.getStatement();
}
