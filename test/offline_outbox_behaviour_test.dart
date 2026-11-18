import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/offline_sales_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/outbox_policy.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/failed_sales_sheet.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/offline_sales_banner.dart';

const String _storageKey = 'offline_pos_orders';

ApiResponse _answer(int status, Object? data) => ApiResponse.withSuccess(Response<dynamic>(requestOptions: RequestOptions(path: '/'), statusCode: status, data: data));

ApiResponse _placed(int orderId) => _answer(200, <String, dynamic>{'order_id': orderId});

ApiResponse _refused(String? message) => _answer(200, <String, dynamic>{'product_not_available': true, if (message != null) 'message': message});

/// What the repository returns for an HTTP error status or a connection that failed: the error, and no response.
ApiResponse _failed(String reason) => ApiResponse.withError(reason);

PendingPosOrder _sale(String id, {int attempts = 0, String? lastError, String? key, String customer = 'Layla'}) => PendingPosOrder(
      id: id,
      body: <String, dynamic>{'user_id': 0, 'cart': <String>[id]},
      createdAt: DateTime(2026, 11, 18, 10),
      orderAmount: 25,
      customerName: customer,
      attempts: attempts,
      lastError: lastError,
      idempotencyKey: key,
    );

class _Call {
  _Call(this.body, this.key);

  final Map<String, dynamic> body;
  final String? key;
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

class _Outbox {
  _Outbox(this.controller, this.prefs, this.service);

  final OfflineSalesController controller;
  final SharedPreferences prefs;
  final _FakeCartService service;

  List<PendingPosOrder> get stored => (prefs.getStringList(_storageKey) ?? <String>[]).map(PendingPosOrder.decode).whereType<PendingPosOrder>().toList();

  List<String> get ids => controller.pending.map((PendingPosOrder order) => order.id).toList();

  List<String> get storedIds => stored.map((PendingPosOrder order) => order.id).toList();
}

Future<_Outbox> _outbox(List<PendingPosOrder> queue, {bool session = true}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{_storageKey: queue.map((PendingPosOrder order) => order.encode()).toList()});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final _FakeCartService service = _FakeCartService();
  final OfflineSalesController controller = OfflineSalesController(cartServiceInterface: service, sharedPreferences: prefs, hasSession: () => session)..loadFromStorage();

  return _Outbox(controller, prefs, service);
}

Widget _app(OfflineSalesController controller, Widget child) => MaterialApp(
      home: Scaffold(body: ChangeNotifierProvider<OfflineSalesController>.value(value: controller, child: child)),
    );

String _amountText(BuildContext context, double amount) => 'SAR ${amount.toStringAsFixed(2)}';

