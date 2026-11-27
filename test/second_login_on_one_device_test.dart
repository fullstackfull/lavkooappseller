import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/repositories/auth_repository.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/services/auth_service.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/customer_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/offline_sales_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/cart_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/temporary_cart_for_customer_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/repository/cart_repository.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/services/profice_service_interface.dart';
import 'package:syriacosmeticsmanger/features/shop/controllers/shop_controller.dart';
import 'package:syriacosmeticsmanger/features/shop/domain/services/shop_service_interface.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/repositories/splash_repository.dart';
import 'package:syriacosmeticsmanger/features/storefront/controllers/seller_market_controller.dart';
import 'package:syriacosmeticsmanger/features/storefront/domain/models/market_scope.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'market_selector/support/recording_adapter.dart';

const String _queueKey = 'offline_pos_orders';
const int _idOfTheFirstSeller = 7;
const int _idOfTheSecondSeller = 9;

/// A sale the outbox replayed: the key it was sent under, and the market the request named.
class _SaleSent {
  _SaleSent(this.key, this.market);

  final String? key;
  final String? market;
}

/// The cart service of the app over the real store on the phone, with only the sending of a sale faked: the server takes every sale it
/// is given.
class _CartServiceWithoutANetwork extends CartService {
  _CartServiceWithoutANetwork({required super.cartRepositoryInterface});

  final List<_SaleSent> salesSent = <_SaleSent>[];

  @override
  Future<dynamic> placeOrderRaw(Map<String, dynamic> orderBody,
      {String? idempotencyKey, String? storefront}) async {
    salesSent.add(_SaleSent(idempotencyKey, storefront));

    return ApiResponse.withSuccess(
      Response<dynamic>(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 200,
          data: <String, dynamic>{'order_id': salesSent.length}),
    );
  }
}

/// The profile of the seller, as the server answers it for the session that asked.
class _FakeProfileService implements ProfileServiceInterface {
  int? sellerId;

  @override
  Future<dynamic> getSellerInfo() async =>
      ApiResponse.withSuccess(Response<dynamic>(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 200,
          data: <String, dynamic>{'id': sellerId, 'pos_status': 1}));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeShopService implements ShopServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One phone with the app on it, which more than one seller signs in to: the real sign-out, the real profile, the real store of the
/// carts on hold, the real market choice, the real reader of the currency and the real outbox, over shared preferences in memory.
/// Only the network is faked. The market is asked for with storefronts on, so that the market a seller chose is really written to the
/// phone and the test says the same thing in a build with the flag and in a build without it.
class _Phone {
  _Phone._(this.preferences, this.tester);

  final SharedPreferences preferences;
  final WidgetTester tester;
  final _FakeProfileService profileService = _FakeProfileService();

  /// Nothing behind the network. The sign-out of this app now gives the seller's token back to the server (K-12), and
  /// this phone holds the real repository, so without an adapter here that request would leave the test and reach the
  /// real host `AppConstants.baseUrl` names. It records what was sent, which is how the hand-back is read below.
  final RecordingAdapter network = RecordingAdapter();

  late final DioClient client = DioClient(
      AppConstants.baseUrl, Dio()..httpClientAdapter = network,
      loggingInterceptor: LoggingInterceptor(), sharedPreferences: preferences);
  late final _CartServiceWithoutANetwork cartService =
      _CartServiceWithoutANetwork(
    cartRepositoryInterface:
        CartRepository(dioClient: client, sharedPreferences: preferences),
  );
  late final SplashRepository shopSettings =
      SplashRepository(dioClient: client, sharedPreferences: preferences);
  late final SellerMarketChoice marketChoice =
      SellerMarketChoice(preferences, enabled: true);
  late final SellerMarketController marketController = SellerMarketController(
      marketChoice: marketChoice, onMarketSwitched: () async {});
  late final ProfileController profile =
      ProfileController(profileServiceInterface: profileService);
  late final AuthController auth = AuthController(
    authServiceInterface: AuthService(
        authRepoInterface:
            AuthRepository(dioClient: client, sharedPreferences: preferences)),
  );
  late final CartController cart =
      CartController(cartServiceInterface: cartService);
  late final CustomerController customer =
      CustomerController(cartServiceInterface: cartService);
  late final OfflineSalesController outbox = OfflineSalesController(
    cartServiceInterface: cartService,
    sharedPreferences: preferences,
    storefrontsEnabled: true,
  )..loadFromStorage();

