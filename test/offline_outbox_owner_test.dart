import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/data/model/response/response_model.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/repositories/auth_repository.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/services/auth_service.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/offline_sales_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/failed_sales_sheet.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/offline_sales_banner.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/services/profice_service_interface.dart';
import 'package:syriacosmeticsmanger/features/shop/controllers/shop_controller.dart';
import 'package:syriacosmeticsmanger/features/shop/domain/services/shop_service_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

const String _storageKey = 'offline_pos_orders';
const String _sellerA = 'seller-a';
const String _sellerB = 'seller-b';
const int _idOfA = 7;
const int _idOfB = 9;

ApiResponse _placed(int orderId) => ApiResponse.withSuccess(Response<dynamic>(requestOptions: RequestOptions(path: '/'), statusCode: 200, data: <String, dynamic>{'order_id': orderId}));

ApiResponse _failed(String reason) => ApiResponse.withError(reason);

/// A sale the way the queue holds it: its id and its key are the same word, which is also what its body lists as its cart, so a test can say which sale a request carried.
PendingPosOrder _sale(String key, {String? seller, int attempts = 0, String? lastError, String customer = 'Layla'}) => PendingPosOrder(
      id: key,
      body: <String, dynamic>{'user_id': 0, 'cart': <String>[key]},
      createdAt: DateTime(2026, 11, 18, 10),
      orderAmount: 25,
      customerName: customer,
      attempts: attempts,
      lastError: lastError,
      idempotencyKey: key,
      sellerId: seller,
    );

/// A sale the way an earlier version wrote it: no seller, and no key either.
String _legacyRecord(String key) => jsonEncode(_sale(key).toJson()..remove('seller_id')..remove('idempotency_key'));

class _Call {
  _Call(this.body, this.key);

  final Map<String, dynamic> body;
  final String? key;

  String get sale => (body['cart'] as List<dynamic>).single as String;
}

class _FakeCartService implements CartServiceInterface {
  final List<_Call> calls = <_Call>[];

  /// The answer to a replay; it may wait for something (a held connection) before it answers.
  Future<ApiResponse> Function(Map<String, dynamic> body, String? key) answer = (Map<String, dynamic> body, String? key) async => _placed(1);