/// K-06 and K-V3: what the offline outbox does with a sale, run on the real controller with a service that answers as the server does. A queued sale is the only record of money taken at the counter:
/// a replay may refuse it, lose its answer or fail, and it may be joined, removed or reopened while the replay is on its way; none of that may lose it, and none may make the seller believe it was sent.
void main() {
  group('the replay of the queue', () {
    test('a sale the server recorded leaves the queue, and was sent under the key it was first sent with', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('a', key: 'key-a')]);
      outbox.service.answer = (Map<String, dynamic> body, String? key) async => _placed(7);

      final int synced = await outbox.controller.syncPending();

      expect(synced, 1);
      expect(outbox.ids, isEmpty);
      expect(outbox.storedIds, isEmpty);
      expect(outbox.service.calls.single.key, 'key-a');
    });

    test('a sale the server refused with a 200 stays, with its attempt counted and the reason the server gave, and is not counted as synced', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('a', key: 'key-a')]);
      outbox.service.answer = (Map<String, dynamic> body, String? key) async => _refused('Aspirin is not available for order place');

      final int synced = await outbox.controller.syncPending();

      expect(synced, 0);
      expect(outbox.controller.pending.single.attempts, 1);
      expect(outbox.controller.pending.single.lastError, 'Aspirin is not available for order place');
      expect(outbox.stored.single.lastError, 'Aspirin is not available for order place', reason: 'and it is on the disk');
    });

    test('a refusal that gives no reason is kept under the general reason', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('a', key: 'key-a')]);
      outbox.service.answer = (Map<String, dynamic> body, String? key) async => _refused(null);

      await outbox.controller.syncPending();

      expect(outbox.controller.pending.single.lastError, OfflineSalesController.refusedWithoutReason);
    });

    test('an HTTP error or a connection that failed counts as a failed attempt and keeps its reason', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('a', key: 'key-a')]);
      outbox.service.answer = (Map<String, dynamic> body, String? key) async => _failed('Internal server error');

      await outbox.controller.syncPending();

      expect(outbox.controller.pending.single.attempts, 1);
      expect(outbox.controller.pending.single.lastError, 'Internal server error');
    });

    test('a replay that throws is a failed attempt like any other, and the sale stays with the words of the failure', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('a', key: 'key-a')]);
      outbox.service.answer = (Map<String, dynamic> body, String? key) async => throw StateError('socket closed');

      await outbox.controller.syncPending();

      expect(outbox.controller.pending.single.attempts, 1);
      expect(outbox.controller.pending.single.lastError, contains('socket closed'));
      expect(outbox.stored.single.attempts, 1, reason: 'and it is on the disk');
    });

    test('however many times a sale fails and is retried, it is never dropped, and it is replayed by itself no more than ten times in a row', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('a', key: 'key-a')]);
      outbox.service.answer = (Map<String, dynamic> body, String? key) async => _failed('Internal server error');

      for (int round = 0; round < 3; round++) {
        final int sentBefore = outbox.service.calls.length;
        for (int pass = 0; pass < OutboxPolicy.maxAttempts + 5; pass++) {
          await outbox.controller.syncPending();
        }

        expect(outbox.controller.pending.single.attempts, OutboxPolicy.maxAttempts);
        expect(outbox.controller.failedCount, 1);
        expect(outbox.service.calls.length - sentBefore, round == 0 ? OutboxPolicy.maxAttempts : OutboxPolicy.maxAttempts - 1, reason: 'the passes after the tenth send nothing; a retry by the seller already sent it once');
        await outbox.controller.retryFailedSales();
      }

      expect(outbox.ids, <String>['a']);
      expect(outbox.storedIds, <String>['a']);
    });

    test('a sale that has used its ten attempts is not replayed by the return of the connection, and it stays', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('failed', attempts: 10, lastError: 'refused', key: 'key-f'), _sale('a', key: 'key-a')]);

      await outbox.controller.syncPending();

      expect(outbox.service.calls.map((_Call call) => call.key), <String?>['key-a'], reason: 'only the sale that is still replayed by itself was sent');
      expect(outbox.ids, <String>['failed'], reason: 'the failed sale is still there, and the other one was recorded');
      expect(outbox.controller.pending.single.attempts, 10);
    });

    test('nothing is sent while there is no session to send it under', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('a', key: 'key-a')], session: false);

      final int synced = await outbox.controller.syncPending();

      expect(synced, 0);
      expect(outbox.service.calls, isEmpty);
      expect(outbox.ids, <String>['a']);
    });

    test('a sale an earlier version queued is given a key that is stored BEFORE it is sent, and is sent under it', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('legacy')]);
      String? storedWhenSent;
      outbox.service.answer = (Map<String, dynamic> body, String? key) async {
        storedWhenSent = outbox.stored.single.idempotencyKey;

        return _placed(3);
      };

      await outbox.controller.syncPending();

      expect(outbox.service.calls.single.key, isNotNull);
      expect(storedWhenSent, outbox.service.calls.single.key, reason: 'the key was on the disk when the request left, so a lost answer is replayed under it');
    });

    test('a sale queued while the replay is on its way is kept', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('a', key: 'key-a')]);
      final Completer<void> connection = Completer<void>();
      outbox.service.answer = (Map<String, dynamic> body, String? key) async {
        await connection.future;

        return _placed(5);
      };

      final Future<int> replaying = outbox.controller.syncPending();
      await pumpEventQueue();
      await outbox.controller.enqueue(orderBody: <String, dynamic>{'user_id': 0, 'cart': <String>['new']}, orderAmount: 10, customerName: 'Omar', idempotencyKey: 'key-new');
      connection.complete();
      await replaying;

      expect(outbox.controller.pending.map((PendingPosOrder order) => order.customerName), <String>['Omar'], reason: 'the first sale was recorded, the one queued meanwhile is the only record of its money');
      expect(outbox.stored.map((PendingPosOrder order) => order.idempotencyKey), <String?>['key-new'], reason: 'and it is on the disk');
    });

    test('a failed sale the seller removed while a replay is on its way does not come back', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('failed', attempts: 10, key: 'key-f'), _sale('a', key: 'key-a')]);
      final Completer<void> connection = Completer<void>();
      outbox.service.answer = (Map<String, dynamic> body, String? key) async {
        await connection.future;

        return _placed(5);
      };

      final Future<int> replaying = outbox.controller.syncPending();
      await pumpEventQueue();
      await outbox.controller.remove('failed');
      connection.complete();
      await replaying;

      expect(outbox.ids, isEmpty);
      expect(outbox.storedIds, isEmpty);
    });

    test('the failed sales the seller reopened while a replay is on its way stay reopened', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('failed', attempts: 10, lastError: 'refused', key: 'key-f'), _sale('a', key: 'key-a')]);
      final Completer<void> connection = Completer<void>();
      outbox.service.answer = (Map<String, dynamic> body, String? key) async {
        await connection.future;

        return _placed(5);
      };

      final Future<int> replaying = outbox.controller.syncPending();
      await pumpEventQueue();
      await outbox.controller.retryFailedSales();
      connection.complete();
      await replaying;

      expect(outbox.ids, <String>['failed']);
      expect(outbox.controller.pending.single.attempts, 0, reason: 'the pass that was on its way did not overwrite the reopened sale with the list it began with');
    });
  });

  group('the seller retries the failed sales', () {
    test('each is given its attempts back and is sent under its own key; one that fails again stays in the queue, no longer counted as failed', () async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('failed', attempts: 10, lastError: 'old reason', key: 'key-f')]);
      outbox.service.answer = (Map<String, dynamic> body, String? key) async => _refused('Still not available');

      await outbox.controller.retryFailedSales();

      expect(outbox.service.calls.single.key, 'key-f');
      expect(outbox.controller.pending.single.attempts, 1);
      expect(outbox.controller.pending.single.lastError, 'Still not available');
      expect(outbox.controller.failedCount, 0, reason: 'it has a new attempt on record, so the sheet must not say there is nothing left to retry');
      expect(outbox.controller.hasPending, isTrue);
    });
  });

  group('the sheet of the sales that could not be sent', () {
    testWidgets('lists each failed sale with its customer and amount, and the reason; a refusal without a reason shows the general one', (WidgetTester tester) async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[
        _sale('one', attempts: 10, lastError: 'Aspirin is not available for order place', customer: 'Layla'),
        _sale('two', attempts: 10, lastError: OfflineSalesController.refusedWithoutReason, customer: 'Omar'),
      ]);

      await tester.pumpWidget(_app(outbox.controller, const FailedSalesSheet(formatAmount: _amountText)));

      expect(find.textContaining('Layla · SAR 25.00'), findsOneWidget);
      expect(find.textContaining('Omar · SAR 25.00'), findsOneWidget);
      expect(find.textContaining('Aspirin is not available for order place'), findsOneWidget);
      expect(find.textContaining('something_went_wrong'), findsOneWidget);
      expect(find.textContaining(OfflineSalesController.refusedWithoutReason), findsNothing, reason: 'the raw key is never shown to the seller');
      expect(find.text('retry'), findsOneWidget);
    });

    testWidgets('says how many sales wait, and never that all are synced, when a retry has given the failed sales their attempts back', (WidgetTester tester) async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('a', attempts: 1, lastError: 'Still not available')]);

      await tester.pumpWidget(_app(outbox.controller, const FailedSalesSheet(formatAmount: _amountText)));

      expect(find.text('unsynced_sales: 1'), findsOneWidget);
      expect(find.text('sales_synced'), findsNothing);
      expect(find.text('retry'), findsNothing, reason: 'nothing is failed, so there is nothing for the sheet to retry');
    });

    testWidgets('says nothing about syncing when the queue is empty', (WidgetTester tester) async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[]);

      await tester.pumpWidget(_app(outbox.controller, const FailedSalesSheet(formatAmount: _amountText)));

      expect(find.text('sales_synced'), findsNothing);
      expect(find.textContaining('unsynced_sales'), findsNothing);
    });

    testWidgets('Retry in the sheet replays the failed sales under their own keys', (WidgetTester tester) async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('one', attempts: 10, lastError: 'refused', key: 'key-one')]);

      await tester.pumpWidget(_app(outbox.controller, const FailedSalesSheet(formatAmount: _amountText)));
      await tester.tap(find.text('retry'));
      await tester.pumpAndSettle();

      expect(outbox.service.calls.map((_Call call) => call.key), <String?>['key-one']);
    });
  });

  group('the banner above the POS', () {
    testWidgets('Retry reopens and replays the failed sales when every sale in the queue has failed', (WidgetTester tester) async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('one', attempts: 10, lastError: 'refused', key: 'key-one')]);

      await tester.pumpWidget(_app(outbox.controller, const OfflineSalesBanner()));
      await tester.tap(find.text('retry'));
      await tester.pumpAndSettle();

      expect(outbox.service.calls.map((_Call call) => call.key), <String?>['key-one'], reason: 'before, Retry replayed nothing because failed sales are not replayed by themselves');
    });

    testWidgets('Retry replays the queue as before when no sale has failed', (WidgetTester tester) async {
      final _Outbox outbox = await _outbox(<PendingPosOrder>[_sale('one', attempts: 2, key: 'key-one')]);

      await tester.pumpWidget(_app(outbox.controller, const OfflineSalesBanner()));
      await tester.tap(find.text('retry'));
      await tester.pumpAndSettle();

      expect(outbox.service.calls.map((_Call call) => call.key), <String?>['key-one']);
      expect(jsonDecode(outbox.prefs.getStringList(_storageKey)?.firstOrNull ?? 'null'), isNull, reason: 'a sale the server recorded leaves the queue');
    });
  });
}
