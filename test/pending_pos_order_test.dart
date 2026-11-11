import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';

void main() {
  group('PendingPosOrder', () {
    final PendingPosOrder order = PendingPosOrder(
      id: '42',
      body: <String, dynamic>{'order_amount': 1500000, 'cart': <dynamic>[]},
      createdAt: DateTime.utc(2026, 8, 19, 10, 30),
      orderAmount: 1500000,
      customerName: 'زبون نقدي',
    );

    test('survives an encode/decode round trip', () {
      final PendingPosOrder? restored = PendingPosOrder.decode(order.encode());
      expect(restored, isNotNull);
      expect(restored!.id, '42');
      expect(restored.orderAmount, 1500000);
      expect(restored.customerName, 'زبون نقدي');
      expect(restored.createdAt, order.createdAt);
      expect(restored.body['order_amount'], 1500000);
    });

    test('decode returns null on corrupt storage instead of throwing', () {
      expect(PendingPosOrder.decode('not json'), isNull);
      expect(PendingPosOrder.decode('[]'), isNull);
    });

    test('copyWith bumps the retry count without losing the body', () {
      final PendingPosOrder retried = order.copyWith(attempts: 3, lastError: 'timeout');
      expect(retried.attempts, 3);
      expect(retried.lastError, 'timeout');
      expect(retried.body, order.body);
      expect(retried.id, order.id);
    });
  });
}
