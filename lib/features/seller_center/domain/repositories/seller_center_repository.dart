import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/repositories/seller_center_repository_interface.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

class SellerCenterRepository implements SellerCenterRepositoryInterface {
  final DioClient? dioClient;
  SellerCenterRepository({required this.dioClient});

  @override
  Future<ApiResponse> getOverview() async {
    try {
      final response = await dioClient!.get(AppConstants.sellerCenterOverviewUri);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getScorecard() async {
    try {
      final response = await dioClient!.get(AppConstants.sellerScorecardUri);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getVerification() async {
    try {
      final response = await dioClient!.get(AppConstants.sellerVerificationUri);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> submitVerificationDocument({
    required String documentType,
    String? documentNumber,
    String? expiresAt,
    XFile? documentFile,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'document_type': documentType,
        if (documentNumber != null && documentNumber.isNotEmpty) 'document_number': documentNumber,
        if (expiresAt != null && expiresAt.isNotEmpty) 'expires_at': expiresAt,
      };

      final response = await dioClient!.postMultipart(
        AppConstants.sellerVerificationSubmitUri,
        data: data,
        files: documentFile != null
            ? [MultipartWithKey(
                key: 'document_file',
                multipartFile: MultipartFile.fromBytes(
                  await documentFile.readAsBytes(),
                  filename: documentFile.name,
                ),
              )]
            : [],
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getPayouts({int offset = 1}) async {
    try {
      final response = await dioClient!.get(
        AppConstants.sellerPayoutsUri,
        queryParameters: {'limit': 10, 'offset': offset},
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> requestPayout({required double amount, String? method, String? payoutCurrency}) async {
    try {
      final response = await dioClient!.post(AppConstants.sellerPayoutsUri, data: {
        'amount': amount,
        if (method != null && method.isNotEmpty) 'method': method,
        if (payoutCurrency != null && payoutCurrency.isNotEmpty) 'payout_currency': payoutCurrency,
      });
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getAnalytics({String? range}) async {
    try {
      final response = await dioClient!.get(
        AppConstants.sellerAnalyticsUri,
        queryParameters: range != null ? {'range': range} : null,
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> getActivities() async {
    try {
      final response = await dioClient!.get(AppConstants.sellerActivitiesUri);
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> cancelPayout(int id) async {
    try {
      final response = await dioClient!.post('${AppConstants.sellerPayoutsUri}/$id/cancel');
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
