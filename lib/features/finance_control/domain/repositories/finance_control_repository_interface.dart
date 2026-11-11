import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class FinanceControlRepositoryInterface {
  /// Does what the seller sold add up to what the seller was paid.
  Future<ApiResponse> getReconciliation({String? from, String? to});

  /// What the marketplace would charge on a sale that has not happened yet.
  Future<ApiResponse> simulateFee(Map<String, dynamic> query);

  /// Who changed this price.
  Future<ApiResponse> getPriceChanges({int? productId, String? source});

  /// The floor the seller has set under their own prices.
  Future<ApiResponse> getPricingPolicy();

  Future<ApiResponse> savePricingPolicy(Map<String, dynamic> payload);
}
