abstract class SellerAnalyticsServiceInterface {
  Future<dynamic> getEarningStatistics(String? type);

  Future<dynamic> getOrderStatistics(String? type);
}