  @override
  Future<dynamic> placeOrderRaw(Map<String, dynamic> orderBody, {String? idempotencyKey}) {
    calls.add(_Call(orderBody, idempotencyKey));

    return answer(orderBody, idempotencyKey);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeShopService implements ShopServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The profile of the seller, as the server answers it: for the session that asked, whenever the answer is let through.
class _FakeProfileService implements ProfileServiceInterface {
  int? sellerId;

  /// While set, an answer waits for it, like a request that is still on its way.
  Completer<void>? onItsWay;

  @override
  Future<dynamic> getSellerInfo() async {
    final int? sellerAsked = sellerId;
    await onItsWay?.future;

    return ApiResponse.withSuccess(Response<dynamic>(requestOptions: RequestOptions(path: '/'), statusCode: 200, data: <String, dynamic>{'id': sellerAsked, 'pos_status': 1}));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A device with the outbox of the app on it: its disk, the server it sends to, and the sales that a test rings up.
abstract class _Terminal {
  _Terminal(this.preferences);

  final SharedPreferences preferences;
  final _FakeCartService service = _FakeCartService();

  OfflineSalesController get controller;

  /// A sale rung up while the connection was down, by whoever is signed in.
  Future<PendingPosOrder> queueSale(String key, {String customer = 'Layla'}) => controller.enqueue(
        orderBody: <String, dynamic>{'user_id': 0, 'cart': <String>[key]},
        orderAmount: 25,
        customerName: customer,
        idempotencyKey: key,
      );

  /// What the disk holds, whoever is signed in.
  List<PendingPosOrder> get stored => (preferences.getStringList(_storageKey) ?? <String>[]).map(PendingPosOrder.decode).whereType<PendingPosOrder>().toList();

  List<String?> get storedKeys => stored.map((PendingPosOrder sale) => sale.idempotencyKey).toList();

  List<String> get sentSales => service.calls.map((_Call call) => call.sale).toList();
}

/// One device: one disk, one server, and whoever is signed in on it, which a test says at once. Starting the app again is a new controller reading the same disk.
class _Device extends _Terminal {
  _Device(super.preferences) {
    start();
  }

  bool hasSession = false;
  String? sellerId;

  @override
  late OfflineSalesController controller;

  void start() {
    controller = OfflineSalesController(cartServiceInterface: service, sharedPreferences: preferences, hasSession: () => hasSession, signedInSellerId: () => sellerId)..loadFromStorage();
  }

  void signIn(String seller) {
    hasSession = true;
    sellerId = seller;
  }

  void signOut() {
    hasSession = false;
    sellerId = null;
  }
}

/// The app as far as the outbox can see it, with only the network faked: the real sign-out, the real profile and the real outbox with its own readers, which find the session and the profile through the
/// navigator as the app does, over real preferences in memory. The session is the token in the preferences, as in the app; the seller is whoever the profile answers for, which it does after the session
/// exists, and which a sign-out forgets.
class _App extends _Terminal {
  _App._(super.preferences, this.tester);

  final WidgetTester tester;
  final _FakeProfileService profileService = _FakeProfileService();

  late final ProfileController profile = ProfileController(profileServiceInterface: profileService);
  late final AuthController auth = AuthController(
    authServiceInterface: AuthService(
      authRepoInterface: AuthRepository(
        dioClient: DioClient(AppConstants.baseUrl, Dio(), loggingInterceptor: LoggingInterceptor(), sharedPreferences: preferences),
        sharedPreferences: preferences,
      ),
    ),
  );

  @override
  late final OfflineSalesController controller = OfflineSalesController(cartServiceInterface: service, sharedPreferences: preferences)..loadFromStorage();

  static Future<_App> start(WidgetTester tester, {List<String> records = const <String>[], Widget child = const SizedBox.shrink()}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{_storageKey: records});
    final _App app = _App._(await SharedPreferences.getInstance(), tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: <ChangeNotifierProvider<ChangeNotifier>>[
          ChangeNotifierProvider<ShopController>.value(value: ShopController(shopServiceInterface: _FakeShopService())),
          ChangeNotifierProvider<AuthController>.value(value: app.auth),
          ChangeNotifierProvider<ProfileController>.value(value: app.profile),
          ChangeNotifierProvider<OfflineSalesController>.value(value: app.controller),
        ],
        child: MaterialApp(navigatorKey: navigatorKey, home: Scaffold(body: child)),
      ),
    );

    return app;
  }

  /// The login stores the token the server issued; the profile of the seller is not known yet.
  Future<void> logIn(String token) => preferences.setString(AppConstants.token, token);

  /// The server answers seller-info for the session that asks, and the app hears it.
  Future<ResponseModel> profileAnswers(int sellerId) {
    profileService.sellerId = sellerId;

    return profile.getSellerInfo();
  }

  Future<void> signOut() async {
    await tester.runAsync(() => auth.clearSharedData());
  }
}

Future<_Device> _device({List<String> records = const <String>[], String? signedIn}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{_storageKey: records});
  final _Device device = _Device(await SharedPreferences.getInstance());
  if (signedIn != null) {
    device.signIn(signedIn);
  }

  return device;
}

String _record(PendingPosOrder sale) => sale.encode();

/// What a seller who signs in after seller A does with the sales on the device: sees none of them, and can send, retry, remove or clear none of them. None leaves the disk, none is sent and none is touched.
Future<void> _expectSalesOfSellerAUntouchedAndUnseen(_App app) async {
  final OfflineSalesController outbox = app.controller;
  final List<PendingPosOrder> before = app.stored;
  expect(before, hasLength(3));

  expect(outbox.pending, isEmpty);
  expect(outbox.pendingCount, 0);
  expect(outbox.hasPending, isFalse);
  expect(outbox.failedSales, isEmpty);
  expect(outbox.failedCount, 0);
  expect(await outbox.syncPending(), 0);
  expect(await outbox.retryFailedSales(), 0);
  for (final PendingPosOrder sale in before) {
    await outbox.remove(sale.id);
  }
  await outbox.clear();

  expect(app.service.calls, isEmpty, reason: 'sent now, the server would record the money A took under another seller');
  expect(app.storedKeys, <String?>['a-f', 'a-1', 'a-2']);
  expect(app.stored.map((PendingPosOrder sale) => sale.sellerId), <String?>['$_idOfA', '$_idOfA', '$_idOfA']);
  expect(app.stored.map((PendingPosOrder sale) => sale.attempts), <int>[10, 0, 0], reason: 'no attempt was counted against them, and the failed one was not given its attempts back');
  expect(app.stored.first.lastError, 'refused by the server');
}

Widget _app(OfflineSalesController controller, Widget child) => MaterialApp(
      home: Scaffold(body: ChangeNotifierProvider<OfflineSalesController>.value(value: controller, child: child)),
    );

String _amountText(BuildContext context, double amount) => 'SAR ${amount.toStringAsFixed(2)}';

/// K-06.2, the seller half: the queue of sales that could not be sent is one list on the device and it outlives a sign-out, while the server records a replayed sale under the seller of the session that
/// sends it. A sale is therefore sent only by the seller who took it, it is never counted, failed or removed by another seller, and a sign-out never deletes it. Run on the real controller, with
/// real shared preferences in memory and a server that answers as it does. The groups before "in the app" say who is signed in through a function that changes at once, which proves the logic of the
/// controller; the groups from "in the app" on run the real sign-out, the real profile and the readers of the outbox itself, which proves that the seller is the one of the session. The market half needs
/// the market choice of pull request 2 and is not covered here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a sale carries the seller who took it', () {
    test('through the disk, a failed replay and the key it is given', () {
      final PendingPosOrder sale = _sale('a-1', seller: _sellerA);

      expect(PendingPosOrder.decode(sale.encode())!.sellerId, _sellerA);
      expect(sale.copyWith(attempts: 3, lastError: 'timeout', idempotencyKey: 'another-key').sellerId, _sellerA);
    });

