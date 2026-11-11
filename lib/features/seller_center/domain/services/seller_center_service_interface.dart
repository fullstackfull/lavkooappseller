import 'package:image_picker/image_picker.dart';

abstract class SellerCenterServiceInterface {
  Future<dynamic> getOverview();

  Future<dynamic> getScorecard();

  Future<dynamic> getVerification();

  Future<dynamic> submitVerificationDocument({
    required String documentType,
    String? documentNumber,
    String? expiresAt,
    XFile? documentFile,
  });

  Future<dynamic> getPayouts({int offset = 1});

  Future<dynamic> requestPayout({required double amount, String? method, String? payoutCurrency});

  Future<dynamic> cancelPayout(int id);

  Future<dynamic> getAnalytics({String? range});

  Future<dynamic> getActivities();
}
