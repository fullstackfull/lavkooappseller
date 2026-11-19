import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/features/order/domain/repositories/order_repository.dart';
import 'package:syriacosmeticsmanger/features/order/domain/services/order_service.dart';
import 'package:syriacosmeticsmanger/features/order_details/controllers/order_details_controller.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/models/order_list_filter_model.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/models/order_setup_model.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/repositories/order_details_repository.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/services/order_details_service.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/customer_controller.dart';

import 'support/fixtures.dart';
import 'support/flow_harness.dart';
import 'support/scripted_adapter.dart';
import 'support/unused_services.dart';

const String _listPath = '/api/v3/seller/orders/list';
const String _detailsPath = '/api/v3/seller/orders/1001';
const String _updatePath = '/api/v3/seller/orders/order-detail-info-update';

const String _enNoInternet = 'No internet connection';
const String _enTimeout = 'Connection timed out. Please try again';
const String _enServerError = 'Server error. Please try again later';
const String _enUpdated = 'Updated Successfully';

/// The same two messages as ar.json writes them: what a seller in any of the six markets actually reads.
const String _arNoInternet = 'لا يوجد اتصال بالإنترنت';
const String _arUpdated = 'تم التحديث بنجاح';

/// The order list, the order screen and the change of an order's status, as the seller app runs them: the real
/// controllers, services and repositories over the app's own Dio client, with a scripted server instead of the network.
class _OrdersFlow {
  _OrdersFlow._(this.adapter, this.orders, this.details);

  final ScriptedAdapter adapter;
  final OrderController orders;
  final OrderDetailsController details;

  /// The language the seller reads the app in is one choice, not two: the locale the screens are built with is also the
  /// language the API is asked in, which is how the app itself keeps them together.
  static Future<_OrdersFlow> pump(WidgetTester tester, ScriptedAdapter adapter,
      {Locale locale = FlowHarness.english}) async {
    final DioClient client = await FlowHarness.client(adapter, language: locale.languageCode);
    final OrderController orders = OrderController(
      orderServiceInterface: OrderService(orderRepoInterface: OrderRepository(dioClient: client)),
    );
    final OrderDetailsController details = OrderDetailsController(
      orderDetailsServiceInterface:
          OrderDetailsService(orderDetailsRepositoryInterface: OrderDetailsRepository(dioClient: client)),
    );

    await FlowHarness.pump(tester, locale: locale, providers: [
      ChangeNotifierProvider<OrderController>.value(value: orders),
      ChangeNotifierProvider<OrderDetailsController>.value(value: details),
      ChangeNotifierProvider<CustomerController>(
          create: (_) => CustomerController(cartServiceInterface: UnusedCartService())),
      ChangeNotifierProvider<CartController>(create: (_) => CartController(cartServiceInterface: UnusedCartService())),
    ]);

    addTearDown(orders.dispose);
    addTearDown(details.dispose);

    return _OrdersFlow._(adapter, orders, details);
  }

  Future<void> loadList(
    WidgetTester tester, {
    int offset = 1,
    String status = 'all',
    OrderListFilterModel? filter,
    bool reload = true,
  }) =>
      FlowHarness.call(
        tester,
        () => orders.getOrderList(Get.context, offset, status, filter, reload: reload),
      );

  Future<void> loadDetails(WidgetTester tester) => FlowHarness.call(tester, () => details.getOrderDetails('1001'));

  Future<void> changeStatus(WidgetTester tester, {String status = 'confirmed', String payment = 'unpaid'}) =>
      FlowHarness.call(
        tester,
        () => details.setUpOrder(
            orderSetupModel: OrderSetupModel(orderId: 1001, orderStatus: status, paymentStatus: payment)),
      );
}

