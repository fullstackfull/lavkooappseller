import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/home/domain/repositories/seller_analytics_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class SellerAnalyticsRepository implements SellerAnalyticsRepositoryInterface {
  final DioClient? dioClient;
  SellerAnalyticsRepository({required this.dioClient});

  @override
  Future<ApiResponse> getEarningStatistics(String? type) async {
    try {
      final response = await dioClient!.get('${AppConstants.chartFilterData}$type');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getOrderStatistics(String? type) async {
    try {
      final response = await dioClient!.get('${AppConstants.businessAnalytics}$type');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
