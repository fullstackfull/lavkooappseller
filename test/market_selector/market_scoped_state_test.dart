import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/customer_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/cart_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/temporary_cart_for_customer_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/repository/cart_repository.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/market_scoped_state.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/fake_screens.dart';
import 'support/market_support.dart';
import 'support/recording_adapter.dart';

const List<String> _cartDrop = <String>[
  'cart.removeAllCartList',
  'cart.clearCardForCancel',
  'cart.removeModifiedTax',
  'cart.resetUserCard',
  'cart.saveCardData',
];

const List<String> _alwaysReloaded = <String>[
  'orders.setIndex(3)',
  'notifications.getNotificationList(1)',
  'analytics.setAnalyticsFilterType(0)',
  'analytics.setRevenueFilterType(0)',
  'analytics.getAnalyticsFilterData(overall)',
  'analytics.getDashboardRevenueData(yearEarn)',
  'sellerCenter.getSellerCenterOverview',
  'sellerCenter.getActivities',
  'actionCenter.getInsights(clearSeverity: true)',
  'products.getStockOutProductList(1, en, reload: true)',
  'products.getTopSellingProductList(1, en, reload: true)',
  'products.getMostPopularProductList(1, en, reload: true)',
  'products.getStockLimitStatus',
];

/// The controller of the market wired as the container wires it: its switch handler is the reload of the screens.
SellerMarketController _marketOf(FakeScreens screens) {
  return controllerOn(screens.preferences, onMarketSwitched: reloadMarketScopedState);
}

/// What was asked of the controllers other than the cart.
Iterable<String> _loaded(FakeScreens screens) => screens.calls.where((String call) => !call.startsWith('cart.'));

/// Moving to another market is the moment the screens drop what belonged to the market left, and load what belongs to the market
/// entered. What the screens hold is reached the way the app reaches it: through the providers above the navigator.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a switch of market', () {
    testWidgets('drops the cart, the carts on hold and what the server priced for them, before anything is loaded', (WidgetTester tester) async {
      final FakeScreens screens = FakeScreens(await preferencesWith());
      await screens.mount(tester);
      final SellerMarketController market = _marketOf(screens);

      await tester.runAsync(() => market.choose(MarketScope.kuwait));

      expect(screens.calls.take(_cartDrop.length), _cartDrop);
    });

    testWidgets('reloads the orders of the tab the seller is on, the notifications, the dashboard and the products', (WidgetTester tester) async {
      final FakeScreens screens = FakeScreens(await preferencesWith());
      await screens.mount(tester);
      final SellerMarketController market = _marketOf(screens);

      await tester.runAsync(() => market.choose(MarketScope.kuwait));

      expect(_loaded(screens), unorderedEquals(_alwaysReloaded));
    });

    testWidgets('reloads the point-of-sale products, the product list and the statement once the seller has opened them', (WidgetTester tester) async {
      final FakeScreens screens = FakeScreens(
        await preferencesWith(),
        posListLoaded: true,
        sellerListLoaded: true,
        statementLoaded: true,
      );
      await screens.mount(tester);
      final SellerMarketController market = _marketOf(screens);

      await tester.runAsync(() => market.choose(MarketScope.kuwait));

      expect(_loaded(screens), unorderedEquals(<String>[
        ..._alwaysReloaded,
        'products.getPosProductList(1, [7])',
        'products.getSellerProductList(42, 1, en)',
        'statement.getStatement',
      ]));
    });

    testWidgets('leaves alone the lists the seller has not opened: they load when they are opened', (WidgetTester tester) async {
      final FakeScreens screens = FakeScreens(await preferencesWith());
      await screens.mount(tester);
      final SellerMarketController market = _marketOf(screens);

      await tester.runAsync(() => market.choose(MarketScope.kuwait));

      expect(screens.calls.where((String call) => call.contains('getPosProductList')), isEmpty);
      expect(screens.calls.where((String call) => call.contains('getSellerProductList')), isEmpty);
      expect(screens.calls.where((String call) => call.contains('statement.')), isEmpty);
    });

    testWidgets('does not touch the queue of sales made offline', (WidgetTester tester) async {
      final FakeScreens screens = FakeScreens(await preferencesWith(), posListLoaded: true, sellerListLoaded: true, statementLoaded: true);
      await screens.mount(tester);
      final SellerMarketController market = _marketOf(screens);

      await tester.runAsync(() => market.choose(MarketScope.qatar));

      expect(screens.calls.where((String call) => call.startsWith('outbox.')), isEmpty);
    });

    testWidgets('to the market already worked in drops and loads nothing', (WidgetTester tester) async {
      final FakeScreens screens = FakeScreens(await preferencesWith());
      await screens.mount(tester);
      final SellerMarketController market = _marketOf(screens);

      await tester.runAsync(() => market.choose(MarketScope.saudiArabia));

      expect(screens.calls, isEmpty);
    });

    testWidgets('that is refused drops and loads nothing', (WidgetTester tester) async {
      final FakeScreens screens = FakeScreens(await preferencesWith());
      await screens.mount(tester);
      final SellerMarketController market = _marketOf(screens);

      await tester.runAsync(() => market.choose(MarketScope.allMarkets));

      expect(screens.calls, isEmpty);
    });

    test('with no screen on show has nothing to drop or load, and does not fail', () async {
      await reloadMarketScopedState();
    });
  });

  group('a switch of market, with the real cart', () {
    testWidgets('drops the cart in hand and the carts on hold from the screen and from the device, and leaves the offline sales on it', (WidgetTester tester) async {
      final String heldCart = jsonEncode(
        TemporaryCartListModel(cart: <CartModel>[], userId: 7, userIndex: 1, customerName: 'Held customer', phoneNumber: '').toJson(),
      );
      final String queuedSale = PendingPosOrder(
        id: '1',
        body: <String, dynamic>{'order_amount': 10},
        createdAt: DateTime(2026, 11, 1),
        orderAmount: 10,
        customerName: 'Walk-In Customer',
      ).encode();
      final SharedPreferences preferences = await preferencesWith(<String, Object>{
        AppConstants.cartList: <String>[heldCart],
        'offline_pos_orders': <String>[queuedSale],
      });
      final CartService cartService = CartService(
        cartRepositoryInterface: CartRepository(dioClient: clientOn(preferences, RecordingAdapter()), sharedPreferences: preferences),
      );
      final CartController cart = CartController(cartServiceInterface: cartService);
      final FakeScreens screens = FakeScreens(preferences, cart: cart, customer: CustomerController(cartServiceInterface: cartService));
      await screens.mount(tester);
      cart.getCartData();
      cart.initTempCartData(isUpdate: false);
      cart.currentCartModel!.cart!.add(CartModel(10, 0, 2, 0, null, null, null, null, null, null));
      expect(cart.customerCartList, hasLength(1));
      expect(cart.currentCartModel!.cart, hasLength(1));
      final SellerMarketController market = _marketOf(screens);

      await tester.runAsync(() => market.choose(MarketScope.unitedArabEmirates));

      expect(cart.customerCartList, isEmpty);
      expect(cart.currentCartModel!.cart, isEmpty);
      expect(preferences.getStringList(AppConstants.cartList), isEmpty);
      expect(preferences.getStringList('offline_pos_orders'), <String>[queuedSale]);
    });
  });
}