  static Future<_Phone> start(WidgetTester tester,
      {Map<String, Object> stored = const <String, Object>{}}) async {
    SharedPreferences.setMockInitialValues(stored);
    final _Phone phone =
        _Phone._(await SharedPreferences.getInstance(), tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: <ChangeNotifierProvider<ChangeNotifier>>[
          ChangeNotifierProvider<ShopController>.value(
              value: ShopController(shopServiceInterface: _FakeShopService())),
          ChangeNotifierProvider<AuthController>.value(value: phone.auth),
          ChangeNotifierProvider<ProfileController>.value(value: phone.profile),
          ChangeNotifierProvider<CartController>.value(value: phone.cart),
          ChangeNotifierProvider<CustomerController>.value(
              value: phone.customer),
          ChangeNotifierProvider<OfflineSalesController>.value(
              value: phone.outbox),
        ],
        child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: SizedBox.shrink())),
      ),
    );

    return phone;
  }

  /// A seller signs in: the token the server issued is stored, and the profile of the new session answers with the id of that seller.
  Future<void> signIn(int sellerId, {required String token}) async {
    await preferences.setString(AppConstants.token, token);
    profileService.sellerId = sellerId;
    await profile.getSellerInfo();
  }

  /// The seller signs out, through the sign-out of the app.
  Future<void> signOut() async {
    await tester.runAsync(() => auth.clearSharedData());
  }

  /// The session ends because the server refused the credential, which is the other way the app ends one.
  Future<void> sessionRefusedByTheServer() async {
    await tester
        .runAsync(() => auth.clearSharedData(fromUnAuthorizationError: true));
  }

  /// Entering the dashboard, which is where the app reads the carts the phone has on hold back into the POS.
  void openDashboard() => cart.getCartData();

  /// Opening the POS, which makes a cart for the seller only when there is not one already, exactly as `PosScreen` does: the cart in
  /// hand is held in memory for the whole life of the app, and the screen takes the one it finds.
  void openPos() {
    if (cart.currentCartModel == null) {
      cart.initTempCartData(isUpdate: false);
    }
    cart.clearCardForCancel();
  }

  /// The seller scans a product at the counter. It goes into the cart in hand, which the phone is told nothing about until the cart is
  /// put aside for a customer or the sale is placed.
  void scan({required double priced}) => cart.currentCartModel!.cart!
      .add(CartModel(priced, 0, 1, 0, null, null, null, null, null, null));

  /// The seller picks a registered customer to ring the sale up for.
  void serveCustomer(int customerId, {required String named}) =>
      customer.setCustomerInfo(customerId, named, '0500000000', false, 0);

  /// The seller puts a cart aside for a customer, as the POS does.
  void holdCartFor(String customerName, {required int customerId}) =>
      cart.addUserCart(TemporaryCartListModel(
          userId: customerId, customerName: customerName, cart: <CartModel>[]));

  /// A sale rung up while the phone could not reach the server.
  Future<PendingPosOrder> queueSale(String key) => outbox.enqueue(
        orderBody: <String, dynamic>{
          'user_id': 0,
          'cart': <String>[key]
        },
        orderAmount: 25,
        customerName: 'Layla',
        idempotencyKey: key,
      );

  /// The market the seller who is signed in now works in.
  MarketScope get market => marketChoice.current();

  /// What the POS screen shows the seller: the price of everything in the cart in hand.
  List<double?> get cartInHand =>
      cart.currentCartModel?.cart
          ?.map((CartModel item) => item.price)
          .toList() ??
      <double?>[];

  /// The customer the POS is ringing the sale up for.
  String? get customerBeingServed => customer.customerSelectedName;

  /// The customers the POS shows a cart on hold for.
  List<String?> get cartsOnHold => cart.customerCartList
      .map((TemporaryCartListModel held) => held.customerName)
      .toList();

  /// The currency the app prices in, which is the shop's own while the phone holds no choice. This is the read the app itself makes:
  /// `SplashController.initConfig` asks the same store the same question on every start and falls back to the currency of the shop
  /// when it holds nothing. The write is the other half of a currency picker that this build does not wire up, so the test makes it.
  String get currency => shopSettings.getCurrency();

  /// The sessions this phone handed back to the server, in the order it handed them back: the token of each
  /// `POST /api/v3/seller/auth/logout` that left the device (K-12).
  List<String> get sessionsGivenBack => network.requests
      .where((RecordedRequest sent) =>
          sent.method == 'POST' && sent.uri.path == AppConstants.logoutUri)
      .map((RecordedRequest sent) => '${sent.header('authorization')}')
      .toList();

  /// Every sale the phone still holds, whoever took it.
  List<String> get queueOnTheDisk =>
      preferences.getStringList(_queueKey) ?? <String>[];

  List<PendingPosOrder> get salesOnTheDisk => queueOnTheDisk
      .map(PendingPosOrder.decode)
      .whereType<PendingPosOrder>()
      .toList();

  List<String?> get keysOnTheDisk => salesOnTheDisk
      .map((PendingPosOrder sale) => sale.idempotencyKey)
      .toList();

  List<String?> get keysSent =>
      cartService.salesSent.map((_SaleSent sale) => sale.key).toList();
}

