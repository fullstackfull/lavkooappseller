import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/customer_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/offline_sales_controller.dart';
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
  'profile.getSellerInfo',
  'bank.setBankInfo(Bank of the market entered)',
  'notifications.clearNotifications',
  'notifications.getNotificationList(1)',
  'analytics.setAnalyticsFilterType(0)',
  'analytics.setRevenueFilterType(0)',
  'analytics.clearEarningStatistics',
  'analytics.getAnalyticsFilterData(overall)',
  'analytics.getDashboardRevenueData(yearEarn)',
  'sellerCenter.clearLoadedData',
  'sellerCenter.getSellerCenterOverview',
  'sellerCenter.getActivities',
  'actionCenter.clearInsights',
  'actionCenter.getInsights(clearSeverity: true)',
  'products.clearStockLimitStatus',
  'products.clearPosProducts',
  'products.getStockOutProductList(1, en, reload: true)',
  'products.getTopSellingProductList(1, en, reload: true)',
  'products.getMostPopularProductList(1, en, reload: true)',
  'products.getStockLimitStatus',
];

/// What is dropped, and the first thing that loads it again: the drop has to come first, or a refresh that fails leaves the figures of
/// the market left on show.
const Map<String, String> _dropBeforeLoad = <String, String>{
  'notifications.clearNotifications': 'notifications.getNotificationList(1)',
  'analytics.clearEarningStatistics': 'analytics.getDashboardRevenueData(yearEarn)',
  'sellerCenter.clearLoadedData': 'sellerCenter.getSellerCenterOverview',
  'actionCenter.clearInsights': 'actionCenter.getInsights(clearSeverity: true)',
  'products.clearStockLimitStatus': 'products.getStockLimitStatus',
  'products.clearPosProducts': 'products.getPosProductList(1, [7])',
  'statement.clearStatement': 'statement.getStatement',
};

