import 'package:image_picker/image_picker.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/repositories/seller_center_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/services/seller_center_service_interface.dart';

class SellerCenterService implements SellerCenterServiceInterface {
  SellerCenterRepositoryInterface sellerCenterRepoInterface;
  SellerCenterService({required this.sellerCenterRepoInterface});

  @override
  Future getOverview() {
    return sellerCenterRepoInterface.getOverview();
  }

  @override
  Future getScorecard() {
    return sellerCenterRepoInterface.getScorecard();
  }

  @override
  Future getVerification() {
    return sellerCenterRepoInterface.getVerification();
  }

  @override
  Future submitVerificationDocument({
    required String documentType,
    String? documentNumber,
    String? expiresAt,
    XFile? documentFile,
  }) {
    return sellerCenterRepoInterface.submitVerificationDocument(
      documentType: documentType,
      documentNumber: documentNumber,
      expiresAt: expiresAt,
      documentFile: documentFile,
    );
  }

  @override
  Future getPayouts({int offset = 1}) {
    return sellerCenterRepoInterface.getPayouts(offset: offset);
  }

  @override
  Future requestPayout({required double amount, String? method, String? payoutCurrency}) {
    return sellerCenterRepoInterface.requestPayout(
      amount: amount, method: method, payoutCurrency: payoutCurrency,
    );
  }

  @override
  Future cancelPayout(int id) {
    return sellerCenterRepoInterface.cancelPayout(id);
  }

  @override
  Future getAnalytics({String? range}) {
    return sellerCenterRepoInterface.getAnalytics(range: range);
  }

  @override
  Future getActivities() {
    return sellerCenterRepoInterface.getActivities();
  }
}
