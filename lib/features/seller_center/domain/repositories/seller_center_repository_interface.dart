import 'package:image_picker/image_picker.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

abstract class SellerCenterRepositoryInterface {
  Future<ApiResponse> getOverview();

  Future<ApiResponse> getScorecard();

  Future<ApiResponse> getVerification();

  Future<ApiResponse> submitVerificationDocument({
    required String documentType,
    String? documentNumber,
    String? expiresAt,
    XFile? documentFile,
  });

  Future<ApiResponse> getPayouts({int offset = 1});

  Future<ApiResponse> requestPayout({required double amount, String? method, String? payoutCurrency});

  Future<ApiResponse> cancelPayout(int id);

  Future<ApiResponse> getAnalytics({String? range});

  Future<ApiResponse> getActivities();
}
