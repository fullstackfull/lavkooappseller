abstract class FinanceControlServiceInterface {
  Future<dynamic> getReconciliation({String? from, String? to});
  Future<dynamic> simulateFee(Map<String, dynamic> query);
  Future<dynamic> getPriceChanges({int? productId, String? source});

  Future getPricingPolicy();

  Future savePricingPolicy(Map<String, dynamic> payload);
}
