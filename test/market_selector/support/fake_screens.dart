import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/model/response/response_model.dart';
import 'package:syriacosmeticsmanger/features/action_center/controllers/action_center_controller.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/services/action_center_service_interface.dart';
import 'package:syriacosmeticsmanger/features/bank_info/controllers/bank_info_controller.dart';
import 'package:syriacosmeticsmanger/features/bank_info/domain/services/bank_info_service_interface.dart';
import 'package:syriacosmeticsmanger/features/home/controllers/seller_analytics_controller.dart';
import 'package:syriacosmeticsmanger/features/home/domain/services/seller_analytics_service_interface.dart';
import 'package:syriacosmeticsmanger/features/notification/controllers/notification_controller.dart';
import 'package:syriacosmeticsmanger/features/notification/domain/services/notification_service_interface.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/features/order/domain/services/order_service_interface.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/customer_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/offline_sales_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/filter_model.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/features/product/domain/services/product_service_interface.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_info.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/services/profice_service_interface.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/services/seller_center_service_interface.dart';
import 'package:syriacosmeticsmanger/features/statement/controllers/statement_controller.dart';
import 'package:syriacosmeticsmanger/features/statement/domain/models/statement_models.dart';
import 'package:syriacosmeticsmanger/features/statement/domain/services/statement_service_interface.dart';

class _UnusedCartService extends Fake implements CartServiceInterface {}

class _UnusedOrderService extends Fake implements OrderServiceInterface {}

class _UnusedNotificationService extends Fake implements NotificationServiceInterface {}

class _UnusedAnalyticsService extends Fake implements SellerAnalyticsServiceInterface {}

class _UnusedSellerCenterService extends Fake implements SellerCenterServiceInterface {}

class _UnusedActionCenterService extends Fake implements ActionCenterServiceInterface {}

class _UnusedProductService extends Fake implements ProductServiceInterface {}

class _UnusedProfileService extends Fake implements ProfileServiceInterface {}

class _UnusedStatementService extends Fake implements StatementServiceInterface {}

class _UnusedBankInfoService extends Fake implements BankInfoServiceInterface {}

class _RecordingCart extends CartController {
  _RecordingCart(this._calls) : super(cartServiceInterface: _UnusedCartService());

  final List<String> _calls;

  @override
  void removeAllCartList() => _calls.add('cart.removeAllCartList');

  @override
  void clearCardForCancel() => _calls.add('cart.clearCardForCancel');

  @override
  void removeModifiedTax({bool isUpdate = false}) => _calls.add('cart.removeModifiedTax');

  @override
  void resetUserCard() => _calls.add('cart.resetUserCard');

  @override
  void saveCardData() => _calls.add('cart.saveCardData');
}

class _RecordingOrders extends OrderController {
  _RecordingOrders(this._calls, this._selectedTab) : super(orderServiceInterface: _UnusedOrderService());

  final List<String> _calls;
  final int _selectedTab;

  @override
  int get orderTypeIndex => _selectedTab;

  @override
  void setIndex(BuildContext context, int index, {bool notify = true}) => _calls.add('orders.setIndex($index)');
}

class _RecordingNotifications extends NotificationController {
  _RecordingNotifications(this._calls, this._answer) : super(notificationServiceInterface: _UnusedNotificationService());

  final List<String> _calls;
  final Future<void>? _answer;

  @override
  void clearNotifications() => _calls.add('notifications.clearNotifications');

  @override
  Future<void> getNotificationList(int offset) async {
    _calls.add('notifications.getNotificationList($offset)');
    await _answer;
  }
}

class _RecordingAnalytics extends SellerAnalyticsController {
  _RecordingAnalytics(this._calls) : super(sellerAnalyticsServiceInterface: _UnusedAnalyticsService());

  final List<String> _calls;

  @override
  void setAnalyticsFilterType(int index, {bool notify = true}) => _calls.add('analytics.setAnalyticsFilterType($index)');

  @override
  void setRevenueFilterType(int index, {bool notify = true}) => _calls.add('analytics.setRevenueFilterType($index)');

  @override
  void clearEarningStatistics() => _calls.add('analytics.clearEarningStatistics');

  @override
  Future<void> getAnalyticsFilterData(String? type) async => _calls.add('analytics.getAnalyticsFilterData($type)');

  @override
  Future<void> getDashboardRevenueData(String? filterType) async => _calls.add('analytics.getDashboardRevenueData($filterType)');
}

