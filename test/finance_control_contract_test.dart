import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/finance_control/domain/models/finance_control_models.dart';

/// Captured verbatim from a running backend
/// (`/api/v3/seller/seller-center/finance/...`) against a real database.
///
/// The reconciliation payload below is a real shop with a real gap: one line
/// delivered in August with no earning recorded against it. `reconciles` is
/// false and the app must not recompute that from the totals — the server's
/// answer is stricter than comparing two numbers, because a missing earning and
/// an extra credit can cancel out and still leave a seller unpaid for a line.
void main() {
  const String liveReconciliation = '''
  {"from":"2025-01-01","to":"2026-08-24",
   "delivered":{"lines":1,"orders":1,"gross":140},
   "recorded":{"lines":0,"commission":0,"net":0,"source":"not_recorded"},
   "credited":{"entries":1,"amount":500},
   "gaps":{
     "lines_without_earning":{"count":1,"amount":140,"sample":[
       {"order_detail_id":2,"order_id":900001,"qty":3,"price":50,
        "created_at":"2026-08-03 00:00:00"}]},
     "earnings_without_credit":{"count":0,"amount":0,"sample":[]}},
   "reconciles":false}''';

  const String liveSimulation = '''
  {"quantity":3,"unit_price":100,"discount_per_unit":10,"gross":300,
   "commissionable_amount":270,"commission_amount":0,"seller_receives":270,
   "effective_rate_percent":0,
   "rule":{"id":null,"scope":null,"label":"legacy_seller_percentage",
     "rate_type":"percentage","percentage":0,"fixed_amount":0},
   "product":null,
   "excludes":["tax","shipping","payment_processing"]}''';

  group('reconciliation', () {
    final ReconciliationModel report =
        ReconciliationModel.fromJson(jsonDecode(liveReconciliation) as Map<String, dynamic>);

    test('the chain is readable hand-off by hand-off', () {
      expect(report.delivered.lines, 1);
      expect(report.delivered.gross, 140);
      expect(report.recorded.lines, 0);
      expect(report.credited.entries, 1);
    });

    test('the server decides whether it reconciles, not the client', () {
      // The totals here do not match either, but that is not what the flag
      // means, and a client recomputing it would eventually get a shop with
      // matching totals and a missing earning wrong.
      expect(report.reconciles, isFalse);
      expect(report.hasGaps, isTrue);
    });

    test('nothing recorded is a state, not a zero', () {
      // The difference matters: "the marketplace has recorded nothing for this
      // period" is not the same claim as "you earned nothing".
      expect(report.recorded.isRecorded, isFalse);
      expect(report.recorded.source, 'not_recorded');
    });

    test('a gap carries rows the seller can go and look at', () {
      expect(report.linesWithoutEarning.count, 1);
      expect(report.linesWithoutEarning.amount, 140);
      expect(report.linesWithoutEarning.sample.first['order_id'], 900001);
      // Numbers arrive as numbers rather than as decimal strings.
      expect(report.linesWithoutEarning.sample.first['price'], 50);
    });

    test('an empty gap reads as no gap rather than as missing data', () {
      expect(report.earningsWithoutCredit.count, 0);
      expect(report.earningsWithoutCredit.sample, isEmpty);
    });
  });

  group('fee simulator', () {
    test('carries the whole arithmetic, not just the answer', () {
      final FeeSimulationModel result =
          FeeSimulationModel.fromJson(jsonDecode(liveSimulation) as Map<String, dynamic>);

      expect(result.gross, 300);
      expect(result.discountPerUnit, 10);
      expect(result.commissionableAmount, 270);
      expect(result.sellerReceives, 270);
      expect(result.ruleLabel, 'legacy_seller_percentage');
    });

    test('names what it does not cover', () {
      final FeeSimulationModel result =
          FeeSimulationModel.fromJson(jsonDecode(liveSimulation) as Map<String, dynamic>);

      expect(result.excludes, ['tax', 'shipping', 'payment_processing']);
    });

    test('a share of nothing comes back null and stays null', () {
      final FeeSimulationModel result = FeeSimulationModel.fromJson(jsonDecode('''
        {"quantity":1,"unit_price":0,"discount_per_unit":0,"gross":0,
         "commissionable_amount":0,"commission_amount":0,"seller_receives":0,
         "effective_rate_percent":null,
         "rule":{"id":null,"scope":null,"label":null,"rate_type":"percentage",
           "percentage":0,"fixed_amount":0},
         "product":null,"excludes":["tax","shipping","payment_processing"]}''')
          as Map<String, dynamic>);

      // Turning this into 0 on the client would state a rate the marketplace
      // never quoted.
      expect(result.effectiveRatePercent, isNull);
    });
  });

  group('price history', () {
    test('a first price is not a change from nothing', () {
      final PriceChangeModel change = PriceChangeModel.fromJson(jsonDecode('''
        {"id":1,"product_id":4,"previous_price":null,"new_price":100,"delta":0,
         "is_first_price":true,"previous_discount":null,"new_discount":0,
         "previous_discount_type":null,"new_discount_type":"flat","source":"seller_ui",
         "reason":null,"actor_type":"seller","actor_name":"Owner One",
         "created_at":"2026-08-20T10:00:00.000000Z"}''') as Map<String, dynamic>);

      expect(change.isFirstPrice, isTrue);
      expect(change.previousPrice, isNull);
      expect(change.delta, 0);
    });

    test('a change made by a rule names the rule that made it', () {
      final PriceChangeModel change = PriceChangeModel.fromJson(jsonDecode('''
        {"id":2,"product_id":4,"previous_price":100,"new_price":90,"delta":-10,
         "is_first_price":false,"previous_discount":0,"new_discount":10,
         "previous_discount_type":"flat","new_discount_type":"percent","source":"automation",
         "reason":"Clear slow stock","actor_type":null,"actor_name":null,
         "created_at":"2026-08-22T10:00:00.000000Z"}''') as Map<String, dynamic>);

      expect(change.source, 'automation');
      // The answer to "who changed this" when the answer is not a person.
      expect(change.reason, 'Clear slow stock');
      expect(change.delta, -10);
    });
  });
}
