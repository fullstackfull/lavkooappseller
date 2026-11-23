import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/statement/domain/models/statement_models.dart';

/// Captured verbatim from a running backend
/// (`/api/v3/seller/seller-center/statement`) against a real database.
///
/// The distinction the app must not lose is between the two scopes in one
/// payload: `range` follows whatever the seller filtered to, `buckets` and
/// `withdrawable` are the whole account. Reading the second from the first would
/// tell a seller who narrowed to last week that they can withdraw less than they
/// can.
void main() {
  const String liveStatement = '''
  {"total_size":6,"limit":4,"offset":1,
   "entry_types":["order_earning","commission_charge","refund","return_adjustment","shipping_fee",
     "penalty","bonus","manual_adjustment","payout"],
   "statuses":["pending","available","reserved","paid"],
   "summary":{"currency":"SYP",
     "range":{"entries":6,"credits":700,"debits":302,"net":398},
     "buckets":{"pending":0,"available":700,"reserved":-102,"paid":-200,"balance":398},
     "withdrawable":398},
   "entries":[{"id":5,"entry_type":"payout","credit":0,"debit":1,"balance_after":399,
     "status":"reserved","available_at":null,"description":"Reserved for payout request",
     "reference_type":"payout_reserve","reference_id":"pending-6a8b9d6c5b70c","order_id":null,
     "payout_reference":"PO-20260824-2CC0C7","settlement_reference":null,
     "created_at":"2026-08-24T01:25:00.000000Z"}]}''';

  group('statement contract', () {
    test('parses the live payload', () {
      final StatementModel statement = StatementModel.fromJson(jsonDecode(liveStatement));

      expect(statement.totalSize, 6);
      expect(statement.entryTypes, contains('commission_charge'));
      expect(statement.statuses, ['pending', 'available', 'reserved', 'paid']);
      expect(statement.summary.currency, 'SYP');
    });

    test('the range and the account are two different scopes', () {
      final StatementSummaryModel summary =
          StatementModel.fromJson(jsonDecode(liveStatement)).summary;

      // The range follows the filter.
      expect(summary.rangeEntries, 6);
      expect(summary.rangeNet, 398);
      // The account does not.
      expect(summary.available, 700);
      expect(summary.reserved, -102);
      expect(summary.balance, 398);
      // The only figure that answers "how much can I ask for right now".
      expect(summary.withdrawable, 398);
    });

    test('a line traces forward to the payout that took it out', () {
      final StatementEntryModel entry =
          StatementModel.fromJson(jsonDecode(liveStatement)).entries.single;

      expect(entry.entryType, 'payout');
      expect(entry.isCredit, isFalse);
      expect(entry.debit, 1);
      // Read from the ledger, never recomputed by the app.
      expect(entry.balanceAfter, 399);
      expect(entry.payoutReference, 'PO-20260824-2CC0C7');
      expect(entry.orderId, isNull);
    });

    test('a line traces back to the order that earned it', () {
      final StatementEntryModel entry = StatementEntryModel.fromJson(jsonDecode('''
      {"id":9,"entry_type":"order_earning","credit":640,"debit":0,"balance_after":1040,
       "status":"pending","available_at":"2026-08-31T00:00:00+03:00","description":"Order #4242",
       "reference_type":"order_details","reference_id":"12","order_id":4242,
       "payout_reference":null,"settlement_reference":null}'''));

      expect(entry.orderId, 4242);
      expect(entry.isCredit, isTrue);
      // Still inside the return window, and the date it comes out of it.
      expect(entry.isPending, isTrue);
      expect(entry.availableAt, isNotNull);
    });

    test('survives a payload with the sections missing', () {
      final StatementModel statement = StatementModel.fromJson(<String, dynamic>{});

      expect(statement.entries, isEmpty);
      expect(statement.entryTypes, isEmpty);
      // Null, not zero. An absent figure and a balance of nothing are different
      // facts, and the screen draws them differently: one is "we cannot tell
      // you one number", the other is "there is nothing to withdraw". This
      // assertion read `0` and went red when the summary became nullable, which
      // is the test doing its job — the expectation is what had to change.
      expect(statement.summary.withdrawable, isNull);
    });

    // The report proves this for a report (report_contract_test.dart); the
    // statement had no test of its own, although the statement screen is where
    // a seller reads what they can withdraw. A combined total over two
    // currencies is not money, so the server refuses it and names a reason; the
    // app must draw the reason, and must not read the refusal as a zero.
    group('a ledger that holds two currencies', () {
      const String refusedSummary = '''
      {"summary":{"currency":null,
        "range":{"entries":4,"credits":null,"debits":null,"net":null},
        "buckets":{"pending":null,"available":null,"reserved":null,"paid":null,"balance":null},
        "withdrawable":null,
        "totals_refused_because":"totals_of_different_currencies_are_not_added",
        "range_by_currency":[
          {"currency_code":"SAR","credits":700,"debits":302,"net":398},
          {"currency_code":"AED","credits":120,"debits":20,"net":100}],
        "buckets_by_currency":[
          {"currency_code":"SAR","available":700,"balance":398,"withdrawable":398},
          {"currency_code":"AED","available":120,"balance":100,"withdrawable":100}]},
       "entries":[]}''';

      test('refuses the single total and says why, instead of adding riyals to dirhams', () {
        final StatementSummaryModel summary =
            StatementModel.fromJson(jsonDecode(refusedSummary)).summary;

        expect(summary.totalsRefused, isTrue);
        expect(summary.totalsRefusedBecause, 'totals_of_different_currencies_are_not_added');
      });

      test('leaves every combined figure null, because a refused total is not a zero balance', () {
        final StatementSummaryModel summary =
            StatementModel.fromJson(jsonDecode(refusedSummary)).summary;

        expect(summary.withdrawable, isNull, reason: 'a refused withdrawable must not read as 0.00');
        expect(summary.balance, isNull);
        expect(summary.available, isNull);
        expect(summary.reserved, isNull);
        expect(summary.paid, isNull);
        expect(summary.pending, isNull);
        expect(summary.rangeCredits, isNull);
        expect(summary.rangeDebits, isNull);
        expect(summary.rangeNet, isNull);
        expect(summary.currency, isNull, reason: 'no one currency is the account\'s currency');
      });

      test('answers each currency its own real figures, which is what there is to draw', () {
        final StatementSummaryModel summary =
            StatementModel.fromJson(jsonDecode(refusedSummary)).summary;

        expect(summary.rangeByCurrency.map((StatementCurrencyFiguresModel row) => row.currencyCode),
            <String>['SAR', 'AED']);
        expect(summary.rangeByCurrency.first.figures['net'], 398);
        expect(summary.bucketsByCurrency.last.currencyCode, 'AED');
        expect(summary.bucketsByCurrency.last.figures['withdrawable'], 100);
        expect(summary.rangeEntries, 4, reason: 'a count of entries is not money and is still one number');
      });

      test('refuses nothing, and offers no per-currency figures, while the ledger holds one currency', () {
        final StatementSummaryModel summary =
            StatementModel.fromJson(jsonDecode(liveStatement)).summary;

        expect(summary.totalsRefused, isFalse);
        expect(summary.totalsRefusedBecause, isNull);
        expect(summary.rangeByCurrency, isEmpty);
        expect(summary.bucketsByCurrency, isEmpty);
        expect(summary.withdrawable, 398, reason: 'one currency: the combined figure is the answer');
      });
    });
  });
}
