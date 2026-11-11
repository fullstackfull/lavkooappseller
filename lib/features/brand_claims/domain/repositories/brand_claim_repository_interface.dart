import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class BrandClaimRepositoryInterface {
  /// Which brands the seller sells under, and where each one stands.
  Future<ApiResponse> getExposure();

  Future<ApiResponse> getClaims();

  Future<ApiResponse> saveClaim(Map<String, dynamic> payload);

  Future<ApiResponse> attachDocument(int claimId, String documentType, MultipartFile file);

  Future<ApiResponse> removeDocument(int claimId, int documentId);

  Future<ApiResponse> submit(int claimId);

  Future<ApiResponse> withdraw(int claimId);
}