/// A server that answers a replayed sale with an order number, so that the outbox counts it as placed, and records what it was sent.
class _SalesServer extends RecordingAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    await super.fetch(options, requestStream, cancelFuture);

    return ResponseBody.fromString('{"order_id": 7}', 200, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    });
  }
}

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
        'statement.clearStatement',
        'statement.getStatement',
      ]));
    });

    testWidgets('drops what each screen holds before it asks for it again', (WidgetTester tester) async {
      final FakeScreens screens = FakeScreens(
        await preferencesWith(),
        posListLoaded: true,
        sellerListLoaded: true,
        statementLoaded: true,
      );
      await screens.mount(tester);
      final SellerMarketController market = _marketOf(screens);

      await tester.runAsync(() => market.choose(MarketScope.kuwait));

      for (final MapEntry<String, String> step in _dropBeforeLoad.entries) {
        expect(screens.calls, contains(step.key));
        expect(screens.calls, contains(step.value));
        expect(screens.calls.indexOf(step.key), lessThan(screens.calls.indexOf(step.value)), reason: '${step.key} comes before ${step.value}');
      }
    });

    testWidgets('loads the profile again, and hands the bank details it now holds to the bank', (WidgetTester tester) async {
      final FakeScreens screens = FakeScreens(await preferencesWith());
      await screens.mount(tester);
      final SellerMarketController market = _marketOf(screens);

      await tester.runAsync(() => market.choose(MarketScope.kuwait));

      expect(screens.calls, containsAllInOrder(<String>['profile.getSellerInfo', 'bank.setBankInfo(Bank of the market entered)']));
    });

    testWidgets('is complete only when the screens have been loaded again, so a caller can wait for them', (WidgetTester tester) async {
      final Completer<void> answered = Completer<void>();
      final FakeScreens screens = FakeScreens(await preferencesWith(), notificationsAnswer: answered.future);
      await screens.mount(tester);
      final SellerMarketController market = _marketOf(screens);
      bool complete = false;
      late final Future<bool> choosing;

      await tester.runAsync(() async {
        choosing = market.choose(MarketScope.kuwait).whenComplete(() => complete = true);
        await pumpEventQueue();
      });
      expect(complete, isFalse);

      await tester.runAsync(() async {
        answered.complete();
        await choosing;
      });
      expect(complete, isTrue);
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

  group('one switch of market, with the real cart and the real queue of sales made offline', () {
    testWidgets('drops the cart in hand, the carts on hold and the cart on the device, and leaves the sale queued in Saudi Arabia owed to Saudi Arabia, which is where it is replayed from Kuwait',
        (WidgetTester tester) async {
      final SharedPreferences preferences = await preferencesWith(<String, Object>{
        AppConstants.cartList: <String>[
          jsonEncode(TemporaryCartListModel(cart: <CartModel>[], userId: 7, userIndex: 1, customerName: 'Held customer', phoneNumber: '').toJson()),
        ],
      });
      final _SalesServer server = _SalesServer();
      final CartService cartService = CartService(
        cartRepositoryInterface: CartRepository(dioClient: clientOn(preferences, server, storefrontsEnabled: true), sharedPreferences: preferences),
      );
      final CartController cart = CartController(cartServiceInterface: cartService);
      // The queue as the container builds it in a storefront build, over the same device store the cart and the market choice use.
      final OfflineSalesController outbox = OfflineSalesController(
        cartServiceInterface: cartService,
        sharedPreferences: preferences,
        hasSession: () => true,
        signedInSellerId: () => '7',
        storefrontsEnabled: true,
      )..loadFromStorage();
      final FakeScreens screens = FakeScreens(
        preferences,
        cart: cart,
        customer: CustomerController(cartServiceInterface: cartService),
        outbox: outbox,
      );
      await screens.mount(tester);
      // The market the sale is taken in, and the counter as the seller leaves it: a sale rung up offline, a cart in hand and a cart
      // put aside for a customer.
      final SellerMarketController market = _marketOf(screens);
      await tester.runAsync(() => market.choose(MarketScope.saudiArabia));
      cart.getCartData();
      cart.initTempCartData(isUpdate: false);
      cart.currentCartModel!.cart!.add(CartModel(10, 0, 2, 0, null, null, null, null, null, null));
      final PendingPosOrder queued = (await tester.runAsync(() => outbox.enqueue(
            orderBody: <String, dynamic>{'user_id': 0, 'cart': <String>['sale-1']},
            orderAmount: 25,
            customerName: 'Layla',
            idempotencyKey: 'sale-1',
          )))!;
      expect(queued.storefront, 'SA');
      expect(cart.customerCartList, hasLength(1));
      expect(cart.currentCartModel!.cart, hasLength(1));

      await tester.runAsync(() => market.choose(MarketScope.kuwait));

      expect(cart.currentCartModel!.cart, isEmpty, reason: 'the sale being rung up in Saudi Arabia is not carried into Kuwait');
      expect(cart.customerCartList, isEmpty, reason: 'nor are the carts put aside there');
      expect(preferences.getStringList(AppConstants.cartList), isEmpty, reason: 'nor the cart the device held');
      expect(_loaded(screens), unorderedEquals(_alwaysReloaded), reason: 'and the one switch reloaded the lists, the notifications and the dashboard');
      expect(outbox.pending.single.storefront, 'SA', reason: 'the money taken in Saudi Arabia is still owed to Saudi Arabia');
      expect(
        (jsonDecode(preferences.getStringList('offline_pos_orders')!.single) as Map<String, dynamic>)['storefront'],
        'SA',
        reason: 'on the device as well, which is the only record of it',
      );

      expect(await tester.runAsync(() => outbox.syncPending()), 1);

      final List<Object?> marketsSent = server.requests
          .where((RecordedRequest request) => request.uri.path.endsWith(AppConstants.placeOrderUri))
          .map((RecordedRequest request) => request.header(AppConstants.storefrontHeader))
          .toList();
      expect(marketsSent, <Object?>['SA'], reason: 'the seller works in Kuwait by now, and the sale still goes to Saudi Arabia');
    });
  });
}
