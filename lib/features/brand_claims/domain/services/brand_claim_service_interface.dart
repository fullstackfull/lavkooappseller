import 'package:dio/dio.dart';

abstract class BrandClaimServiceInterface {
  Future<dynamic> getExposure();
  Future<dynamic> getClaims();
  Future<dynamic> saveClaim(Map<String, dynamic> payload);
  Future<dynamic> attachDocument(int claimId, String documentType, MultipartFile file);
  Future<dynamic> removeDocument(int claimId, int documentId);
  Future<dynamic> submit(int claimId);
  Future<dynamic> withdraw(int claimId);
}
