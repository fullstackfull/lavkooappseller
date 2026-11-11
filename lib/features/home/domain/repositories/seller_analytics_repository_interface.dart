import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class SellerAnalyticsRepositoryInterface {
  Future<ApiResponse> getEarningStatistics(String? type);

  Future<ApiResponse> getOrderStatistics(String? type);
}
