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

  group('the code of the seller app', () {
    String code(String path) => File(path).readAsStringSync();

    test('a 200 that names no order keeps the cart and tells the cashier why', () {
      final String cart = code('lib/features/pos/controllers/cart_controller.dart');
      final int refusal = cart.indexOf('!PosOrderAnswer.isPlaced(response.response?.data)');
      final int success = cart.indexOf("getTranslated('order_placed_successfully'");

      expect(refusal, greaterThan(0), reason: 'the refusal is checked');
      expect(success, greaterThan(refusal), reason: 'before the success is shown');
      expect(cart, contains('PosOrderAnswer.refusalMessage(response.response?.data)'));
    });

    test('a queued sale the server refused is not counted as synced and stays queued with the reason', () {
      final String outbox = code('lib/features/pos/controllers/offline_sales_controller.dart');
      final int check = outbox.indexOf('PosOrderAnswer.isPlaced(response?.response?.data)');
      final int counted = outbox.indexOf('synced++');

      expect(check, greaterThan(0));
      expect(counted, greaterThan(check), reason: 'a sale is counted only after the answer is checked');
      expect(outbox, contains('lastError: PosOrderAnswer.refusalMessage(response?.response?.data)'));
    });
  });
}
