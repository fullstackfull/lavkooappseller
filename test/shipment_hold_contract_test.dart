import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/order_details/domain/models/shipment_hold_model.dart';

/// The shape `/api/v3/seller/orders/{id}/shipment-holds` answers (H1-04, H1-06).
///
/// A shipment can be held for something the seller can act on -- a product with no permission to reach the order's destination, a
/// regulated product with no licence on file -- and the reason was written by the dispatcher and read only by the admin panel, so a seller
/// watching an order that never moved could not find out why.
///
/// The reason arrives already in the seller's language, because the server translates it for the request. So nothing here is translated
/// and no key is kept in step: a reason added on the server reaches the seller without another release. The awkward case pinned below is a
/// hold with no reason recorded, where null has to stay null -- a screen that invented a cause would be worse than one that says it is
/// held and nothing more.
void main() {
  const String liveHeld = '''
  {"holds":[
    {"id":77,"reason_code":"hold_route_unsupported",
     "reason":"This product is not permitted to be shipped to that country.","held_at":"2026-11-24T22:10:00+03:00"},
    {"id":78,"reason_code":null,"reason":null,"held_at":"2026-11-24T22:11:00+03:00"}
  ]}''';

  group('shipment holds contract', () {
    test('parses the live payload, reason and all', () {
      final List<ShipmentHoldModel> holds = ShipmentHoldModel.listFrom(jsonDecode(liveHeld));

      expect(holds.length, 2);
      expect(holds.first.id, 77);
      expect(holds.first.reasonCode, 'hold_route_unsupported');
      expect(holds.first.reason, 'This product is not permitted to be shipped to that country.');
      expect(holds.first.heldAt, '2026-11-24T22:10:00+03:00');
    });

    test('a hold with no reason recorded keeps null rather than inventing one', () {
      final List<ShipmentHoldModel> holds = ShipmentHoldModel.listFrom(jsonDecode(liveHeld));

      expect(holds[1].reason, isNull);
      expect(holds[1].reasonCode, isNull);
      expect(holds[1].id, 78);
    });

    test('an Arabic reason is read as the server wrote it', () {
      final List<ShipmentHoldModel> holds = ShipmentHoldModel.listFrom(jsonDecode(
        '{"holds":[{"id":1,"reason_code":"hold_route_unsupported","reason":"هذا المنتج غير مصرَّح بشحنه إلى ذلك البلد.","held_at":null}]}',
      ));

      expect(holds.single.reason, 'هذا المنتج غير مصرَّح بشحنه إلى ذلك البلد.');
      expect(holds.single.heldAt, isNull);
    });

    test('an order with nothing held is an empty list, not a null to guard against', () {
      expect(ShipmentHoldModel.listFrom(jsonDecode('{"holds":[]}')), isEmpty);
    });

    test('a body that is not this answer reads as nothing held rather than throwing', () {
      for (final Object? body in <Object?>[
        null,
        'a string',
        <String, Object?>{},
        <String, Object?>{'holds': null},
        <String, Object?>{'holds': 'not a list'},
        <String, Object?>{'holds': <Object?>[null, 7, 'text']},
      ]) {
        expect(ShipmentHoldModel.listFrom(body), isEmpty);
      }
    });

    test('an id the server sends as text is still read', () {
      final List<ShipmentHoldModel> holds = ShipmentHoldModel.listFrom(jsonDecode('{"holds":[{"id":"42","reason":"Held."}]}'));

      expect(holds.single.id, 42);
      expect(holds.single.reason, 'Held.');
    });

    test('a blank reason is read as none, because a blank line tells a seller nothing', () {
      final List<ShipmentHoldModel> holds = ShipmentHoldModel.listFrom(jsonDecode('{"holds":[{"id":1,"reason":"   "}]}'));

      expect(holds.single.reason, isNull);
    });
  });
}