/// The three requests that follow a status change that was accepted, answered by a server that remembers the status.
ScriptedAdapter _serverThatRemembersTheStatus({String initial = 'pending'}) {
  String status = initial;

  return ScriptedAdapter.routes(<String, ScriptedServer>{
    'POST $_updatePath': (RecordedRequest request) {
      status = request.fields['order_status']! as String;
      return ScriptedAnswer.json(<String, Object?>{'success': 1, 'message': 'Order updated successfully'});
    },
    'GET $_detailsPath': (_) => ScriptedAnswer.json(<Object?>[orderLineJson(orderStatus: status)]),
    'POST $_listPath': (_) =>
        ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[orderJson(orderStatus: status)])),
  });
}

void main() {
  group('the order list', () {
    group('the request', () {
      testWidgets('is a POST of the page and the status to the list, signed in with the seller\'s session',
          (WidgetTester tester) async {
        final _OrdersFlow flow = await _OrdersFlow.pump(
          tester,
          ScriptedAdapter.always(ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[orderJson()]))),
        );

        await flow.loadList(tester);

        expect(flow.adapter.only.method, 'POST');
        expect(flow.adapter.only.path, _listPath);
        expect(flow.adapter.only.rawQuery, isEmpty, reason: 'the page travels in the body, not in the address');
        expect(flow.adapter.only.fields, <String, Object?>{'limit': 10, 'offset': 1, 'status': 'all'});
        FlowHarness.expectSignedIn(flow.adapter.only);
      });

      testWidgets('names one status in the filter the API reads', (WidgetTester tester) async {
        final _OrdersFlow flow = await _OrdersFlow.pump(
          tester,
          ScriptedAdapter.always(ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[]))),
        );

        await flow.loadList(tester, status: 'pending');

        expect(flow.adapter.only.fields, <String, Object?>{
          'limit': 10,
          'offset': 1,
          'status': 'pending',
          'order_current_status': jsonEncode(<String>['pending']),
        });
      });

      // The tab names are the seller's words; the statuses are the API's. The tab for returned orders is "return" on the
      // screen and "returned" on the wire, and the one for cancelled orders is spelled the American way.
      const Map<int, String> statusOfTab = <int, String>{
        0: 'all',
        1: 'pending',
        2: 'processing',
        3: 'delivered',
        4: 'returned',
        5: 'failed',
        6: 'canceled',
        7: 'confirmed',
        8: 'out_for_delivery',
      };

      for (final MapEntry<int, String> tab in statusOfTab.entries) {
        testWidgets('is asked by tab ${tab.key} of the screen for the status "${tab.value}"',
            (WidgetTester tester) async {
          final _OrdersFlow flow = await _OrdersFlow.pump(
            tester,
            ScriptedAdapter.always(ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[]))),
          );

          await FlowHarness.call(tester, () async => flow.orders.setIndex(Get.context!, tab.key));

          final Map<String, Object?> body = flow.adapter.only.fields;
          expect(flow.adapter.only.path, _listPath);
          expect(body['status'], tab.value);
          expect(body['offset'], 1, reason: 'a tab starts at the first page');
          expect(body['order_current_status'], tab.value == 'all' ? isNull : jsonEncode(<String>[tab.value]));
        });
      }

      testWidgets('carries the seller\'s filter in the keys the API reads', (WidgetTester tester) async {
        final _OrdersFlow flow = await _OrdersFlow.pump(
          tester,
          ScriptedAdapter.always(ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[]))),
        );

        await flow.loadList(
          tester,
          filter: OrderListFilterModel(
            filterDateType: 'custom_date',
            startDate: '2026-11-01',
            endDate: '2026-11-15',
            onlyPosOrder: 1,
            hasDueAmount: 1,
            paymentStatusUnpaid: 1,
            orderStatus: <String>['pending', 'confirmed'],
            selectedCustomerId: '55',
          ),
        );

        expect(flow.adapter.only.fields, <String, Object?>{
          'limit': 10,
          'offset': 1,
          'date_type': 'custom_date',
          'start_date': '2026-11-01',
          'end_date': '2026-11-15',
          'order_types': jsonEncode(<String>['POS']),
          'order_amount_settlement': jsonEncode(<String>['due']),
          'payment_status': jsonEncode(<String>['unpaid']),
          'customer_id': '55',
          'order_current_status': jsonEncode(<String>['pending', 'confirmed']),
        });
        expect(flow.orders.isFilterActive, isTrue);
      });
    });

    group('a success answer', () {
      testWidgets('is the page the screen reads: its orders, its size and what each order says',
          (WidgetTester tester) async {
        final _OrdersFlow flow = await _OrdersFlow.pump(
          tester,
          ScriptedAdapter.always(ScriptedAnswer.json(orderPageJson(
            <Map<String, Object?>>[
              orderJson(id: 1002, orderStatus: 'confirmed', paymentStatus: 'paid', orderAmount: 99.9),
              orderJson(),
            ],
            totalSize: 14,
          ))),
        );

        expect(flow.orders.orderModel, isNull,
            reason: 'nothing is read before the answer, so the screen shows its placeholder');

        await flow.loadList(tester);

        expect(flow.orders.orderModel!.totalSize, 14);
        expect(flow.orders.orderModel!.offset, 1);
        expect(flow.orders.orderModel!.orders!.map((order) => order.id), <int?>[1002, 1001]);
        expect(flow.orders.orderModel!.orders!.first.orderStatus, 'confirmed');
        expect(flow.orders.orderModel!.orders!.first.paymentStatus, 'paid');
        expect(flow.orders.orderModel!.orders!.first.orderAmount, 99.9);
        expect(flow.orders.orderModel!.orders!.last.customer!.name, 'Test Customer');
        expect(flow.orders.paymentStatus, 'unpaid', reason: 'the payment status the screen reads is the last order\'s');
        expect(FlowHarness.shown(tester), isEmpty);
      });

      testWidgets('adds the next page to the first instead of replacing it', (WidgetTester tester) async {
        final _OrdersFlow flow = await _OrdersFlow.pump(
          tester,
          ScriptedAdapter.inOrder(<ScriptedAnswer>[
            ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[orderJson(id: 1003)], totalSize: 3)),
            ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[orderJson(id: 1002)], totalSize: 3, offset: 2)),
          ]),
        );

        await flow.loadList(tester);
        await flow.loadList(tester, offset: 2, reload: false);

        expect(flow.adapter.requests.map((request) => request.fields['offset']), <Object?>[1, 2]);
        expect(flow.orders.orderModel!.orders!.map((order) => order.id), <int?>[1003, 1002]);
        expect(flow.orders.orderModel!.offset, 2);
        expect(flow.orders.orderModel!.totalSize, 3);
      });

      testWidgets('may be an empty page, which is an answer and not a failure', (WidgetTester tester) async {
        final _OrdersFlow flow = await _OrdersFlow.pump(
          tester,
          ScriptedAdapter.always(ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[]))),
        );

        await flow.loadList(tester);

        expect(flow.orders.orderModel, isNotNull,
            reason: 'the screen shows "no order found", not its loading placeholder');
        expect(flow.orders.orderModel!.orders, isEmpty);
        expect(flow.orders.paymentStatus, isNull);
        expect(FlowHarness.shown(tester), isEmpty);
      });
    });

    group('a refusal', () {
      testWidgets('is shown in the server\'s words and leaves the list without a page', (WidgetTester tester) async {
        final _OrdersFlow flow = await _OrdersFlow.pump(tester, ScriptedAdapter.always(permissionRefusal()));

        await flow.loadList(tester);

        expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
        expect(flow.orders.orderModel, isNull);
        expect(flow.adapter.requests, hasLength(1));
      });

      testWidgets('does not take away the page already on screen when a later page is refused',
          (WidgetTester tester) async {
        final _OrdersFlow flow = await _OrdersFlow.pump(
          tester,
          ScriptedAdapter.inOrder(<ScriptedAnswer>[
            ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[orderJson()], totalSize: 12)),
            permissionRefusal(),
          ]),
        );

        await flow.loadList(tester);
        await flow.loadList(tester, offset: 2, reload: false);

        expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
        expect(flow.orders.orderModel!.orders!.map((order) => order.id), <int?>[1001]);
        expect(flow.orders.orderModel!.offset, 1);
      });
    });

    group('a transport failure', () {
      for (final MapEntry<String, (ScriptedAnswer, String)> failure in <String, (ScriptedAnswer, String)>{
        'no signal': (ScriptedAnswer.offline(), _enNoInternet),
        'a socket reset underneath the app': (ScriptedAnswer.socketReset(), _enNoInternet),
        'a connection that never completes': (ScriptedAnswer.timeout(), _enTimeout),
        'a server that crashed': (crashedServer, _enServerError),
      }.entries) {
        testWidgets('(${failure.key}) is shown to the seller, throws nothing, and can be retried',
            (WidgetTester tester) async {
          final _OrdersFlow flow = await _OrdersFlow.pump(
            tester,
            ScriptedAdapter.inOrder(<ScriptedAnswer>[
              failure.value.$1,
              ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[orderJson()])),
            ]),
          );

          await flow.loadList(tester);

          expect(FlowHarness.shown(tester), <String>[failure.value.$2]);
          expect(flow.orders.orderModel, isNull,
              reason: 'there is no page to show, so the screen keeps its placeholder');

          await FlowHarness.dismissToast(tester);
          await flow.loadList(tester);

          expect(flow.adapter.requests, hasLength(2));
          expect(flow.adapter.requests.last.fields, flow.adapter.requests.first.fields,
              reason: 'the retry asks for the same page');
          expect(flow.orders.orderModel!.orders!.single.id, 1001);
        });
      }
    });
  });

  group('the order screen', () {
    testWidgets('asks for the order by its id, with a GET and no body', (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(
        tester,
        ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[orderLineJson()])),
      );

      await flow.loadDetails(tester);

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _detailsPath);
      expect(flow.adapter.only.rawQuery, isEmpty);
      expect(flow.adapter.only.body, isNull);
      FlowHarness.expectSignedIn(flow.adapter.only);
    });

    testWidgets('reads the lines of the order, with the order on each, and offers the statuses its shipping allows',
        (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(
        tester,
        ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[orderLineJson(), orderLineJson()])),
      );

      expect(flow.details.orderDetails, isNull);

      await flow.loadDetails(tester);

      expect(flow.details.orderDetails, hasLength(2));
      expect(flow.details.orderDetails!.first.order!.id, 1001);
      expect(flow.details.orderDetails!.first.order!.orderStatus, 'pending');
      expect(flow.details.orderDetails!.first.productDetails!.name, 'Rose Serum');
      expect(flow.details.orderDetails!.first.qty, 2);
      expect(flow.details.orderStatusList, <String>['pending', 'confirmed', 'processing']);
    });

    testWidgets('offers every status when the order is shipped by a third party', (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(
        tester,
        ScriptedAdapter.always(
            ScriptedAnswer.json(<Object?>[orderLineJson(shippingResponsibility: 'sellerwise_shipping')])),
      );

      await flow.loadDetails(tester);

      expect(flow.details.orderStatusList, <String>[
        'pending',
        'confirmed',
        'processing',
        'out_for_delivery',
        'delivered',
        'returned',
        'failed',
        'canceled',
      ]);
    });

    testWidgets('shows the server\'s words when the order is not the seller\'s, and keeps nothing on screen',
        (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(
        tester,
        ScriptedAdapter.always(errorsRefusal('order', 'Order not found.', status: 404)),
      );

      await flow.loadDetails(tester);

      expect(FlowHarness.shown(tester), <String>['Order not found.']);
      expect(flow.details.orderDetails, isNull);
    });

    testWidgets('survives a transport failure, says so, and can be opened again', (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.offline(),
          ScriptedAnswer.json(<Object?>[orderLineJson()]),
        ]),
      );

      await flow.loadDetails(tester);

      expect(FlowHarness.shown(tester), <String>[_enNoInternet]);
      expect(flow.details.orderDetails, isNull);

      await FlowHarness.dismissToast(tester);
      await flow.loadDetails(tester);

      expect(flow.adapter.requests.map((request) => request.path), <String>[_detailsPath, _detailsPath]);
      expect(flow.details.orderDetails!.single.order!.id, 1001);
    });
  });

  group('changing the status of an order', () {
    testWidgets('is a POST of the order and what it should become, with every field the API reads',
        (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(tester, _serverThatRemembersTheStatus());

      await flow.changeStatus(tester, status: 'out_for_delivery', payment: 'paid');

      final RecordedRequest request = flow.adapter.requests.first;
      expect(request.method, 'POST');
      expect(request.path, _updatePath);
      expect(request.rawQuery, isEmpty);
      expect(request.fields, <String, Object?>{
        'order_id': 1001,
        'order_status': 'out_for_delivery',
        'payment_status': 'paid',
        'delivery_man_id': null,
        'deliveryman_charge': null,
        'expected_delivery_date': null,
        'delivery_service_name': null,
        'third_party_delivery_tracking_id': null,
        'delivery_type': null,
      });
      FlowHarness.expectSignedIn(request);
    });

    testWidgets('that was accepted is told to the seller, and the order and the list are read again',
        (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(tester, _serverThatRemembersTheStatus());

      await flow.loadList(tester);
      await flow.loadDetails(tester);
      flow.adapter.requests.clear();

      await flow.changeStatus(tester, status: 'confirmed');

      expect(FlowHarness.shown(tester), <String>[_enUpdated]);
      expect(
        flow.adapter.requests.map((request) => '${request.method} ${request.path}'),
        <String>['POST $_updatePath', 'GET $_detailsPath', 'POST $_listPath'],
        reason: 'the screens must show what the server now says, not what they showed before',
      );
      expect(flow.details.orderDetails!.single.order!.orderStatus, 'confirmed');
      expect(flow.orders.orderModel!.orders!.single.orderStatus, 'confirmed');
      expect(flow.details.isLoading, isFalse);
    });

    testWidgets('that the server refuses is shown in its words, changes nothing on screen, and reads nothing again',
        (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.json(<Object?>[orderLineJson(paymentStatus: 'paid')]),
          messageRefusal(
            'When payment status paid then you can not change payment status paid to unpaid.',
            extra: <String, Object?>{'success': 0},
          ),
        ]),
      );

      await flow.loadDetails(tester);
      await flow.changeStatus(tester, status: 'confirmed', payment: 'unpaid');

      expect(FlowHarness.shown(tester),
          <String>['When payment status paid then you can not change payment status paid to unpaid.']);
      expect(flow.adapter.requests, hasLength(2), reason: 'nothing is read again after a refusal');
      expect(flow.details.orderDetails!.single.order!.paymentStatus, 'paid');
      expect(flow.details.isLoading, isFalse, reason: 'the button the seller pressed is usable again');
    });

    // DEFECT K-16.4-D1, written down as the app behaves today rather than as it should. The API answers some refusals of a
    // status change with a 200 and "success": 0 beside its reason (an order already delivered, a status the fulfilment rules
    // block), and `setUpOrder` reads every 200 as an update, so the seller is told "Updated Successfully" over an order that
    // did not move. That is what this test asserts, so the defect is held in place instead of being hidden behind a skip:
    // whoever teaches the controller to read the answer's own verdict will see this fail, and the line below says what to
    // put in its place.
    testWidgets('that the server refuses in a 200 with success 0 is told to the seller as an update, which is a defect',
        (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(
        tester,
        ScriptedAdapter.routes(<String, ScriptedServer>{
          'POST $_updatePath': (_) =>
              ScriptedAnswer.json(<String, Object?>{'success': 0, 'message': 'Order is already delivered.'}),
          'GET $_detailsPath': (_) => ScriptedAnswer.json(<Object?>[orderLineJson(orderStatus: 'delivered')]),
          'POST $_listPath': (_) =>
              ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[orderJson(orderStatus: 'delivered')])),
        }),
      );

      await flow.changeStatus(tester, status: 'pending');

      expect(FlowHarness.shown(tester), <String>[_enUpdated],
          reason: 'what the seller reads today. It should be ["Order is already delivered."], the answer\'s own message');

      // What keeps the seller from acting on the wrong message: the handler reads the order and the list again, and both
      // come back with the status the server still holds, so neither screen pretends the order moved.
      expect(
        flow.adapter.requests.map((request) => '${request.method} ${request.path}'),
        <String>['POST $_updatePath', 'GET $_detailsPath', 'POST $_listPath'],
      );
      expect(flow.details.orderDetails!.single.order!.orderStatus, 'delivered',
          reason: 'the order screen shows the status the server holds, not the one that was asked for');
      expect(flow.orders.orderModel!.orders!.single.orderStatus, 'delivered');
      expect(flow.details.isLoading, isFalse);
    });

    testWidgets('that the server cannot find is shown in its words', (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(
        tester,
        ScriptedAdapter.always(messageRefusal('Order not found.', status: 404, extra: <String, Object?>{'success': 0})),
      );

      await flow.changeStatus(tester);

      expect(FlowHarness.shown(tester), <String>['Order not found.']);
      expect(flow.details.isLoading, isFalse);
    });

    testWidgets('survives a transport failure, leaves the button usable, and sends the same change again on retry',
        (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.timeout(),
          ScriptedAnswer.json(<String, Object?>{'success': 1, 'message': 'Order updated successfully'}),
          ScriptedAnswer.json(<Object?>[orderLineJson(orderStatus: 'confirmed')]),
          ScriptedAnswer.json(orderPageJson(<Map<String, Object?>>[orderJson(orderStatus: 'confirmed')])),
        ]),
      );

      await flow.changeStatus(tester, status: 'confirmed');

      expect(FlowHarness.shown(tester), <String>[_enTimeout]);
      expect(flow.adapter.requests, hasLength(1), reason: 'nothing is read again after a failure');
      expect(flow.details.isLoading, isFalse);

      await FlowHarness.dismissToast(tester);
      await flow.changeStatus(tester, status: 'confirmed');

      expect(flow.adapter.requests.first.fields, flow.adapter.requests[1].fields,
          reason: 'the retry is the same change');
      expect(FlowHarness.shown(tester), <String>[_enUpdated]);
      expect(flow.details.orderDetails!.single.order!.orderStatus, 'confirmed');
    });
  });

  // Every one of the six markets is read in Arabic by most of the sellers in it, and what the app says to them comes out
  // of ar.json rather than out of the code, so a flow run only in English leaves the half that matters unproven. The
  // harness loads the real language files for whichever locale it is given, and the API is asked in the same language.
  group('the seller who reads the app in Arabic', () {
    testWidgets('is told in Arabic that an order list could not be reached, and the API is asked in Arabic',
        (WidgetTester tester) async {
      final _OrdersFlow flow = await _OrdersFlow.pump(
        tester,
        ScriptedAdapter.always(ScriptedAnswer.offline()),
        locale: FlowHarness.arabic,
      );

      await flow.loadList(tester);

      expect(FlowHarness.shown(tester), <String>[_arNoInternet]);
      FlowHarness.expectSignedIn(flow.adapter.only, language: 'ar');
    });

    testWidgets('is told in Arabic that a status change was accepted', (WidgetTester tester) async {
      final _OrdersFlow flow =
          await _OrdersFlow.pump(tester, _serverThatRemembersTheStatus(), locale: FlowHarness.arabic);

      await flow.changeStatus(tester, status: 'confirmed');

      expect(FlowHarness.shown(tester), <String>[_arUpdated]);
      expect(flow.details.orderDetails!.single.order!.orderStatus, 'confirmed');
      FlowHarness.expectSignedIn(flow.adapter.requests.first, language: 'ar');
    });
  });
}
