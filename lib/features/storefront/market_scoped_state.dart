import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/features/action_center/controllers/action_center_controller.dart';
import 'package:syriacosmeticsmanger/features/bank_info/controllers/bank_info_controller.dart';
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
/// already has. What was loaded is dropped before the refresh is asked for, so that a refresh that fails leaves a screen with nothing
/// to show, and never with the figures of the market left under the label of the market entered. What a screen loads only when it is
/// opened is left to the screen, and so is whatever is still on its way from before the switch.
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
    _reloadProfile(context),
    _reloadNotifications(context),
    _reloadDashboard(context),
    _reloadProducts(context),
    _reloadStatement(context),
  ]);
}

void _dropPosCart(BuildContext context) {
  final CartController cart = Provider.of<CartController>(context, listen: false);
  cart.dropPosCart();
  cart.saveCardData();
}

void _reloadOrders(BuildContext context) {
  final OrderController orders = Provider.of<OrderController>(context, listen: false);
  orders.setIndex(context, orders.orderTypeIndex);
}

/// The wallet, the withdrawal and the shop screens read what the seller's profile holds, and load it only once: with the dashboard. It
/// is the one thing not dropped first, because the screens read the profile as one that is always there.
Future<void> _reloadProfile(BuildContext context) async {
  final ProfileController profile = Provider.of<ProfileController>(context, listen: false);
  final BankInfoController bank = Provider.of<BankInfoController>(context, listen: false);
  await profile.getSellerInfo();
  bank.setBankInfo(profile.userInfoModel);
}

Future<void> _reloadNotifications(BuildContext context) {
  final NotificationController notifications = Provider.of<NotificationController>(context, listen: false);
  notifications.clearNotifications();
  return notifications.getNotificationList(1);
}

Future<void> _reloadDashboard(BuildContext context) {
  final SellerAnalyticsController analytics = Provider.of<SellerAnalyticsController>(context, listen: false);
  final SellerCenterController sellerCenter = Provider.of<SellerCenterController>(context, listen: false);
  final ActionCenterController actionCenter = Provider.of<ActionCenterController>(context, listen: false);
  analytics.setAnalyticsFilterType(0);
  analytics.setRevenueFilterType(0);
  analytics.clearEarningStatistics();
  sellerCenter.clearLoadedData();
  actionCenter.clearInsights();

  return Future.wait<void>(<Future<void>>[
    analytics.getAnalyticsFilterData('overall'),
    analytics.getDashboardRevenueData('yearEarn'),
    sellerCenter.getSellerCenterOverview(),
    sellerCenter.getActivities(),
    actionCenter.getInsights(clearSeverity: true),
  ]);
}

Future<void> _reloadProducts(BuildContext context) {
  final ProductController products = Provider.of<ProductController>(context, listen: false);
  final ProfileController profile = Provider.of<ProfileController>(context, listen: false);
  final String languageCode = LocalizationController.apiLanguageCode(context);
  final bool posListOpened = products.posProductModel != null;
  final bool productListOpened = products.sellerProductModel != null;
  products.clearStockLimitStatus();
  products.clearPosProducts();

  return Future.wait<void>(<Future<void>>[
    products.getStockOutProductList(1, languageCode, reload: true),
    products.getTopSellingProductList(1, context, languageCode, reload: true),
    products.getMostPopularProductList(1, context, languageCode, reload: true),
    products.getStockLimitStatus(context),
    if (posListOpened) products.getPosProductList(1, context, products.posSelectedCategoryIds),
    if (productListOpened)
      products.getSellerProductList(profile.userId.toString(), 1, languageCode, '', filterSearchModel: products.filterModel),
  ]);
}

Future<void> _reloadStatement(BuildContext context) {
  final StatementController statements = Provider.of<StatementController>(context, listen: false);
  if (statements.statement == null) {
    return Future<void>.value();
  }

  statements.clearStatement();
  return statements.getStatement();
}