/// A seller works: a market to sell in, a cart put aside for a customer and a currency to price in.
Future<void> _work(_Phone phone,
    {required MarketScope inMarket,
    required String forCustomer,
    required String pricedIn}) async {
  await phone.marketChoice.choose(inMarket);
  phone.holdCartFor(forCustomer, customerId: 4321);
  phone.shopSettings.setCurrency(pricedIn);
  phone.openDashboard();
}

/// K-12.4: one phone stands on the counter and more than one seller signs in to it. A second login must start clean — no market, no
/// cart and no currency of the seller before it — while the sales that could not be sent are the one thing that is kept, because they
/// are money already taken and are owed to the seller who rang them up.
///
/// Run on the real sign-out over real shared preferences in memory. Which session may send a queued sale, and the market it is replayed
/// in, are proven in test/offline_outbox_owner_test.dart and test/market_selector/queued_sale_market_test.dart; this file pins what a
/// sign-out takes off the phone, what it leaves, and what the next seller to sign in therefore finds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a sign-out', () {
    testWidgets(
        'takes the market, the cart and the currency the seller was working in, and the session with them',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'a-real-looking-session-token-value');
      await _work(phone,
          inMarket: MarketScope.kuwait, forCustomer: 'Noura', pricedIn: 'KWD');

      expect(phone.market, MarketScope.kuwait);
      expect(phone.cartsOnHold, <String?>['Noura']);
      expect(phone.currency, 'KWD');

      await phone.signOut();

      expect(phone.auth.isLoggedIn(), isFalse);
      // Forgetting the key is not revoking it: the session this phone gave up is handed back, so it ends on the server
      // too (K-12). Carried on that one request, because the client's own credential is already gone by then.
      expect(phone.sessionsGivenBack,
          <String>['Bearer a-real-looking-session-token-value']);
      expect(phone.preferences.containsKey(AppConstants.storefrontCountry),
          isFalse,
          reason:
              'the market the seller chose is not the next seller\'s market');
      expect(phone.preferences.containsKey(AppConstants.cartList), isFalse,
          reason: 'nor is the cart they put aside the next seller\'s cart');
      expect(phone.preferences.containsKey(AppConstants.currency), isFalse,
          reason:
              'nor is the currency they priced in the next seller\'s currency');
    });

    testWidgets(
        'leaves the sales that could not be sent exactly as they were, each still naming the seller who took it',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      await phone.queueSale('a-1');
      await phone.queueSale('a-2');
      final List<String> queuedBefore = phone.queueOnTheDisk;

      await phone.signOut();

      expect(phone.queueOnTheDisk, queuedBefore,
          reason: 'money already taken is not thrown away with the session');
      expect(phone.salesOnTheDisk.map((PendingPosOrder sale) => sale.sellerId),
          <String?>['$_idOfTheFirstSeller', '$_idOfTheFirstSeller']);
    });

    testWidgets(
        'takes the cart in hand with it, and not only the carts put aside for customers',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      phone.openPos();
      phone.scan(priced: 31);
      phone.scan(priced: 44);
      phone.serveCustomer(55, named: 'Fatima');

      expect(phone.cartInHand, <double?>[31, 44]);
      expect(phone.customerBeingServed, 'Fatima');

      await phone.signOut();

      expect(phone.cartInHand, isEmpty,
          reason:
              'the sale the seller was ringing up is not left on the screen to be finished by somebody else');
      expect(phone.customerBeingServed, 'Walk-In Customer',
          reason: 'nor is the customer it was being rung up for');
    });

    testWidgets(
        'takes nothing else: the email the login prefills, the language and the theme of the phone stay',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester, stored: <String, Object>{
        AppConstants.userEmail: 'first.seller@example.com',
        AppConstants.languageCode: 'ar',
        AppConstants.theme: 'dark',
      });
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      await phone.queueSale('a-1');

      await phone.signOut();

      expect(phone.auth.getUserEmail(), 'first.seller@example.com');
      expect(phone.preferences.getString(AppConstants.languageCode), 'ar');
      expect(phone.preferences.getString(AppConstants.theme), 'dark');
      expect(phone.keysOnTheDisk, <String?>['a-1']);
    });

    testWidgets(
        'has taken all four off the phone by the time it first waits, because no caller waits for it',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      await _work(phone,
          inMarket: MarketScope.kuwait, forCustomer: 'Noura', pricedIn: 'KWD');

      await tester.runAsync(() async {
        // As `ApiChecker` ends a session: the sign-out is started and nothing waits for it, while the login screen goes up and a
        // seller with their credentials prefilled can be signed back in. Whatever is left to do after the first wait would then run
        // on their session, so every removal has to be asked for before it.
        final Future<bool> signingOut = phone.auth.clearSharedData();

        expect(phone.preferences.containsKey(AppConstants.token), isFalse);
        expect(phone.preferences.containsKey(AppConstants.storefrontCountry),
            isFalse,
            reason:
                'a market removed later would be the market the next seller had just chosen');
        expect(phone.preferences.containsKey(AppConstants.cartList), isFalse,
            reason:
                'and a cart read back before the removal would be written to the phone again under the next session');
        expect(phone.preferences.containsKey(AppConstants.currency), isFalse);

        await signingOut;
      });
    });

    testWidgets(
        'that an unauthorized answer forces takes the same three, and keeps the sales in the same way',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'a-token-the-server-has-stopped-accepting');
      await _work(phone,
          inMarket: MarketScope.qatar, forCustomer: 'Noura', pricedIn: 'QAR');
      await phone.queueSale('a-1');

      await phone.sessionRefusedByTheServer();

      expect(phone.preferences.containsKey(AppConstants.storefrontCountry),
          isFalse);
      expect(phone.preferences.containsKey(AppConstants.cartList), isFalse);
      expect(phone.preferences.containsKey(AppConstants.currency), isFalse);
      expect(phone.keysOnTheDisk, <String?>['a-1'],
          reason: 'a refused credential is no reason to lose a sale');
      // Nothing is handed back: that token is already refused, the route would answer the same 401 that brought us
      // here, and `ApiChecker` runs this sign-out from inside the handler for that 401.
      expect(phone.sessionsGivenBack, isEmpty);
    });
  });

  group('the second seller to sign in on the same phone', () {
    testWidgets(
        'starts in no market, with no cart on hold and in the currency of the shop',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      await _work(phone,
          inMarket: MarketScope.kuwait, forCustomer: 'Noura', pricedIn: 'KWD');
      await phone.signOut();

      await phone.signIn(_idOfTheSecondSeller,
          token: 'token-of-the-second-seller');
      phone.openDashboard();

      expect(phone.market, MarketScope.defaultScope,
          reason:
              'the second seller is in Saudi Arabia until they choose a market, not in the first seller\'s Kuwait');
      expect(phone.cartsOnHold, isEmpty,
          reason:
              'the cart the first seller put aside is not on the second seller\'s screen');
      expect(phone.currency, isEmpty,
          reason:
              'and the prices are the shop\'s own again, not the first seller\'s Kuwaiti dinar');
    });

    testWidgets(
        'opens the POS on an empty cart, and so cannot place the sale the first seller was ringing up',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      phone.openPos();
      phone.scan(priced: 31);
      phone.serveCustomer(55, named: 'Fatima');
      await phone.signOut();

      await phone.signIn(_idOfTheSecondSeller,
          token: 'token-of-the-second-seller');
      phone.openDashboard();
      phone.openPos();

      expect(phone.cartInHand, isEmpty,
          reason:
              'the cart controller is made once for the app and outlives the sign-out, so the second seller would otherwise find the first seller\'s items priced on the screen');
      expect(phone.customerBeingServed, 'Walk-In Customer');
      expect(phone.cartsOnHold, isEmpty);
    });

    testWidgets(
        'is labelled with their own market, although the one controller of the app has not been built again',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');

      expect(phone.marketController.market, MarketScope.defaultScope,
          reason: 'the controller is made once, before anyone has chosen');

      await phone.marketController.choose(MarketScope.kuwait);

      expect(phone.marketController.market, MarketScope.kuwait);

      await phone.signOut();
      await phone.signIn(_idOfTheSecondSeller,
          token: 'token-of-the-second-seller');

      expect(phone.marketController.market, MarketScope.defaultScope,
          reason:
              'the screens cannot be labelled Kuwait while their requests are sent to Saudi Arabia');
    });

    testWidgets(
        'sees none of the first seller\'s unsent sales and sends none of them, and they stay on the phone',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      await phone.queueSale('a-1');
      await phone.queueSale('a-2');
      await phone.signOut();

      await phone.signIn(_idOfTheSecondSeller,
          token: 'token-of-the-second-seller');

      expect(phone.outbox.pending, isEmpty);
      expect(phone.outbox.pendingCount, 0);
      expect(phone.outbox.hasPending, isFalse);
      expect(phone.outbox.failedCount, 0);
      expect(await phone.outbox.syncPending(), 0);
      expect(phone.keysSent, isEmpty,
          reason:
              'sent now, the server would record the money the first seller took under the second');
      expect(phone.keysOnTheDisk, <String?>['a-1', 'a-2'],
          reason:
              'and they are not destroyed by the seller they do not belong to');
    });

    testWidgets(
        'cannot empty, retry or remove them either, and the first seller signing back in still has them and sends them',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      await phone.queueSale('a-1');
      await phone.queueSale('a-2');
      await phone.signOut();
      await phone.signIn(_idOfTheSecondSeller,
          token: 'token-of-the-second-seller');

      expect(phone.keysOnTheDisk, <String?>['a-1', 'a-2'],
          reason: 'the sign-out left them for their seller');

      await phone.outbox.clear();
      await phone.outbox.retryFailedSales();
      for (final PendingPosOrder sale in phone.salesOnTheDisk) {
        await phone.outbox.remove(sale.id);
      }

      expect(phone.keysOnTheDisk, <String?>['a-1', 'a-2']);

      await phone.signOut();
      await phone.signIn(_idOfTheFirstSeller,
          token: 'another-token-of-the-first-seller');

      expect(
          phone.outbox.pending
              .map((PendingPosOrder sale) => sale.idempotencyKey),
          <String?>['a-1', 'a-2'],
          reason: 'they were waiting for their own seller all along');
      expect(await phone.outbox.syncPending(), 2);
      expect(phone.keysSent, <String?>['a-1', 'a-2']);
      expect(phone.keysOnTheDisk, isEmpty,
          reason: 'and once the server has them the phone lets them go');
    });

    testWidgets(
        'does not inherit the market even for a sale of their own: the sale they ring up names the market they are in',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      await phone.marketChoice.choose(MarketScope.kuwait);
      await phone.queueSale('a-1');
      await phone.signOut();
      await phone.signIn(_idOfTheSecondSeller,
          token: 'token-of-the-second-seller');

      await phone.queueSale('b-1');

      expect(
          phone.salesOnTheDisk.map((PendingPosOrder sale) => sale.storefront),
          <String?>['KW', MarketScope.defaultScope.countryCode],
          reason:
              'the first sale is owed to Kuwait, the second to the market the second seller is in');
    });

    testWidgets(
        'and the sale the first seller left is still replayed in the market it was taken in, although the phone no longer holds that market',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      await phone.marketChoice.choose(MarketScope.kuwait);
      await phone.queueSale('a-1');
      await phone.signOut();
      await phone.signIn(_idOfTheSecondSeller,
          token: 'token-of-the-second-seller');
      await phone.signOut();
      await phone.signIn(_idOfTheFirstSeller,
          token: 'another-token-of-the-first-seller');

      expect(phone.market, MarketScope.defaultScope,
          reason: 'the chosen market did not survive either sign-out');
      expect(await phone.outbox.syncPending(), 1);
      expect(phone.cartService.salesSent.single.market, 'KW',
          reason:
              'the sale carries its own market, and the cleared choice does not rewrite it');
    });
  });

  group('one seller alone on the phone', () {
    testWidgets(
        'signs out and in again and finds their unsent sales where they left them, cart and market started afresh',
        (WidgetTester tester) async {
      final _Phone phone = await _Phone.start(tester);
      await phone.signIn(_idOfTheFirstSeller,
          token: 'token-of-the-first-seller');
      await _work(phone,
          inMarket: MarketScope.kuwait, forCustomer: 'Noura', pricedIn: 'KWD');
      await phone.queueSale('a-1');

      await phone.signOut();
      await phone.signIn(_idOfTheFirstSeller,
          token: 'another-token-of-the-first-seller');
      phone.openDashboard();

      expect(
          phone.outbox.pending
              .map((PendingPosOrder sale) => sale.idempotencyKey),
          <String?>['a-1']);
      expect(phone.cartsOnHold, isEmpty);
      expect(phone.market, MarketScope.defaultScope);
      expect(phone.currency, isEmpty);
    });
  });
}
