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

/// The profile of the seller, as the server answers it.
class _FakeProfileService implements ProfileServiceInterface {
  int? sellerId;

  @override
  Future<dynamic> getSellerInfo() async => ApiResponse.withSuccess(Response<dynamic>(requestOptions: RequestOptions(path: '/'), statusCode: 200, data: <String, dynamic>{'id': sellerId, 'pos_status': 1}));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One device: one disk, one server, and whoever is signed in on it. The app learns who is signed in from the profile, which answers after the session exists, so the session and the seller are two
/// facts here too. Starting the app again is a new controller reading the same disk.
class _Device {
  _Device(this.preferences) {
    start();
  }

  final SharedPreferences preferences;
  final _FakeCartService service = _FakeCartService();

  bool hasSession = false;
  String? sellerId;
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

Future<_Device> _device({List<String> records = const <String>[], String? signedIn}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{_storageKey: records});
  final _Device device = _Device(await SharedPreferences.getInstance());
  if (signedIn != null) {
    device.signIn(signedIn);
  }

  return device;
}

String _record(PendingPosOrder sale) => sale.encode();

Widget _app(OfflineSalesController controller, Widget child) => MaterialApp(
      home: Scaffold(body: ChangeNotifierProvider<OfflineSalesController>.value(value: controller, child: child)),
    );

String _amountText(BuildContext context, double amount) => 'SAR ${amount.toStringAsFixed(2)}';

/// K-06.2, the seller half: the queue of sales that could not be sent is one list on the device and it outlives a sign-out, while the server records a replayed sale under the seller of the session that
/// sends it. A sale is therefore sent only by the seller who took it, it is never counted, failed or removed by another seller, and a sign-out never deletes it. Run on the real controller, with
/// real shared preferences in memory and a server that answers as it does. The market half needs the market choice of pull request 2 and is not covered here.
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
      late MockStreamHandlerEventSink connection;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
        MockStreamHandler.inline(onListen: (Object? arguments, MockStreamHandlerEventSink sink) => connection = sink),
      );
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

  group('in the app', () {
    testWidgets('the signed-in seller is the one the profile names, and no seller is named before the profile has answered', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      final _FakeProfileService profileService = _FakeProfileService();
      final ProfileController profile = ProfileController(profileServiceInterface: profileService);
      final OfflineSalesController outbox = OfflineSalesController(cartServiceInterface: _FakeCartService(), sharedPreferences: preferences, hasSession: () => true);
      await tester.pumpWidget(
        MultiProvider(
          providers: <ChangeNotifierProvider<ChangeNotifier>>[
            ChangeNotifierProvider<ProfileController>.value(value: profile),
            ChangeNotifierProvider<OfflineSalesController>.value(value: outbox),
          ],
          child: MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
        ),
      );
      Future<PendingPosOrder> sale() => outbox.enqueue(orderBody: <String, dynamic>{'user_id': 0}, orderAmount: 25, customerName: 'Layla');

      final PendingPosOrder beforeTheAnswer = await sale();
      profileService.sellerId = 7;
      await profile.getSellerInfo();
      final PendingPosOrder afterTheAnswer = await sale();
      profileService.sellerId = 9;
      await profile.getSellerInfo();
      final PendingPosOrder forAnotherSeller = await sale();

      expect(beforeTheAnswer.sellerId, isNull);
      expect(afterTheAnswer.sellerId, '7');
      expect(forAnotherSeller.sellerId, '9');
      expect(outbox.pending.map((PendingPosOrder order) => order.id), <String>[beforeTheAnswer.id, forAnotherSeller.id], reason: 'the seller who is signed in sees their own sales, and the one that has no seller');
    });
  });

  group('a sign-out', () {
    testWidgets('ends the session and leaves the queue on the disk and in the outbox', (WidgetTester tester) async {
      final _Device device = await _device(
        records: <String>[_record(_sale('a-1', seller: _sellerA)), _record(_sale('a-f', seller: _sellerA, attempts: 10, lastError: 'refused by the server'))],
        signedIn: _sellerA,
      );
      await device.preferences.setString(AppConstants.token, 'a-real-looking-session-token-value');
      final List<String> queueBefore = device.preferences.getStringList(_storageKey)!;
      final AuthController auth = AuthController(
        authServiceInterface: AuthService(
          authRepoInterface: AuthRepository(
            dioClient: DioClient(AppConstants.baseUrl, Dio(), loggingInterceptor: LoggingInterceptor(), sharedPreferences: device.preferences),
            sharedPreferences: device.preferences,
          ),
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: <ChangeNotifierProvider<ChangeNotifier>>[
            ChangeNotifierProvider<ShopController>.value(value: ShopController(shopServiceInterface: _FakeShopService())),
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<OfflineSalesController>.value(value: device.controller),
          ],
          child: MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
        ),
      );
      expect(auth.isLoggedIn(), isTrue);

      await tester.runAsync(() => auth.clearSharedData());

      expect(auth.isLoggedIn(), isFalse, reason: 'the session is gone');
      expect(device.preferences.getStringList(_storageKey), queueBefore, reason: 'and the sales are still on the disk, as they were');
      expect(device.controller.pending, hasLength(2), reason: 'and in the outbox');
      expect(device.controller.failedCount, 1);
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
