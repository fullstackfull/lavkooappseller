abstract class InventoryServiceInterface {
  Future getOverview();

  Future getMovements({int? productId, String? type, int offset = 1});

  Future getWarehouses({int? productId});

  Future getBatches({int days = 30});

  Future adjust({required int productId, required int delta, required String reason, String? note});
}
