import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/returns/domain/models/return_models.dart';

/// Captured verbatim from a running backend
/// (`/api/v3/seller/seller-center/returns`) against a real database, including
/// the receive response after a restock actually happened.
///
/// The distinction the app has to keep is `received` versus `restocked`. Both
/// mean the goods arrived; only one means they can be sold again, and that is
/// the thing a seller is looking at the screen to find out.
void main() {
  const String liveList = '''
  {"total_size":1,"limit":25,"offset":1,
   "statuses":["authorized","in_transit","received","restocked","rejected"],
   "returns":[{"id":1,"reference":"RMA-202608-0001","status":"authorized","product_id":3,
     "product_name":"MEDEE hydra 50 ml","qty":2,"reason":"damaged","restock":true,
     "is_open":true,"received_at":null,"created_at":"2026-08-24T02:40:20.000000Z"}]}''';

  const String liveRestocked = '''
  {"message":"Return updated",
   "return":{"id":1,"reference":"RMA-202608-0001","status":"restocked","product_id":3,
     "product_name":"MEDEE hydra 50 ml","qty":2,"reason":"damaged","restock":true,
     "is_open":false,"received_at":"2026-08-24T02:40:29.000000Z",
     "created_at":"2026-08-24T02:40:20.000000Z"},
   "restocked":true,"balance_after":500}''';

  group('returns contract', () {
    test('parses the live list', () {
      final ReturnListModel list = ReturnListModel.fromJson(jsonDecode(liveList));

      expect(list.totalSize, 1);
      expect(list.statuses, ['authorized', 'in_transit', 'received', 'restocked', 'rejected']);

      final ReturnShipmentModel shipment = list.returns.single;
      expect(shipment.reference, 'RMA-202608-0001');
      expect(shipment.productName, 'MEDEE hydra 50 ml');
      expect(shipment.qty, 2);
      expect(shipment.reason, 'damaged');
      // Still moving, so the screen offers the decisions.
      expect(shipment.isOpen, isTrue);
      expect(shipment.isAuthorized, isTrue);
      expect(shipment.isRestocked, isFalse);
    });

    test('a restocked return is distinguishable from one merely received', () {
      final ReturnShipmentModel restocked = ReturnShipmentModel.fromJson(
          Map<String, dynamic>.from(jsonDecode(liveRestocked)['return'] as Map));

      expect(restocked.isRestocked, isTrue);
      // Closed: nothing left to decide, so the actions disappear.
      expect(restocked.isOpen, isFalse);
      expect(restocked.receivedAt, isNotNull);

      final ReturnShipmentModel received = ReturnShipmentModel.fromJson(jsonDecode(
          '{"id":2,"reference":"RMA-2","status":"received","qty":1,"is_open":false,"restock":false}'));

      // Arrived, but not sellable again — which is why the two are different words.
      expect(received.isRestocked, isFalse);
      expect(received.restock, isFalse);
    });

    test('the ledger carries the credit sellers never see', () {
      final List<ReturnLedgerEntryModel> ledger = (jsonDecode('''
      [{"entry_type":"refund","credit":0,"debit":100,"status":"available","description":"Refund"},
       {"entry_type":"commission_charge","credit":12,"debit":0,"status":"available","description":"Commission reversal"}]''')
              as List)
          .map((row) => ReturnLedgerEntryModel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();

      expect(ledger[0].isCredit, isFalse);
      expect(ledger[0].debit, 100);
      // Without this line a refund leaves the marketplace's cut of a sale it gave
      // back still charged.
      expect(ledger[1].entryType, 'commission_charge');
      expect(ledger[1].isCredit, isTrue);
      expect(ledger[1].credit, 12);
    });

    test('restock defaults to true only because the server sends it that way', () {
      // The flag decides whether goods re-enter stock, so an absent value must not
      // silently mean "do not restock" either — it mirrors what the server sends.
      expect(ReturnShipmentModel.fromJson(<String, dynamic>{}).restock, isTrue);
      expect(ReturnShipmentModel.fromJson({'restock': false}).restock, isFalse);
    });

    test('an empty list is a real answer', () {
      final ReturnListModel list = ReturnListModel.fromJson(jsonDecode(
          '{"total_size":0,"limit":25,"offset":1,"statuses":["authorized"],"returns":[]}'));

      expect(list.returns, isEmpty);
      expect(list.totalSize, 0);
    });

    test('survives a payload with the sections missing', () {
      final ReturnListModel list = ReturnListModel.fromJson(<String, dynamic>{});

      expect(list.returns, isEmpty);
      expect(list.statuses, isEmpty);
    });
  });
}
