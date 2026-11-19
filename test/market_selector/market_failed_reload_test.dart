import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/action_center/controllers/action_center_controller.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/services/action_center_service_interface.dart';
import 'package:syriacosmeticsmanger/features/home/controllers/seller_analytics_controller.dart';
import 'package:syriacosmeticsmanger/features/home/domain/services/seller_analytics_service_interface.dart';
import 'package:syriacosmeticsmanger/features/notification/controllers/notification_controller.dart';
import 'package:syriacosmeticsmanger/features/notification/domain/services/notification_service_interface.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/features/order/domain/services/order_service_interface.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/filter_model.dart';
import 'package:syriacosmeticsmanger/features/product/domain/services/product_service_interface.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/services/seller_center_service_interface.dart';
import 'package:syriacosmeticsmanger/features/statement/controllers/statement_controller.dart';
import 'package:syriacosmeticsmanger/features/statement/domain/services/statement_service_interface.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_scoped_state.dart';

import 'support/fake_screens.dart';
import 'support/market_support.dart';

/// The server of a market, as the screens meet it: it answers what it holds until it is told to refuse, and then it refuses every
/// request, as a server does that has no storefront for the seller or cannot be reached.
class _Server {
  bool refusing = false;

  ApiResponse answer(Map<String, dynamic> body) {
    if (refusing) {
      return ApiResponse.withError('server_unavailable');
    }

    return ApiResponse.withSuccess(Response<dynamic>(requestOptions: RequestOptions(), statusCode: 200, data: body));
  }
}

const Map<String, dynamic> _productPage = <String, dynamic>{'total_size': 0, 'limit': 10, 'offset': 1, 'products': <dynamic>[]};

/// The top selling products are the one list whose page the app reads with its limit and offset as text.
const Map<String, dynamic> _topSellingPage = <String, dynamic>{'total_size': 0, 'limit': '10', 'offset': '1', 'products': <dynamic>[]};

class _Orders extends Fake implements OrderServiceInterface {
  _Orders(this._server);

  final _Server _server;

  @override
  Future<dynamic> getOrderList(int offset, String status, Object? filter) async => _server.answer(_productPage.map(
        (String key, dynamic value) => MapEntry<String, dynamic>(key == 'products' ? 'orders' : key, value),
      ));
}

class _Notifications extends Fake implements NotificationServiceInterface {
  _Notifications(this._server);

  final _Server _server;

  @override
  Future<dynamic> getNotificationList(int offset) async =>
      _server.answer(<String, dynamic>{'total_size': 1, 'limit': 10, 'offset': 1, 'new_notification': 3, 'notification': <dynamic>[]});
}

class _Analytics extends Fake implements SellerAnalyticsServiceInterface {
  _Analytics(this._server);

  final _Server _server;

  @override
  Future<dynamic> getOrderStatistics(String? type) async => _server.answer(<String, dynamic>{'pending': 4, 'delivered': 9});

  @override
  Future<dynamic> getEarningStatistics(String? type) async =>
      _server.answer(<String, dynamic>{'seller_earn': <dynamic>[10, 20], 'commission_earn': <dynamic>[1, 2]});
}

class _SellerCenter extends Fake implements SellerCenterServiceInterface {
  _SellerCenter(this._server);

  final _Server _server;

  @override
  Future<dynamic> getOverview() async => _server.answer(<String, dynamic>{});

  @override
  Future<dynamic> getActivities() async => _server.answer(<String, dynamic>{});

  @override
  Future<dynamic> getPayouts({int offset = 1}) async => _server.answer(<String, dynamic>{});

  @override
  Future<dynamic> getAnalytics({String? range}) async => _server.answer(<String, dynamic>{});
}

class _ActionCenter extends Fake implements ActionCenterServiceInterface {
  _ActionCenter(this._server);

  final _Server _server;

  @override
  Future<dynamic> getInsights({String? severity, int limit = 50}) async => _server.answer(<String, dynamic>{});
}

class _Products extends Fake implements ProductServiceInterface {
  _Products(this._server);

  final _Server _server;

  @override
  Future<dynamic> getStockLimitStatus() async => _server.answer(<String, dynamic>{'status': 'low', 'product_count': 3});

  @override
  Future<dynamic> getPosProductList(int offset, List<String> ids) async => _server.answer(_productPage);

  @override
  Future<dynamic> getStockLimitedProductList(int offset, String languageCode) async => _server.answer(_productPage);

  @override
  Future<dynamic> getMostPopularProductList(int offset, String languageCode) async => _server.answer(_productPage);

  @override
  Future<dynamic> getTopSellingProductList(int offset, String languageCode) async => _server.answer(_topSellingPage);

  @override
  Future<dynamic> getSellerProductList({
    required String sellerId,
    required int offset,
    required String languageCode,
    required String search,
    FilterModel? filterModel,
  }) async =>
      _server.answer(_productPage);
}

class _Statements extends Fake implements StatementServiceInterface {
  _Statements(this._server);

  final _Server _server;

  @override
  Future<dynamic> getStatement({String? entryType, String? status, String? from, String? to, int offset = 1}) async =>
      _server.answer(<String, dynamic>{});
}

