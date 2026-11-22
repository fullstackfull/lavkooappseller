import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pos_order_answer.dart';

/// K-06: the server refuses a POS sale with HTTP 200 and no order number, so a 200 is not a sale. An earlier version showed "order placed", emptied the cart and opened an invoice of no order, and a
/// queued sale that the server refused was counted as synced and left the queue.
void main() {
  group('an answer that says a sale was recorded', () {
    test('names the order, whatever type its number has', () {
      expect(PosOrderAnswer.isPlaced(<String, dynamic>{'order_id': 100312}), isTrue);
      expect(PosOrderAnswer.isPlaced(<String, dynamic>{'order_id': '100312'}), isTrue);
      expect(PosOrderAnswer.isPlaced(<String, dynamic>{'order_id': 100312, 'message': 'ok'}), isTrue);
    });

    test('is not a refusal that comes with a 200', () {
      expect(PosOrderAnswer.isPlaced(<String, dynamic>{'product_not_available': true, 'message': 'Aspirin is not available for order place'}), isFalse);
      expect(PosOrderAnswer.isPlaced(<String, dynamic>{'checkProductTypeForWalkingCustomer': true, 'message': 'A digital product needs a customer'}), isFalse);
      expect(PosOrderAnswer.isPlaced(<String, dynamic>{'product_not_available': true, 'order_id': 5}), isFalse, reason: 'a refusal wins over a number');
    });

    test('is not an answer that names no order', () {
      expect(PosOrderAnswer.isPlaced(<String, dynamic>{'order_id': null}), isFalse);
      expect(PosOrderAnswer.isPlaced(<String, dynamic>{}), isFalse);
      expect(PosOrderAnswer.isPlaced(<String, dynamic>{'message': 'done'}), isFalse);
      expect(PosOrderAnswer.isPlaced(null), isFalse);
      expect(PosOrderAnswer.isPlaced('order placed'), isFalse);
      expect(PosOrderAnswer.isPlaced(<dynamic>[1]), isFalse);
    });
  });

  group('what the server said when it refused', () {
    test('is its message, trimmed', () {
      expect(PosOrderAnswer.refusalMessage(<String, dynamic>{'message': '  Aspirin is not available for order place '}), 'Aspirin is not available for order place');
    });

    test('is nothing when it said nothing', () {
      expect(PosOrderAnswer.refusalMessage(<String, dynamic>{'message': '   '}), isNull);
      expect(PosOrderAnswer.refusalMessage(<String, dynamic>{'message': 5}), isNull);
      expect(PosOrderAnswer.refusalMessage(<String, dynamic>{}), isNull);
      expect(PosOrderAnswer.refusalMessage(null), isNull);
    });
  });

  group('an answer with its status', () {
    test('says a sale was recorded when the status is 200 and the answer names the order', () {
      expect(PosOrderAnswer.isPlacedAnswer(statusCode: 200, data: <String, dynamic>{'order_id': 7}), isTrue);
    });

    test('says nothing was recorded for a 200 that is a refusal, and for a 200 that names no order', () {
      expect(PosOrderAnswer.isPlacedAnswer(statusCode: 200, data: <String, dynamic>{'product_not_available': true, 'message': 'Aspirin is not available for order place'}), isFalse);
      expect(PosOrderAnswer.isPlacedAnswer(statusCode: 200, data: <String, dynamic>{'checkProductTypeForWalkingCustomer': true}), isFalse);
      expect(PosOrderAnswer.isPlacedAnswer(statusCode: 200, data: <String, dynamic>{}), isFalse);
      expect(PosOrderAnswer.isPlacedAnswer(statusCode: 200, data: null), isFalse);
    });

    test('says nothing was recorded for any other status, whatever the answer names', () {
      expect(PosOrderAnswer.isPlacedAnswer(statusCode: 500, data: <String, dynamic>{'order_id': 7}), isFalse);
      expect(PosOrderAnswer.isPlacedAnswer(statusCode: 401, data: <String, dynamic>{'order_id': 7}), isFalse);
      expect(PosOrderAnswer.isPlacedAnswer(statusCode: null, data: <String, dynamic>{'order_id': 7}), isFalse);
    });
  });

  group('the code of the seller app', () {
    String code(String path) => File(path).readAsStringSync();

    test('the cart controller and the POS screen ask the same rule, so the status code alone never decides what happens to a cart', () {
      final String cart = code('lib/features/pos/controllers/cart_controller.dart');
      final String screen = code('lib/features/pos/screens/pos_screen.dart');
      final int sale = screen.indexOf('cartController.placeOrder(');

      expect(sale, greaterThan(0), reason: 'the screen sends the sale through the cart controller');

      final String afterTheSale = screen.substring(sale, screen.indexOf('cartController.removeModifiedTax()', sale));

      expect(cart, contains('PosOrderAnswer.isPlacedAnswer(statusCode: response.response?.statusCode, data: response.response?.data)'));
      expect(cart, contains('PosOrderAnswer.refusalMessage(response.response?.data)'));
      expect(afterTheSale, contains('PosOrderAnswer.isPlacedAnswer(statusCode: value.response?.statusCode, data: value.response?.data)'));
      expect(afterTheSale, isNot(contains('statusCode == 200')), reason: 'a refusal comes with a 200 too, and the cart a refused sale keeps must keep its priced lines');
    });

    test('the outbox asks the same rule for a replayed sale', () {
      final String outbox = code('lib/features/pos/controllers/offline_sales_controller.dart');

      expect(outbox, contains('PosOrderAnswer.isPlaced(response?.response?.data)'));
      expect(outbox, contains('PosOrderAnswer.refusalMessage(response?.response?.data)'));
    });
  });
}
