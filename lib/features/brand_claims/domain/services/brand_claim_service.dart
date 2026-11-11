import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/features/brand_claims/domain/repositories/brand_claim_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/brand_claims/domain/services/brand_claim_service_interface.dart';

class BrandClaimService implements BrandClaimServiceInterface {
  final BrandClaimRepositoryInterface brandClaimRepoInterface;
  BrandClaimService({required this.brandClaimRepoInterface});

  @override
  Future getExposure() => brandClaimRepoInterface.getExposure();

  @override
  Future getClaims() => brandClaimRepoInterface.getClaims();

  @override
  Future saveClaim(Map<String, dynamic> payload) => brandClaimRepoInterface.saveClaim(payload);

  @override
  Future attachDocument(int claimId, String documentType, MultipartFile file) =>
      brandClaimRepoInterface.attachDocument(claimId, documentType, file);

  @override
  Future removeDocument(int claimId, int documentId) =>
      brandClaimRepoInterface.removeDocument(claimId, documentId);

  @override
  Future submit(int claimId) => brandClaimRepoInterface.submit(claimId);

  @override
  Future withdraw(int claimId) => brandClaimRepoInterface.withdraw(claimId);
}
