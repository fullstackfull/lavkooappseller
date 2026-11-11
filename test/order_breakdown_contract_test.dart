import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/models/order_breakdown_model.dart';

/// Captured verbatim from a running backend
/// (`/api/v3/seller/orders/{id}/breakdown`) against a real database.
///
/// The case pinned first is the awkward one: an order whose earning has not been
/// booked, where `seller_receives` is null. A model that defaulted that to zero
/// would put "you receive 0" in front of a seller whose money is simply not
/// settled yet, which is worse than saying nothing.
void main() {
  const String liveNotRecorded = '''
  {"order_id":900001,
   "fees":{"source":"not_recorded","currency":"SYP",
     "items":{"count":1,"quantity":3,"price":150,"discount":30,"tax":15},
     "commissionable_amount":null,"commission_amount":null,"commission_rules":[],
     "reversed_amount":null,"seller_receives":null,"is_settled":false,
     "shipping":{"cost":5,"borne_by":"inhouse_shipping","is_free":false,"deliveryman_charge":0},
     "order_total":200,"payment_method":"cash_on_delivery","payment_status":"unpaid","ledger":[]},
   "timeline":[{"key":"order_placed","at":"2026-08-03T00:00:00+03:00","actor":null,"note":null}],
   "sla":null}''';

  group('order breakdown contract', () {
    test('parses the live payload for an unsettled order', () {
      final OrderBreakdownModel breakdown = OrderBreakdownModel.fromJson(jsonDecode(liveNotRecorded));

      expect(breakdown.orderId, 900001);
      expect(breakdown.fees?.source, 'not_recorded');
      expect(breakdown.fees?.isSettled, isFalse);
      // Null, not zero. The difference is the whole feature.
      expect(breakdown.fees?.sellerReceives, isNull);
      expect(breakdown.fees?.commissionAmount, isNull);
      // What the order itself states is still a fact and is still shown.
      expect(breakdown.fees?.itemsPrice, 150);
      expect(breakdown.fees?.quantity, 3);
      expect(breakdown.fees?.orderTotal, 200);
      expect(breakdown.fees?.currency, 'SYP');
    });

    test('an order that no longer waits on the seller carries no countdown', () {
      final OrderBreakdownModel breakdown = OrderBreakdownModel.fromJson(jsonDecode(liveNotRecorded));

      // Once it is with the courier a countdown would blame the seller for
      // someone else's clock.
      expect(breakdown.sla, isNull);
      expect(breakdown.timeline, hasLength(1));
      expect(breakdown.timeline.first.key, 'order_placed');
    });

    test('a settled order carries the rule that charged, not just the amount', () {
      final OrderBreakdownModel breakdown = OrderBreakdownModel.fromJson(jsonDecode('''
      {"order_id":5001,
       "fees":{"source":"commission_ledger","currency":"SYP","is_settled":true,
         "items":{"count":1,"quantity":3,"price":150,"discount":30,"tax":15},
         "commissionable_amount":150,"commission_amount":18,"seller_receives":132,"reversed_amount":0,
         "commission_rules":[{"label":"Cosmetics 12%","scope":"category","rate_type":"percentage",
           "percentage":12,"fixed_amount":null,"commissionable_amount":150,"commission_amount":18}],
         "shipping":{"cost":5,"borne_by":"seller","is_free":false,"deliveryman_charge":0},
         "order_total":200,"payment_method":"cash_on_delivery","payment_status":"unpaid",
         "ledger":[{"entry_type":"order_earning","credit":150,"debit":0,"status":"pending",
           "available_at":"2026-08-31T00:00:00+03:00","description":"Order #5001",
           "created_at":"2026-08-24T00:00:00+03:00"}]},
       "timeline":[],"sla":null}'''));

      expect(breakdown.fees?.sellerReceives, 132);
      expect(breakdown.fees?.commissionAmount, 18);
      expect(breakdown.fees?.rules.first.label, 'Cosmetics 12%');
      expect(breakdown.fees?.rules.first.percentage, 12);
      // When the pending earning becomes withdrawable.
      expect(breakdown.fees?.ledger.first.status, 'pending');
      expect(breakdown.fees?.ledger.first.availableAt, isNotNull);
      expect(breakdown.fees?.ledger.first.credit, 150);
    });

    test('a countdown is read as a signed number so one field says both things', () {
      final OrderBreakdownModel onTime = OrderBreakdownModel.fromJson(jsonDecode('''
      {"order_id":1,"fees":null,"timeline":[],
       "sla":{"deadline":"2026-08-25T00:00:00+03:00","hours_left":20.0,"is_late":false,"window_hours":24}}'''));
      final OrderBreakdownModel late = OrderBreakdownModel.fromJson(jsonDecode('''
      {"order_id":1,"fees":null,"timeline":[],
       "sla":{"deadline":"2026-08-22T00:00:00+03:00","hours_left":-6.5,"is_late":true,"window_hours":24}}'''));

      expect(onTime.sla?.hoursLeft, 20.0);
      expect(onTime.sla?.isLate, isFalse);
      expect(onTime.sla?.windowHours, 24);
      expect(late.sla?.hoursLeft, -6.5);
      expect(late.sla?.isLate, isTrue);
    });

    test('the timeline keeps who caused each event', () {
      final OrderBreakdownModel breakdown = OrderBreakdownModel.fromJson(jsonDecode('''
      {"order_id":1,"fees":null,"sla":null,
       "timeline":[{"key":"order_placed","at":"2026-08-24T10:00:00+03:00","actor":null,"note":null},
         {"key":"status_canceled","at":"2026-08-24T12:00:00+03:00","actor":"customer","note":"Changed mind"}]}'''));

      // A seller chasing a cancellation needs to know whether it was them, the
      // customer, or the marketplace.
      expect(breakdown.timeline, hasLength(2));
      expect(breakdown.timeline[1].actor, 'customer');
      expect(breakdown.timeline[1].note, 'Changed mind');
    });

    test('survives a payload with the sections missing', () {
      final OrderBreakdownModel breakdown = OrderBreakdownModel.fromJson(<String, dynamic>{});

      expect(breakdown.fees, isNull);
      expect(breakdown.sla, isNull);
      expect(breakdown.timeline, isEmpty);
    });
  });
}
