import 'package:syriacosmeticsmanger/features/inventory/domain/repositories/inventory_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/inventory/domain/services/inventory_service_interface.dart';

class InventoryService implements InventoryServiceInterface {
  final InventoryRepositoryInterface inventoryRepoInterface;
  InventoryService({required this.inventoryRepoInterface});

  @override
  Future getOverview() => inventoryRepoInterface.getOverview();

  @override
  Future getMovements({int? productId, String? type, int offset = 1}) =>
      inventoryRepoInterface.getMovements(productId: productId, type: type, offset: offset);

  @override
  Future getWarehouses({int? productId}) => inventoryRepoInterface.getWarehouses(productId: productId);

  @override
  Future getBatches({int days = 30}) => inventoryRepoInterface.getBatches(days: days);

  @override
  Future adjust({required int productId, required int delta, required String reason, String? note}) =>
      inventoryRepoInterface.adjust(productId: productId, delta: delta, reason: reason, note: note);
}