class _RecordingSellerCenter extends SellerCenterController {
  _RecordingSellerCenter(this._calls) : super(sellerCenterServiceInterface: _UnusedSellerCenterService());

  final List<String> _calls;

  @override
  void clearLoadedData() => _calls.add('sellerCenter.clearLoadedData');

  @override
  Future<void> getSellerCenterOverview() async => _calls.add('sellerCenter.getSellerCenterOverview');

  @override
  Future<void> getActivities() async => _calls.add('sellerCenter.getActivities');
}

class _RecordingActionCenter extends ActionCenterController {
  _RecordingActionCenter(this._calls) : super(actionCenterServiceInterface: _UnusedActionCenterService());

  final List<String> _calls;

  @override
  void clearInsights() => _calls.add('actionCenter.clearInsights');

  @override
  Future<void> getInsights({String? severity, bool clearSeverity = false}) async =>
      _calls.add('actionCenter.getInsights(clearSeverity: $clearSeverity)');
}

class _RecordingProducts extends ProductController {
  _RecordingProducts(this._calls, {required this.posListLoaded, required this.sellerListLoaded})
      : super(productServiceInterface: _UnusedProductService());

  final List<String> _calls;
  final bool posListLoaded;
  final bool sellerListLoaded;

  static ProductModel _loadedList() =>
      ProductModel.fromJson(<String, dynamic>{'total_size': 0, 'limit': 10, 'offset': 1, 'products': <dynamic>[]});

  @override
  ProductModel? get posProductModel => posListLoaded ? _loadedList() : null;

  @override
  ProductModel? get sellerProductModel => sellerListLoaded ? _loadedList() : null;

  @override
  List<String> get posSelectedCategoryIds => <String>['7'];

  @override
  Future<void> getStockOutProductList(int offset, String languageCode, {bool reload = false}) async =>
      _calls.add('products.getStockOutProductList($offset, $languageCode, reload: $reload)');

  @override
  Future<void> getTopSellingProductList(int offset, BuildContext context, String languageCode, {bool reload = false}) async =>
      _calls.add('products.getTopSellingProductList($offset, $languageCode, reload: $reload)');

  @override
  Future<void> getMostPopularProductList(int offset, BuildContext context, String languageCode, {bool reload = false}) async =>
      _calls.add('products.getMostPopularProductList($offset, $languageCode, reload: $reload)');

  @override
  void clearStockLimitStatus() => _calls.add('products.clearStockLimitStatus');

  @override
  void clearPosProducts() => _calls.add('products.clearPosProducts');

  @override
  Future<void> getStockLimitStatus(BuildContext context) async => _calls.add('products.getStockLimitStatus');

  @override
  Future<void> getPosProductList(int offset, BuildContext context, List<String> id, {bool reload = true}) async =>
      _calls.add('products.getPosProductList($offset, $id)');

  @override
  Future<void> getSellerProductList(String sellerId, int offset, String languageCode, String search,
          {FilterModel? filterSearchModel}) async =>
      _calls.add('products.getSellerProductList($sellerId, $offset, $languageCode)');
}

class _RecordingProfile extends ProfileController {
  _RecordingProfile(this._calls) : super(profileServiceInterface: _UnusedProfileService());

  final List<String> _calls;

  @override
  int? get userId => 42;

  @override
  ProfileInfoModel? get userInfoModel => ProfileInfoModel(bankName: reloadedBankName);

  /// The bank details the profile holds once it has been loaded again.
  static const String reloadedBankName = 'Bank of the market entered';

  @override
  Future<ResponseModel> getSellerInfo() async {
    _calls.add('profile.getSellerInfo');
    return ResponseModel(true, 'successful');
  }
}

class _RecordingBank extends BankInfoController {
  _RecordingBank(this._calls) : super(bankInfoServiceInterface: _UnusedBankInfoService());

  final List<String> _calls;

  @override
  void setBankInfo(ProfileInfoModel? info) => _calls.add('bank.setBankInfo(${info?.bankName})');
}

class _RecordingStatements extends StatementController {
  _RecordingStatements(this._calls, {required this.loaded}) : super(statementServiceInterface: _UnusedStatementService());

  final List<String> _calls;
  final bool loaded;

  @override
  StatementModel? get statement => loaded ? const StatementModel() : null;

  @override
  void clearStatement() => _calls.add('statement.clearStatement');

  @override
  Future<void> getStatement({
    String? entryType,
    String? status,
    DateTime? from,
    DateTime? to,
    bool clearEntryType = false,
    bool clearStatus = false,
    bool clearDates = false,
  }) async =>
      _calls.add('statement.getStatement');
}

