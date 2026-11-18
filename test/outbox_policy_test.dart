import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/outbox_policy.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/pending_pos_order.dart';

PendingPosOrder _sale(String id, {int attempts = 0, String? lastError, String? key}) => PendingPosOrder(
      id: id,
      body: <String, dynamic>{'order_amount': 1500},
      createdAt: DateTime.utc(2026, 11, 18, 10, 30),
      orderAmount: 1500,
      customerName: 'Walk-In Customer',
      attempts: attempts,
      lastError: lastError,
      idempotencyKey: key,
    );

/// K-18: a queued sale is the only record of money taken at the counter. An earlier version deleted it after its tenth failed replay without a word, so the seller never learned that a sale had not
/// been recorded. It stays on the device with its last error until the seller retries it or removes it, and it is not replayed by every return of the connection in the meantime.
void main() {
  group('a queued sale', () {
    test('has failed when it has used its ten attempts, and not before', () {
      expect(OutboxPolicy.maxAttempts, 10);
      expect(OutboxPolicy.hasFailed(_sale('a', attempts: 0)), isFalse);
      expect(OutboxPolicy.hasFailed(_sale('a', attempts: 9)), isFalse);
      expect(OutboxPolicy.hasFailed(_sale('a', attempts: 10)), isTrue);
      expect(OutboxPolicy.hasFailed(_sale('a', attempts: 11)), isTrue);
    });

    test('is replayed by itself only while it has not failed', () {
      expect(OutboxPolicy.isReplayedAutomatically(_sale('a', attempts: 9)), isTrue);
      expect(OutboxPolicy.isReplayedAutomatically(_sale('a', attempts: 10)), isFalse);
    });

    test('the failed ones among a queue are the sales that used their attempts, in the order they were queued', () {
      final List<PendingPosOrder> queue = <PendingPosOrder>[_sale('a', attempts: 10), _sale('b', attempts: 2), _sale('c', attempts: 12), _sale('d')];

      expect(OutboxPolicy.failedAmong(queue).map((PendingPosOrder sale) => sale.id).toList(), <String>['a', 'c']);
    });
  });

  group('the seller asks for the failed sales to be tried again', () {
    test('each failed sale gets its attempts back and keeps its reason and its key; the others are as they were', () {
      final List<PendingPosOrder> queue = <PendingPosOrder>[
        _sale('a', attempts: 10, lastError: 'sale_refused', key: 'key-a'),
        _sale('b', attempts: 3, lastError: 'timeout', key: 'key-b'),
      ];

      final List<PendingPosOrder> reopened = OutboxPolicy.withFailedSalesReopened(queue);

      expect(reopened.map((PendingPosOrder sale) => sale.attempts).toList(), <int>[0, 3]);
      expect(reopened.map((PendingPosOrder sale) => sale.lastError).toList(), <String?>['sale_refused', 'timeout']);
      expect(reopened.map((PendingPosOrder sale) => sale.idempotencyKey).toList(), <String?>['key-a', 'key-b'], reason: 'a retry is a replay of the same sale under the same key');
      expect(queue.first.attempts, 10, reason: 'the queue it was given is not changed');
    });

    test('a queue with nothing failed is returned as it was', () {
      final List<PendingPosOrder> queue = <PendingPosOrder>[_sale('a', attempts: 4)];

      expect(OutboxPolicy.withFailedSalesReopened(queue).single.attempts, 4);
    });
  });

  group('the code of the seller app', () {
    String code(String path) => File(path).readAsStringSync();

    test('the outbox never drops a sale after its failed replays and does not replay a failed sale by itself', () {
      final String outbox = code('lib/features/pos/controllers/offline_sales_controller.dart');

      expect(outbox, isNot(contains('_maxAttempts')), reason: 'no private ceiling after which a sale disappears');
      expect(RegExp(r'attempts\s*<').hasMatch(outbox), isFalse, reason: 'no comparison of the attempts decides whether a sale is kept');
      expect(outbox, contains('if (!OutboxPolicy.isReplayedAutomatically(order))'));
      expect(outbox, contains('OutboxPolicy.withFailedSalesReopened(_pending)'));
    });

    test('the banner says how many sales could not be sent and opens them', () {
      final String banner = code('lib/features/pos/widgets/offline_sales_banner.dart');

      expect(banner, contains("getTranslated('sales_not_sent', context)"));
      expect(banner, contains('FailedSalesSheet.show(context)'));
    });

    test('the sheet removes a sale only after the seller said yes, and never by itself', () {
      final String sheet = code('lib/features/pos/widgets/failed_sales_sheet.dart');

      expect(sheet, contains('if (confirmed == true)'));
      expect(sheet.indexOf('offline.remove(order.id)'), greaterThan(sheet.indexOf('if (confirmed == true)')));
      expect('offline.remove('.allMatches(sheet).length, 1, reason: 'one place removes a sale');
      expect(sheet, contains('offline.retryFailedSales()'));
      expect(sheet, contains('order.lastError'), reason: 'the reason is shown');
    });

    test('the words of the sheet exist in both languages, and the Arabic is Arabic', () {
      for (final String key in <String>['sales_not_sent', 'sales_not_sent_explained', 'remove_sale', 'remove_sale_confirmation']) {
        final Map<String, dynamic> english = jsonDecode(File('assets/language/en.json').readAsStringSync()) as Map<String, dynamic>;
        final Map<String, dynamic> arabic = jsonDecode(File('assets/language/ar.json').readAsStringSync()) as Map<String, dynamic>;

        expect(english[key], isA<String>(), reason: 'en $key');
        expect(arabic[key], matches(RegExp(r'[؀-ۿ]')), reason: 'ar $key');
      }
    });
  });
}
