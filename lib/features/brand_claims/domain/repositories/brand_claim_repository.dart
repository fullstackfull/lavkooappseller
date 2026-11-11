import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/brand_claims/domain/repositories/brand_claim_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class BrandClaimRepository implements BrandClaimRepositoryInterface {
  final DioClient? dioClient;
  BrandClaimRepository({required this.dioClient});

  @override
  Future<ApiResponse> getExposure() => _get('${AppConstants.brandClaimsUri}/exposure');

  @override
  Future<ApiResponse> getClaims() => _get(AppConstants.brandClaimsUri);

  @override
  Future<ApiResponse> saveClaim(Map<String, dynamic> payload) async {
    try {
      final response = await dioClient!.post(AppConstants.brandClaimsUri, data: payload);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> attachDocument(int claimId, String documentType, MultipartFile file) async {
    try {
      final response = await dioClient!.postMultipart(
        '${AppConstants.brandClaimsUri}/$claimId/documents',
        data: {'document_type': documentType},
        files: [MultipartWithKey(key: 'file', multipartFile: file)],
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> removeDocument(int claimId, int documentId) async {
    try {
      final response =
          await dioClient!.delete('${AppConstants.brandClaimsUri}/$claimId/documents/$documentId');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> submit(int claimId) => _post('${AppConstants.brandClaimsUri}/$claimId/submit');

  @override
  Future<ApiResponse> withdraw(int claimId) => _post('${AppConstants.brandClaimsUri}/$claimId/withdraw');

  Future<ApiResponse> _get(String uri) async {
    try {
      final response = await dioClient!.get(uri);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponse> _post(String uri) async {
    try {
      final response = await dioClient!.post(uri, data: const <String, dynamic>{});
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