/// The queue of sales made offline, with every way of changing it recorded: a switch of market must not touch it.
class _WatchedOutbox extends OfflineSalesController {
  _WatchedOutbox(this._calls, SharedPreferences preferences)
      : super(cartServiceInterface: _UnusedCartService(), sharedPreferences: preferences);

  final List<String> _calls;

  @override
  Future<PendingPosOrder> enqueue({
    required Map<String, dynamic> orderBody,
    required double orderAmount,
    required String customerName,
    String? idempotencyKey,
  }) async {
    _calls.add('outbox.enqueue');
    return super.enqueue(orderBody: orderBody, orderAmount: orderAmount, customerName: customerName, idempotencyKey: idempotencyKey);
  }

  @override
  Future<void> remove(String id) async => _calls.add('outbox.remove');

  @override
  Future<int> syncPending() async {
    _calls.add('outbox.syncPending');
    return 0;
  }

  @override
  Future<void> clear() async => _calls.add('outbox.clear');
}

/// The controllers the screens read, every one of them recording the calls made to it in one shared log, in the order they were made.
/// A controller handed in is used as it is, instead of the recording one. [notificationsAnswer] holds back the answer of the
/// notifications, to see who waits for it.
class FakeScreens {
  FakeScreens(
    this.preferences, {
    CartController? cart,
    CustomerController? customer,
    OrderController? orders,
    NotificationController? notifications,
    SellerAnalyticsController? analytics,
    SellerCenterController? sellerCenter,
    ActionCenterController? actionCenter,
    ProductController? products,
    StatementController? statements,
    int selectedOrderTab = 3,
    bool posListLoaded = false,
    bool sellerListLoaded = false,
    bool statementLoaded = false,
    Future<void>? notificationsAnswer,
  }) {
    this.cart = cart ?? _RecordingCart(calls);
    this.customer = customer ?? CustomerController(cartServiceInterface: _UnusedCartService());
    this.orders = orders ?? _RecordingOrders(calls, selectedOrderTab);
    this.notifications = notifications ?? _RecordingNotifications(calls, notificationsAnswer);
    this.analytics = analytics ?? _RecordingAnalytics(calls);
    this.sellerCenter = sellerCenter ?? _RecordingSellerCenter(calls);
    this.actionCenter = actionCenter ?? _RecordingActionCenter(calls);
    this.products = products ?? _RecordingProducts(calls, posListLoaded: posListLoaded, sellerListLoaded: sellerListLoaded);
    this.statements = statements ?? _RecordingStatements(calls, loaded: statementLoaded);
  }

  final SharedPreferences preferences;

  /// What was called on the controllers, in order.
  final List<String> calls = <String>[];

  late final CartController cart;
  late final CustomerController customer;
  late final OrderController orders;
  late final NotificationController notifications;
  late final SellerAnalyticsController analytics;
  late final SellerCenterController sellerCenter;
  late final ActionCenterController actionCenter;
  late final ProductController products;
  late final StatementController statements;

  List<SingleChildWidget> get providers => <SingleChildWidget>[
        ChangeNotifierProvider<CartController>.value(value: cart),
        ChangeNotifierProvider<CustomerController>.value(value: customer),
        ChangeNotifierProvider<OrderController>.value(value: orders),
        ChangeNotifierProvider<NotificationController>.value(value: notifications),
        ChangeNotifierProvider<SellerAnalyticsController>.value(value: analytics),
        ChangeNotifierProvider<SellerCenterController>.value(value: sellerCenter),
        ChangeNotifierProvider<ActionCenterController>.value(value: actionCenter),
        ChangeNotifierProvider<ProductController>.value(value: products),
        ChangeNotifierProvider<ProfileController>.value(value: _RecordingProfile(calls)),
        ChangeNotifierProvider<BankInfoController>.value(value: _RecordingBank(calls)),
        ChangeNotifierProvider<StatementController>.value(value: statements),
        ChangeNotifierProvider<OfflineSalesController>.value(value: _WatchedOutbox(calls, preferences)),
      ];

  /// Mounts the app as `main.dart` does for the code that reaches the controllers through the navigator: the providers above the
  /// navigator, and the navigator under the key the app keeps for it. A refused request shows its refusal in a snackbar, which
  /// needs a screen with a scaffold: [home] is one when the test lets requests fail.
  Future<void> mount(WidgetTester tester, {Widget home = const SizedBox.shrink()}) {
    return tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(navigatorKey: navigatorKey, home: home),
      ),
    );
  }
}
