import 'package:syriacosmeticsmanger/features/home/domain/repositories/seller_analytics_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/home/domain/services/seller_analytics_service_interface.dart';

class SellerAnalyticsService implements SellerAnalyticsServiceInterface {
  SellerAnalyticsRepositoryInterface sellerAnalyticsRepoInterface;
  SellerAnalyticsService({required this.sellerAnalyticsRepoInterface});

  @override
  Future getEarningStatistics(String? type) {
    return sellerAnalyticsRepoInterface.getEarningStatistics(type);
  }

  @override
  Future getOrderStatistics(String? type) {
    return sellerAnalyticsRepoInterface.getOrderStatistics(type);
  }
}
