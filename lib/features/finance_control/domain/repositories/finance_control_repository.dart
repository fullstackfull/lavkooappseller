import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/finance_control/domain/repositories/finance_control_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class FinanceControlRepository implements FinanceControlRepositoryInterface {
  final DioClient? dioClient;
  FinanceControlRepository({required this.dioClient});

  @override
  Future<ApiResponse> getReconciliation({String? from, String? to}) => _get(
        '${AppConstants.sellerFinanceUri}/reconciliation',
        {if (from != null) 'from': from, if (to != null) 'to': to},
      );

  @override
  Future<ApiResponse> simulateFee(Map<String, dynamic> query) =>
      _get('${AppConstants.sellerFinanceUri}/fee-simulator', query);

  @override
  Future<ApiResponse> getPriceChanges({int? productId, String? source}) => _get(
        '${AppConstants.sellerFinanceUri}/price-changes',
        {
          if (productId != null) 'product_id': '$productId',
          if (source != null) 'source': source,
        },
      );

  Future<ApiResponse> _get(String uri, Map<String, dynamic> query) async {
    try {
      final String suffix = query.isEmpty
          ? ''
          : '?${query.entries.map((e) => '${e.key}=${Uri.encodeComponent('${e.value}')}').join('&')}';
      final response = await dioClient!.get('$uri$suffix');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getPricingPolicy() async {
    try {
      return ApiResponse.withSuccess(await dioClient!.get('${AppConstants.sellerFinanceUri}/pricing-policy'));
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> savePricingPolicy(Map<String, dynamic> payload) async {
    try {
      return ApiResponse.withSuccess(
        await dioClient!.put('${AppConstants.sellerFinanceUri}/pricing-policy', data: payload),
      );
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