/// A switch of market whose reload the server refuses, which is what happens to a seller who picks a market that has no storefront for
/// them, or who has no network: what is left on the screens must not be the figures of the market left, under the label of the market
/// entered.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('leaves no figure of the market left on any screen when the reload is refused', (WidgetTester tester) async {
    final _Server server = _Server();
    final OrderController orders = OrderController(orderServiceInterface: _Orders(server));
    final NotificationController notifications = NotificationController(notificationServiceInterface: _Notifications(server));
    final SellerAnalyticsController analytics = SellerAnalyticsController(sellerAnalyticsServiceInterface: _Analytics(server));
    final SellerCenterController sellerCenter = SellerCenterController(sellerCenterServiceInterface: _SellerCenter(server));
    final ActionCenterController actionCenter = ActionCenterController(actionCenterServiceInterface: _ActionCenter(server));
    final ProductController products = ProductController(productServiceInterface: _Products(server));
    final StatementController statements = StatementController(statementServiceInterface: _Statements(server));
    final FakeScreens screens = FakeScreens(
      await preferencesWith(),
      orders: orders,
      notifications: notifications,
      analytics: analytics,
      sellerCenter: sellerCenter,
      actionCenter: actionCenter,
      products: products,
      statements: statements,
    );
    await screens.mount(tester, home: const Scaffold(body: SizedBox.shrink()));
    final BuildContext context = Get.context!;
    final SellerMarketController market = controllerOn(screens.preferences, onMarketSwitched: reloadMarketScopedState);

    await tester.runAsync(() async {
      await orders.getOrderList(context, 1, 'all', null);
      await notifications.getNotificationList(1);
      await analytics.getAnalyticsFilterData('overall');
      await analytics.getDashboardRevenueData('yearEarn');
      await sellerCenter.getSellerCenterOverview();
      await sellerCenter.getActivities();
      await sellerCenter.getPayouts();
      await sellerCenter.getAnalytics();
      await actionCenter.getInsights();
      await products.getStockLimitStatus(context);
      await products.getPosProductList(1, context, <String>['7']);
      await products.getStockOutProductList(1, 'en');
      await products.getMostPopularProductList(1, context, 'en');
      await products.getTopSellingProductList(1, context, 'en');
      await products.getSellerProductList('42', 1, 'en', '');
      await statements.getStatement();
    });
    expect(orders.orderModel, isNotNull);
    expect(notifications.notificationModel, isNotNull);
    expect(analytics.businessAnalyticsFilterData, isNotNull);
    expect(analytics.userEarnings, isNotNull);
    expect(analytics.userCommissions, isNotNull);
    expect(sellerCenter.overview, isNotNull);
    expect(sellerCenter.activities, isNotNull);
    expect(sellerCenter.payouts, isNotNull);
    expect(sellerCenter.analytics, isNotNull);
    expect(actionCenter.actionCenter, isNotNull);
    expect(products.stockLimitStatus, isNotNull);
    expect(products.posProductModel, isNotNull);
    expect(products.stockOutProductList, isNotNull);
    expect(products.mostPopularProductList, isNotNull);
    expect(products.topSellingProductModel, isNotNull);
    expect(products.sellerProductModel, isNotNull);
    expect(statements.statement, isNotNull);

    server.refusing = true;
    await tester.runAsync(() => market.choose(MarketScope.kuwait));

    expect(market.market, MarketScope.kuwait);
    expect(orders.orderModel, isNull);
    expect(notifications.notificationModel, isNull);
    expect(analytics.businessAnalyticsFilterData, isNull);
    expect(analytics.userEarnings, isNull);
    expect(analytics.userCommissions, isNull);
    expect(sellerCenter.overview, isNull);
    expect(sellerCenter.activities, isNull);
    expect(sellerCenter.payouts, isNull);
    expect(sellerCenter.analytics, isNull);
    expect(actionCenter.actionCenter, isNull);
    expect(products.stockLimitStatus, isNull);
    expect(products.posProductModel, isNull);
    expect(products.posProductList, isEmpty);
    expect(products.stockOutProductList, isNull);
    expect(products.mostPopularProductList, isNull);
    expect(products.topSellingProductModel, isNull);
    expect(products.sellerProductModel, isNull);
    expect(statements.statement, isNull);
  });

  testWidgets('loads the figures of the market entered where the server answers', (WidgetTester tester) async {
    final _Server server = _Server();
    final NotificationController notifications = NotificationController(notificationServiceInterface: _Notifications(server));
    final SellerAnalyticsController analytics = SellerAnalyticsController(sellerAnalyticsServiceInterface: _Analytics(server));
    final SellerCenterController sellerCenter = SellerCenterController(sellerCenterServiceInterface: _SellerCenter(server));
    final ActionCenterController actionCenter = ActionCenterController(actionCenterServiceInterface: _ActionCenter(server));
    final ProductController products = ProductController(productServiceInterface: _Products(server));
    final StatementController statements = StatementController(statementServiceInterface: _Statements(server));
    final FakeScreens screens = FakeScreens(
      await preferencesWith(),
      notifications: notifications,
      analytics: analytics,
      sellerCenter: sellerCenter,
      actionCenter: actionCenter,
      products: products,
      statements: statements,
    );
    await screens.mount(tester);
    final SellerMarketController market = controllerOn(screens.preferences, onMarketSwitched: reloadMarketScopedState);

    await tester.runAsync(() => market.choose(MarketScope.kuwait));

    expect(notifications.notificationModel, isNotNull);
    expect(analytics.businessAnalyticsFilterData, isNotNull);
    expect(analytics.userEarnings, isNotNull);
    expect(sellerCenter.overview, isNotNull);
    expect(sellerCenter.activities, isNotNull);
    expect(actionCenter.actionCenter, isNotNull);
    expect(products.stockLimitStatus, isNotNull);
    expect(products.stockOutProductList, isNotNull);
    expect(products.mostPopularProductList, isNotNull);
    expect(products.topSellingProductModel, isNotNull);
  });
}
