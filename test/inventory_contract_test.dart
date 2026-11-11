import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/inventory/domain/models/inventory_models.dart';

/// Captured verbatim from a running backend
/// (`/api/v3/seller/seller-center/inventory/*`) against a real database.
///
/// Two things the app has to read right. `warehouses_enabled` and
/// `batches_enabled` decide whether a whole section appears at all — defaulting
/// either to true would put an empty warehouse screen in front of a seller who
/// has never been given a warehouse. And `balance_after` is what makes the
/// movement log readable without adding up every change since the beginning.
void main() {
  const String liveOverview = '''
  {"low_stock_threshold":5,"products":2,"out_of_stock":0,"running_low":0,
   "units_on_hand":600,"movements_recorded":0,
   "reasons":["count_correction","damage","loss","theft","found","expiry","other"],
   "movement_types":["adjustment","receipt","sale","return","transfer"],
   "warehouses_enabled":false,"batches_enabled":false}''';

  const String liveMovements = '''
  {"total_size":1,"limit":25,"offset":1,
   "movements":[{"id":3,"product_id":3,"type":"adjustment","qty_change":-2,"balance_after":498,
     "reason":"damage","note":"Broken in transit","created_by_type":"seller",
     "created_at":"2026-08-24T02:23:28.000000Z"}]}''';

  group('inventory contract', () {
    test('parses the live overview', () {
      final InventoryOverviewModel overview = InventoryOverviewModel.fromJson(jsonDecode(liveOverview));

      expect(overview.products, 2);
      expect(overview.unitsOnHand, 600);
      expect(overview.lowStockThreshold, 5);
      // The reasons the correction sheet offers come from the server, so the app
      // cannot offer one the ledger would refuse.
      expect(overview.reasons, contains('damage'));
      expect(overview.reasons, hasLength(7));
      expect(overview.movementTypes, contains('adjustment'));
    });

    test('a module the marketplace does not run stays hidden', () {
      final InventoryOverviewModel overview = InventoryOverviewModel.fromJson(jsonDecode(liveOverview));

      // False, and false by default too — an absent flag must not turn a section on.
      expect(overview.warehousesEnabled, isFalse);
      expect(overview.batchesEnabled, isFalse);
      expect(InventoryOverviewModel.fromJson(<String, dynamic>{}).warehousesEnabled, isFalse);
      expect(InventoryOverviewModel.fromJson(<String, dynamic>{}).batchesEnabled, isFalse);
    });

    test('parses the live movement log', () {
      final StockMovementListModel log = StockMovementListModel.fromJson(jsonDecode(liveMovements));

      expect(log.totalSize, 1);
      final StockMovementModel movement = log.movements.single;
      expect(movement.type, 'adjustment');
      expect(movement.qtyChange, -2);
      // The balance the change left behind, so the log reads without replay.
      expect(movement.balanceAfter, 498);
      expect(movement.reason, 'damage');
      expect(movement.note, 'Broken in transit');
      expect(movement.createdByType, 'seller');
      expect(movement.isIncrease, isFalse);
    });

    test('a positive change reads as an increase', () {
      final StockMovementModel movement = StockMovementModel.fromJson(jsonDecode(
          '{"id":9,"product_id":3,"type":"receipt","qty_change":40,"balance_after":538,"reason":"found"}'));

      expect(movement.isIncrease, isTrue);
      expect(movement.qtyChange, 40);
    });

    test('parses warehouses and batches when they exist', () {
      final WarehouseModel warehouse = WarehouseModel.fromJson(jsonDecode(
          '{"id":4,"name":"Damascus","code":"DAM","address":"Mezzeh","is_default":true,"status":"active"}'));
      final ProductBatchModel batch = ProductBatchModel.fromJson(jsonDecode(
          '{"id":11,"product_id":3,"batch_number":"B-2026-04","expiry_date":"2026-09-30","quantity":24,"status":"active"}'));

      expect(warehouse.name, 'Damascus');
      expect(warehouse.isDefault, isTrue);
      expect(batch.batchNumber, 'B-2026-04');
      expect(batch.expiryDate, '2026-09-30');
      expect(batch.quantity, 24);
    });

    test('an empty log is a real answer, not a broken payload', () {
      final StockMovementListModel log = StockMovementListModel.fromJson(jsonDecode(
          '{"total_size":0,"limit":25,"offset":1,"movements":[]}'));

      expect(log.totalSize, 0);
      expect(log.movements, isEmpty);
    });

    test('survives a payload with the sections missing', () {
      final InventoryOverviewModel overview = InventoryOverviewModel.fromJson(<String, dynamic>{});

      expect(overview.products, 0);
      expect(overview.reasons, isEmpty);
      // With no reasons from the server the correction sheet offers none, which
      // is right: it must never invent a reason the ledger would refuse.
      expect(overview.movementTypes, isEmpty);
    });
  });
}