    test('and one an earlier version wrote has none', () {
      expect(PendingPosOrder.decode(_legacyRecord('old'))!.sellerId, isNull);
    });

    test('belongs to its seller, to no other, and when it has none to whoever is signed in', () {
      final PendingPosOrder owned = _sale('a-1', seller: _sellerA);
      final PendingPosOrder legacy = _sale('old');

      expect(owned.belongsTo(_sellerA), isTrue);
      expect(owned.belongsTo(_sellerB), isFalse);
      expect(owned.belongsTo(null), isFalse, reason: 'when the app does not know who is signed in, it cannot say that the sale is theirs');
      expect(legacy.belongsTo(_sellerA), isTrue);
      expect(legacy.belongsTo(_sellerB), isTrue);
      expect(legacy.belongsTo(null), isTrue, reason: 'so that no sale an earlier version queued is stranded');
    });
  });

  group('a sale is queued under the seller who is signed in', () {
    test('and the sale and the disk both name that seller', () async {
      final _Device device = await _device(signedIn: _sellerA);

      final PendingPosOrder sale = await device.queueSale('a-1');

      expect(sale.sellerId, _sellerA);
      expect(device.stored.single.sellerId, _sellerA);
    });

    test('so one queue on one device holds the sales of two sellers, each under its own', () async {
      final _Device device = await _device(signedIn: _sellerA);
      await device.queueSale('a-1');
      device.signOut();
      device.signIn(_sellerB);
      await device.queueSale('b-1');

      expect(device.stored.map((PendingPosOrder sale) => sale.sellerId), <String?>[_sellerA, _sellerB]);
    });

    test('and while the app does not know who is signed in it is queued all the same, with no seller', () async {
      final _Device device = await _device();
      device.hasSession = true;

      await device.queueSale('first');

      expect(device.stored.single.sellerId, isNull, reason: 'a sale is the only record of the money taken at the counter: it is never refused for want of a name');
      expect(device.controller.pending, hasLength(1));
    });
  });

  group('when the connection returns', () {
    test('what seller A queued offline is not sent under seller B, stays on the disk untouched, and B sees none of it', () async {
      final _Device device = await _device(signedIn: _sellerA);
      await device.queueSale('a-1');
      await device.queueSale('a-2');
      device.signOut();
      device.signIn(_sellerB);

      final int synced = await device.controller.syncPending();

      expect(synced, 0);
      expect(device.service.calls, isEmpty, reason: 'sent now, the server would record the money A took under B');
      expect(device.storedKeys, <String?>['a-1', 'a-2'], reason: 'they are still on the disk');
      expect(device.stored.map((PendingPosOrder sale) => sale.attempts), <int>[0, 0], reason: 'no attempt was counted against them');
      expect(device.stored.map((PendingPosOrder sale) => sale.lastError), <String?>[null, null], reason: 'and no failure was written on them');
      expect(device.stored.map((PendingPosOrder sale) => sale.sellerId), <String?>[_sellerA, _sellerA]);
      expect(device.controller.pending, isEmpty);
      expect(device.controller.pendingCount, 0);
      expect(device.controller.hasPending, isFalse);
      expect(device.controller.failedSales, isEmpty);
      expect(device.controller.failedCount, 0);
    });

    test('B queues a sale and A signs in again: A\'s two sales go, each under its own key, and B\'s does not; B\'s goes when B signs in', () async {
      final _Device device = await _device(signedIn: _sellerA);
      await device.queueSale('a-1');
      await device.queueSale('a-2');
      device.signIn(_sellerB);
      await device.queueSale('b-1');
      device.signIn(_sellerA);

      final int syncedForA = await device.controller.syncPending();

      expect(syncedForA, 2);
      expect(device.service.calls.map((_Call call) => call.key), <String?>['a-1', 'a-2']);
      expect(device.storedKeys, <String?>['b-1'], reason: 'B\'s sale is still the only record of B\'s money');
      expect(device.stored.single.attempts, 0, reason: 'no attempt was counted against it while A\'s sales were sent');
      expect(device.stored.single.lastError, isNull);
      expect(device.controller.pending, isEmpty, reason: 'and A does not see it');

      device.signIn(_sellerB);
      final int syncedForB = await device.controller.syncPending();

      expect(syncedForB, 1);
      expect(device.sentSales, <String>['a-1', 'a-2', 'b-1']);
      expect(device.storedKeys, isEmpty);
    });

    test('through the watch the app keeps on the connection: its return sends the sales of the seller who is signed in and not those of another seller', () async {
      const EventChannel connectivityChannel = EventChannel('dev.fluttercommunity.plus/connectivity_status');
      late MockStreamHandlerEventSink connection;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        connectivityChannel,
        MockStreamHandler.inline(onListen: (Object? arguments, MockStreamHandlerEventSink sink) => connection = sink),
      );
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(connectivityChannel, null));
      final _Device device = await _device(signedIn: _sellerA);
      await device.queueSale('a-1');
      device.signIn(_sellerB);
      device.controller.initialise();
      await pumpEventQueue();

      connection.success(<String>['none']);
      await pumpEventQueue();
      connection.success(<String>['wifi']);
      await pumpEventQueue();

      expect(device.service.calls, isEmpty, reason: 'the connection came back for B, whose outbox is empty');
      expect(device.storedKeys, <String?>['a-1']);

      device.signIn(_sellerA);
      connection.success(<String>['none']);
      await pumpEventQueue();
      connection.success(<String>['wifi']);
      await pumpEventQueue();

      expect(device.sentSales, <String>['a-1'], reason: 'the connection came back for A, whose sale is waiting');
      expect(device.storedKeys, isEmpty);
    });

    test('the sales are still the first seller\'s after the app has started again on the same disk', () async {
      final _Device device = await _device(signedIn: _sellerA);
      await device.queueSale('a-1');
      await device.queueSale('a-2');
      device.signOut();
      device.start();
      device.signIn(_sellerB);

      await device.controller.syncPending();

      expect(device.service.calls, isEmpty);
      expect(device.controller.pending, isEmpty);

      device.signIn(_sellerA);

      expect(device.controller.pending.map((PendingPosOrder sale) => sale.idempotencyKey), <String?>['a-1', 'a-2']);
      expect(await device.controller.syncPending(), 2);
    });

    test('a replay that failed leaves the sale its seller\'s, so that another seller does not send it later', () async {
      final _Device device = await _device(signedIn: _sellerA);
      await device.queueSale('a-1');
      device.service.answer = (Map<String, dynamic> body, String? key) async => _failed('Internal server error');
      await device.controller.syncPending();
      device.signIn(_sellerB);
      device.service.answer = (Map<String, dynamic> body, String? key) async => _placed(2);

      await device.controller.syncPending();

      expect(device.stored.single.attempts, 1);
      expect(device.stored.single.sellerId, _sellerA);
      expect(device.service.calls, hasLength(1), reason: 'only the replay that failed under A was sent');
    });

    test('another seller signs in while the replay is on its way: the sales still waiting are not sent under the new session', () async {
      final _Device device = await _device(records: <String>[_record(_sale('a-1', seller: _sellerA)), _record(_sale('a-2', seller: _sellerA)), _record(_sale('a-3', seller: _sellerA))], signedIn: _sellerA);
      final Completer<void> connection = Completer<void>();
      device.service.answer = (Map<String, dynamic> body, String? key) async {
        await connection.future;

        return _placed(5);
      };

      final Future<int> replaying = device.controller.syncPending();
      await pumpEventQueue();
      device.signIn(_sellerB);
      connection.complete();
      final int synced = await replaying;

      expect(synced, 1);
      expect(device.sentSales, <String>['a-1'], reason: 'the first sale left before B signed in; the others are A\'s and the session is B\'s now');
      expect(device.storedKeys, <String?>['a-2', 'a-3']);
    });

    test('a sale of another seller that has already failed is not sent, not counted again and not listed as a failure of this seller', () async {
      final _Device device = await _device(records: <String>[_record(_sale('a-f', seller: _sellerA, attempts: 10, lastError: 'refused by the server'))], signedIn: _sellerB);

      await device.controller.syncPending();

      expect(device.service.calls, isEmpty);
      expect(device.stored.single.attempts, 10);
      expect(device.stored.single.lastError, 'refused by the server');
      expect(device.controller.failedSales, isEmpty);
      expect(device.controller.failedCount, 0);
    });
  });

  group('a sale an earlier version queued', () {
    for (final MapEntry<String, List<String>> signIn in <String, List<String>>{
      _sellerA: <String>['old', 'a-1'],
      _sellerB: <String>['old', 'b-1'],
    }.entries) {
      test('is sent by whoever is signed in, with the sales of that seller and not those of the other: ${signIn.key}', () async {
        final _Device device = await _device(
          records: <String>[_legacyRecord('old'), _record(_sale('a-1', seller: _sellerA)), _record(_sale('b-1', seller: _sellerB))],
          signedIn: signIn.key,
        );

        final int synced = await device.controller.syncPending();

        expect(synced, 2);
        expect(device.sentSales, signIn.value);
        expect(device.service.calls.first.key, isNotNull, reason: 'it is given its key before it is sent, as before');
        expect(device.stored.map((PendingPosOrder sale) => sale.sellerId), <String?>[signIn.key == _sellerA ? _sellerB : _sellerA]);
      });
    }

    test('is listed and counted for whoever is signed in', () async {
      final _Device device = await _device(records: <String>[_legacyRecord('old')], signedIn: _sellerA);

      expect(device.controller.pendingCount, 1);
      device.signIn(_sellerB);
      expect(device.controller.pendingCount, 1);
      expect(device.controller.hasPending, isTrue);
    });

    test('is sent while the app does not know who is signed in, and a sale of a seller is kept until it does', () async {
      final _Device device = await _device(records: <String>[_record(_sale('a-1', seller: _sellerA)), _legacyRecord('old')]);
      device.hasSession = true;

      final int synced = await device.controller.syncPending();

      expect(synced, 1);
      expect(device.sentSales, <String>['old']);
      expect(device.storedKeys, <String?>['a-1']);

      device.signIn(_sellerA);

      expect(await device.controller.syncPending(), 1);
      expect(device.sentSales, <String>['old', 'a-1']);
    });
  });

  group('the lists and counts of the signed-in seller', () {
    test('follow whoever is signed in, and show a sale of another seller to no one else', () async {
      final _Device device = await _device(records: <String>[
        _record(_sale('a-f', seller: _sellerA, attempts: 10, lastError: 'refused')),
        _record(_sale('a-w', seller: _sellerA, attempts: 1)),
        _record(_sale('b-w', seller: _sellerB)),
        _legacyRecord('old'),
      ]);

      device.signIn(_sellerA);
      expect(device.controller.pending.map((PendingPosOrder sale) => sale.id), <String>['a-f', 'a-w', 'old']);
      expect(device.controller.pendingCount, 3);
      expect(device.controller.failedSales.map((PendingPosOrder sale) => sale.id), <String>['a-f']);
      expect(device.controller.failedCount, 1);

      device.signIn(_sellerB);
      expect(device.controller.pending.map((PendingPosOrder sale) => sale.id), <String>['b-w', 'old']);
      expect(device.controller.pendingCount, 2);
      expect(device.controller.hasPending, isTrue);
      expect(device.controller.failedSales, isEmpty);
      expect(device.controller.failedCount, 0);

      device.sellerId = null;
      expect(device.controller.pending.map((PendingPosOrder sale) => sale.id), <String>['old'], reason: 'when the app does not know who is signed in, the sales of a seller are out of sight');
      expect(device.controller.pendingCount, 1);
      expect(device.controller.failedCount, 0);
      expect(device.stored, hasLength(4), reason: 'and all four are on the disk');
    });
  });

  group('the seller retries, removes or clears', () {
    test('a retry gives their failed sales their attempts back and sends them, and leaves the failed sales of another seller as they were', () async {
      final _Device device = await _device(
        records: <String>[
          _record(_sale('a-f', seller: _sellerA, attempts: 10, lastError: 'refused by the server')),
          _record(_sale('b-f', seller: _sellerB, attempts: 10, lastError: 'refused by the server')),
        ],
        signedIn: _sellerB,
      );

      final int synced = await device.controller.retryFailedSales();

      expect(synced, 1);
      expect(device.sentSales, <String>['b-f']);
      expect(device.stored.single.idempotencyKey, 'a-f');
      expect(device.stored.single.attempts, 10, reason: 'its attempts were not given back: it is still a sale that could not be sent, for A to retry or remove');
      expect(device.stored.single.lastError, 'refused by the server');

      device.signIn(_sellerA);

      expect(device.controller.failedCount, 1, reason: 'and A still sees it as a sale that could not be sent');
    });

    test('removing a sale by its id removes it only when it is the signed-in seller\'s', () async {
      final _Device device = await _device(
        records: <String>[_record(_sale('a-f', seller: _sellerA, attempts: 10)), _record(_sale('b-f', seller: _sellerB, attempts: 10))],
        signedIn: _sellerB,
      );

      await device.controller.remove('a-f');

      expect(device.storedKeys, <String?>['a-f', 'b-f'], reason: 'the id of A\'s sale removes nothing when B asks');

      await device.controller.remove('b-f');

      expect(device.storedKeys, <String?>['a-f']);
    });

    test('emptying the queue empties the signed-in seller\'s sales and leaves the others', () async {
      final _Device device = await _device(
        records: <String>[_record(_sale('a-1', seller: _sellerA)), _record(_sale('b-1', seller: _sellerB)), _legacyRecord('old')],
        signedIn: _sellerB,
      );

      await device.controller.clear();

      expect(device.stored.map((PendingPosOrder sale) => sale.sellerId), <String?>[_sellerA]);
    });
  });

  group('the banner above the POS and the sheet of the sales that could not be sent', () {
    testWidgets('the banner counts the sales of the seller who is signed in, and says nothing to a seller who has none', (WidgetTester tester) async {
      final _Device device = await _device(
        records: <String>[
          _record(_sale('a-f', seller: _sellerA, attempts: 10, lastError: 'refused')),
          _record(_sale('a-w', seller: _sellerA, attempts: 1)),
          _record(_sale('b-w', seller: _sellerB)),
        ],
        signedIn: _sellerA,
      );

      await tester.pumpWidget(_app(device.controller, const OfflineSalesBanner()));

      expect(find.textContaining('unsynced_sales: 2'), findsOneWidget);
      expect(find.textContaining('sales_not_sent: 1'), findsOneWidget);
      expect(find.text('details'), findsOneWidget);

      device.signIn(_sellerB);
      device.controller.loadFromStorage();
      await tester.pump();

      expect(find.textContaining('unsynced_sales: 1'), findsOneWidget);
      expect(find.textContaining('sales_not_sent'), findsNothing, reason: 'the sale A could not send is not a failure of B');
      expect(find.text('details'), findsNothing);

      device.signIn('seller-c');
      device.controller.loadFromStorage();
      await tester.pump();

      expect(find.textContaining('unsynced_sales'), findsNothing);
      expect(find.text('retry'), findsNothing);
    });

    testWidgets('the sheet lists the failed sales of the seller who is signed in and none of another seller\'s, and its Retry sends only theirs', (WidgetTester tester) async {
      final _Device device = await _device(
        records: <String>[
          _record(_sale('a-f', seller: _sellerA, attempts: 10, lastError: 'refused by the server', customer: 'Layla')),
          _record(_sale('b-f', seller: _sellerB, attempts: 10, lastError: 'refused by the server', customer: 'Omar')),
        ],
        signedIn: _sellerB,
      );

      await tester.pumpWidget(_app(device.controller, const FailedSalesSheet(formatAmount: _amountText)));

      expect(find.textContaining('Omar · SAR 25.00'), findsOneWidget);
      expect(find.textContaining('Layla'), findsNothing);

      await tester.tap(find.text('retry'));
      await tester.pumpAndSettle();

      expect(device.sentSales, <String>['b-f']);
      expect(device.stored.single.idempotencyKey, 'a-f');
      expect(device.stored.single.attempts, 10);
    });
  });

  group('in the app, with the real sign-out, the real profile and the readers of the outbox itself', () {
    testWidgets('the seller of a sale is the one the profile names, and a sale rung up before it has answered is given that seller when it does', (WidgetTester tester) async {
      final _App app = await _App.start(tester);
      await app.logIn('token-of-a');

      final PendingPosOrder beforeTheAnswer = await app.queueSale('before');
      await app.profileAnswers(_idOfA);
      final PendingPosOrder afterTheAnswer = await app.queueSale('after');

      expect(beforeTheAnswer.sellerId, isNull, reason: 'the app did not know who was signed in when it was rung up');
      expect(afterTheAnswer.sellerId, '$_idOfA');
      expect(app.stored.map((PendingPosOrder sale) => sale.sellerId), <String?>['$_idOfA', '$_idOfA'], reason: 'the first was given its seller, on the disk as well');
      expect(app.controller.pending.map((PendingPosOrder sale) => sale.idempotencyKey), <String?>['before', 'after']);
    });

    testWidgets('a seller who signs in after another does not see, send, retry, remove or clear the first seller\'s sales, before their own profile has answered or after', (WidgetTester tester) async {
      final _App app = await _App.start(tester, records: <String>[_record(_sale('a-f', seller: '$_idOfA', attempts: 10, lastError: 'refused by the server'))]);
      await app.logIn('token-of-a');
      await app.profileAnswers(_idOfA);
      await app.queueSale('a-1');
      await app.queueSale('a-2');
      await app.signOut();
      await app.logIn('token-of-b');

      await _expectSalesOfSellerAUntouchedAndUnseen(app);

      await app.profileAnswers(_idOfB);

      await _expectSalesOfSellerAUntouchedAndUnseen(app);

      await app.signOut();
      await app.logIn('token-of-a-again');
      await app.profileAnswers(_idOfA);

      expect(app.controller.pending.map((PendingPosOrder sale) => sale.idempotencyKey), <String?>['a-f', 'a-1', 'a-2'], reason: 'they are A\'s again when A signs in');
      expect(app.controller.failedCount, 1);
      expect(await app.controller.syncPending(), 2);
      expect(app.service.calls.map((_Call call) => call.key), <String?>['a-1', 'a-2'], reason: 'each under the key it was queued with');
      expect(app.storedKeys, <String?>['a-f']);
    });

    testWidgets('a sale B rings up before B\'s profile has answered is B\'s: A signing in again does not send it, and B signing in again does', (WidgetTester tester) async {
      final _App app = await _App.start(tester);
      await app.logIn('token-of-a');
      await app.profileAnswers(_idOfA);
      await app.queueSale('a-1');
      await app.queueSale('a-2');
      await app.signOut();
      await app.logIn('token-of-b');

      final PendingPosOrder rungUp = await app.queueSale('b-1');

      expect(rungUp.sellerId, isNull, reason: 'the profile of B has not answered, and the profile of A is gone');
      expect(app.controller.pending.map((PendingPosOrder sale) => sale.idempotencyKey), <String?>['b-1'], reason: 'B sees their own sale at once, and not A\'s');

      await app.profileAnswers(_idOfB);

      expect(app.stored.map((PendingPosOrder sale) => sale.sellerId), <String?>['$_idOfA', '$_idOfA', '$_idOfB'], reason: 'it is B\'s on the disk too, and never A\'s');

      await app.signOut();
      await app.logIn('token-of-a-again');
      await app.profileAnswers(_idOfA);

      expect(await app.controller.syncPending(), 2);
      expect(app.service.calls.map((_Call call) => call.key), <String?>['a-1', 'a-2']);
      expect(app.storedKeys, <String?>['b-1']);

      await app.signOut();
      await app.logIn('token-of-b-again');
      await app.profileAnswers(_idOfB);

      expect(await app.controller.syncPending(), 1);
      expect(app.sentSales, <String>['a-1', 'a-2', 'b-1']);
      expect(app.storedKeys, isEmpty);
    });

    testWidgets('a sale an earlier version queued is not given a seller by the answer: it stays everyone\'s', (WidgetTester tester) async {
      final _App app = await _App.start(tester, records: <String>[_legacyRecord('old')]);
      await app.logIn('token-of-a');
      await app.queueSale('s-1');

      await app.profileAnswers(_idOfA);

      expect(app.stored.map((PendingPosOrder sale) => sale.sellerId), <String?>[null, '$_idOfA']);

      await app.signOut();
      await app.logIn('token-of-b');
      await app.profileAnswers(_idOfB);

      expect(app.controller.pending.map((PendingPosOrder sale) => sale.id), <String>['old'], reason: 'it is still the signed-in seller\'s to send, as before, and the sale of A is not');
    });

    testWidgets('a sale rung up before the profile has answered is given the seller of its own session only: the answer of the next session does not claim it', (WidgetTester tester) async {
      final _App app = await _App.start(tester);
      await app.logIn('token-of-a');
      await app.queueSale('a-1');
      await app.signOut();
      await app.logIn('token-of-b');

      await app.profileAnswers(_idOfB);

      expect(app.stored.single.sellerId, isNull, reason: 'it was not rung up in B\'s session, so B\'s answer does not say whose it is: it is left as it was, and A can still send it');

      await app.signOut();
      await app.logIn('token-of-a-again');
      await app.profileAnswers(_idOfA);

      expect(await app.controller.syncPending(), 1);
      expect(app.sentSales, <String>['a-1']);
    });

    testWidgets('an answer on its way from the session that ended does not make a seller of the next session', (WidgetTester tester) async {
      final _App app = await _App.start(tester);
      await app.logIn('token-of-a');
      await app.profileAnswers(_idOfA);
      await app.queueSale('a-1');
      final Object? modelOfA = app.profile.userInfoModel;
      app.profileService.onItsWay = Completer<void>();
      final Future<ResponseModel> asked = app.profile.getSellerInfo();

      await app.signOut();
      await app.logIn('token-of-b');
      app.profileService.onItsWay!.complete();
      final ResponseModel answer = await asked;

      expect(answer.isSuccess, isFalse, reason: 'the answer is for a session that has ended');
      expect(app.profile.userId, isNull);
      expect(app.profile.userInfoModel, same(modelOfA), reason: 'the answer was not taken in');
      expect(app.controller.pending, isEmpty, reason: 'the sale of A is not B\'s, whose own profile has not answered');
      expect(await app.controller.syncPending(), 0);
      expect(app.service.calls, isEmpty);
      expect(app.storedKeys, <String?>['a-1']);
    });

    testWidgets('a sign-out in the middle of a replay stops it: the sales still waiting are not sent under the next session', (WidgetTester tester) async {
      final _App app = await _App.start(
        tester,
        records: <String>[_record(_sale('a-1', seller: '$_idOfA')), _record(_sale('a-2', seller: '$_idOfA')), _record(_sale('a-3', seller: '$_idOfA'))],
      );
      await app.logIn('token-of-a');
      await app.profileAnswers(_idOfA);
      final Completer<void> connection = Completer<void>();
      app.service.answer = (Map<String, dynamic> body, String? key) async {
        await connection.future;

        return _placed(5);
      };

      final Future<int> replaying = app.controller.syncPending();
      await tester.pump();
      await app.signOut();
      await app.logIn('token-of-b');
      connection.complete();
      final int synced = await replaying;

      expect(synced, 1);
      expect(app.sentSales, <String>['a-1'], reason: 'the first sale was on its way when A signed out; the others are A\'s, and the profile that said so is gone');
      expect(app.storedKeys, <String?>['a-2', 'a-3']);
    });

    testWidgets('a seller given to a sale while a replay is on its way is not lost when the replay fails', (WidgetTester tester) async {
      final _App app = await _App.start(tester);
      await app.logIn('token-of-a');
      await app.queueSale('s-1');
      final Completer<void> connection = Completer<void>();
      app.service.answer = (Map<String, dynamic> body, String? key) async {
        await connection.future;

        return _failed('Internal server error');
      };

      final Future<int> replaying = app.controller.syncPending();
      await tester.pump();
      await app.profileAnswers(_idOfA);
      connection.complete();
      await replaying;

      expect(app.stored.single.sellerId, '$_idOfA');
      expect(app.stored.single.attempts, 1);
      expect(app.stored.single.lastError, 'Internal server error');
    });

    testWidgets('the banner follows the seller who is signed in by itself: it is told by the profile and by nothing else', (WidgetTester tester) async {
      final _App app = await _App.start(
        tester,
        records: <String>[_record(_sale('a-1', seller: '$_idOfA')), _record(_sale('a-2', seller: '$_idOfA')), _record(_sale('b-1', seller: '$_idOfB'))],
        child: const OfflineSalesBanner(),
      );
      await app.logIn('token-of-a');
      await app.profileAnswers(_idOfA);
      await tester.pump();

      expect(find.textContaining('unsynced_sales: 2'), findsOneWidget);

      await app.signOut();
      await app.logIn('token-of-b');
      await app.profileAnswers(_idOfB);
      await tester.pump();

      expect(find.textContaining('unsynced_sales: 1'), findsOneWidget, reason: 'the banner counts the sales of B now, and was not told by anything but the answer of B\'s profile');
    });

    testWidgets('an outbox that has been disposed no longer hears the profile', (WidgetTester tester) async {
      final _App app = await _App.start(tester);
      await app.logIn('token-of-a');
      expect(app.controller.pending, isEmpty, reason: 'the outbox has found the profile and follows it');
      app.controller.dispose();

      await app.profileAnswers(_idOfA);

      expect(app.profile.userId, _idOfA, reason: 'the answer reached the profile, and a disposed outbox that still followed it would have been told');
    });
  });

  group('a sign-out', () {
    testWidgets('ends the session and the seller it was known by, and leaves the queue on the disk and in the outbox for the seller who signs in again', (WidgetTester tester) async {
      final _App app = await _App.start(
        tester,
        records: <String>[_record(_sale('a-1', seller: '$_idOfA')), _record(_sale('a-f', seller: '$_idOfA', attempts: 10, lastError: 'refused by the server'))],
      );
      await app.logIn('a-real-looking-session-token-value');
      await app.profileAnswers(_idOfA);
      final List<String> queueBefore = app.preferences.getStringList(_storageKey)!;
      expect(app.auth.isLoggedIn(), isTrue);
      expect(app.profile.userId, _idOfA);

      await app.signOut();

      expect(app.auth.isLoggedIn(), isFalse, reason: 'the session is gone');
      expect(app.profile.userId, isNull, reason: 'and so is the seller it was known by');
      expect(app.preferences.getStringList(_storageKey), queueBefore, reason: 'and the sales are still on the disk, as they were');

      await app.logIn('another-session-token-of-the-same-seller');
      await app.profileAnswers(_idOfA);

      expect(app.controller.pending, hasLength(2), reason: 'and in the outbox');
      expect(app.controller.failedCount, 1);
    });

    testWidgets('leaves the profile to the screens of the ended session, which are still on the stack and read it', (WidgetTester tester) async {
      final _App app = await _App.start(tester);
      await app.logIn('token-of-a');
      await app.profileAnswers(_idOfA);
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => Scaffold(
            body: Consumer<ProfileController>(
              builder: (BuildContext context, ProfileController profile, Widget? child) => TextButton(
                onPressed: () {
                  Provider.of<AuthController>(context, listen: false).clearSharedData();
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (BuildContext context) => const Scaffold(body: Text('login'))), (Route<dynamic> route) => false);
                },
                child: Text('${profile.userInfoModel!.id}'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('$_idOfA'), findsOneWidget);

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'a screen that reads the profile with ! is rebuilt before its route is gone, and a profile that was emptied under it would break it');
      expect(find.text('login'), findsOneWidget);
    });

    test('the code that ends the session names neither the queue nor the whole of the preferences', () {
      for (final String path in <String>[
        'lib/features/auth/controllers/auth_controller.dart',
        'lib/features/auth/domain/services/auth_service.dart',
        'lib/features/auth/domain/repositories/auth_repository.dart',
        'lib/features/menu/widgets/sign_out_confirmation_dialog_widget.dart',
        'lib/helper/api_checker.dart',
        'lib/data/datasource/local/secure_credential_store.dart',
      ]) {
        final String code = File(path).readAsStringSync();

        expect(code, isNot(contains('offline_pos_orders')), reason: path);
        expect(code, isNot(contains('OfflineSalesController')), reason: path);
        expect(RegExp(r'[pP]references[!?]?\.clear\(').hasMatch(code), isFalse, reason: '$path must not empty the preferences, which hold the queue');
      }
    });
  });
}
