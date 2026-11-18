import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/offline_sales_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/place_order_body.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pos_idempotency_key.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/temporary_cart_for_customer_model.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/services/cart_service_interface.dart';

ApiResponse _answer(int status, Object? data) => ApiResponse.withSuccess(Response<dynamic>(requestOptions: RequestOptions(path: '/'), statusCode: status, data: data));

class _FakeCartService implements CartServiceInterface {
  ApiResponse answer = ApiResponse.withError('not set');
  final List<String?> keysSent = <String?>[];

  @override
  Future<dynamic> placeOrder(PlaceOrderBody placeOrderBody, {String? idempotencyKey}) async {
    keysSent.add(idempotencyKey);

    return answer;
  }

  @override
  void addToCartList(List<TemporaryCartListModel> cartProductList) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Counter {
  _Counter(this.cart, this.outbox, this.service);

  final CartController cart;
  final OfflineSalesController outbox;
  final _FakeCartService service;
}

PlaceOrderBody _sale() => PlaceOrderBody(cart: <dynamic>[].cast(), orderAmount: 1500, userId: 0, paymentMethod: 'cash');

/// The counter as the cashier meets it: the real cart controller and the real outbox, a server that answers as it does, and a cart with what the cashier typed in it.
Future<_Counter> _counter(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _FakeCartService service = _FakeCartService();
  final OfflineSalesController outbox = OfflineSalesController(cartServiceInterface: service, sharedPreferences: preferences, hasSession: () => true);
  final CartController cart = CartController(cartServiceInterface: service);
  cart.collectedCashController.text = '1600';
  cart.extraDiscountController.text = '25';

  await tester.pumpWidget(
    ChangeNotifierProvider<OfflineSalesController>.value(
      value: outbox,
      child: MaterialApp(navigatorKey: navigatorKey, home: const Scaffold(body: SizedBox.shrink())),
    ),
  );

  return _Counter(cart, outbox, service);
}

/// K-06: what the cashier sees and what the cart keeps after a sale is sent, run on the real cart controller. The server refuses a sale with HTTP 200 and no order number; an earlier version emptied
/// the cart as if the sale had been recorded, so the cashier's retry sent an empty sale.
void main() {
  group('a sale the server refused with a 200', () {
    for (final MapEntry<String, Map<String, dynamic>> refusal in <String, Map<String, dynamic>>{
      'a product that is not available': <String, dynamic>{'product_not_available': true, 'message': 'Aspirin is not available for order place'},
      'a digital product for a walk-in': <String, dynamic>{'checkProductTypeForWalkingCustomer': true, 'message': 'Aspirin is not available for order place'},
    }.entries) {
      testWidgets('is told to the cashier in the words of the server, keeps what was typed, and is not queued: ${refusal.key}', (WidgetTester tester) async {
        final _Counter counter = await _counter(tester);
        counter.service.answer = _answer(200, refusal.value);

        final ApiResponse answer = await counter.cart.placeOrder(Get.context!, _sale());
        await tester.pump();

        expect(find.text('Aspirin is not available for order place'), findsOneWidget);
        expect(counter.cart.collectedCashController.text, '1600', reason: 'the cart is as the cashier left it, so the retry is the same sale');
        expect(counter.cart.extraDiscountController.text, '25');
        expect(counter.cart.isLoading, isFalse);
        expect(counter.outbox.pending, isEmpty, reason: 'the server answered, so there is nothing to replay');
        expect(answer.response?.statusCode, 200);
      });
    }

    testWidgets('that gives no reason is told as the general message', (WidgetTester tester) async {
      final _Counter counter = await _counter(tester);
      counter.service.answer = _answer(200, <String, dynamic>{'product_not_available': true});

      await counter.cart.placeOrder(Get.context!, _sale());
      await tester.pump();

      expect(find.text('something_went_wrong'), findsOneWidget);
      expect(counter.cart.collectedCashController.text, '1600');
    });

    testWidgets('that names no order at all is a refusal too', (WidgetTester tester) async {
      final _Counter counter = await _counter(tester);
      counter.service.answer = _answer(200, <String, dynamic>{'message': 'done'});

      await counter.cart.placeOrder(Get.context!, _sale());
      await tester.pump();

      expect(find.text('done'), findsOneWidget);
      expect(counter.cart.collectedCashController.text, '1600');
      expect(counter.outbox.pending, isEmpty);
    });
  });

  group('a sale whose request got no answer', () {
    testWidgets('is parked in the outbox under the key it was sent with, and the cart is cleared because the outbox holds the sale now', (WidgetTester tester) async {
      final _Counter counter = await _counter(tester);
      counter.service.answer = ApiResponse.withError('Connection timed out');

      await counter.cart.placeOrder(Get.context!, _sale());
      await tester.pump();

      expect(counter.service.keysSent, hasLength(1));
      expect(PosIdempotencyKey.isValid(counter.service.keysSent.single), isTrue);
      expect(counter.outbox.pending.single.idempotencyKey, counter.service.keysSent.single, reason: 'a replay of a sale whose answer was lost is the same sale to the server');
      expect(counter.outbox.pending.single.orderAmount, 1500);
      expect(counter.cart.collectedCashController.text, isEmpty);
      expect(counter.cart.extraDiscountController.text, isEmpty);
      expect(find.text('sale_saved_offline'), findsOneWidget);
    });
  });
}
