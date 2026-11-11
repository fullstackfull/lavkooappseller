import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/analytics_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/payout_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/seller_center_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/verification_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/services/seller_center_service_interface.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';

class SellerCenterController extends ChangeNotifier {
  final SellerCenterServiceInterface sellerCenterServiceInterface;
  SellerCenterController({required this.sellerCenterServiceInterface});

  SellerCenterOverviewModel? _overview;
  SellerCenterOverviewModel? get overview => _overview;

  ScorecardModel? get scorecard => _overview?.performance;

  VerificationStatusModel? _verification;
  VerificationStatusModel? get verification => _verification;

  PayoutOverviewModel? _payouts;
  PayoutOverviewModel? get payouts => _payouts;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  XFile? _pickedDocument;
  XFile? get pickedDocument => _pickedDocument;

  SellerAnalyticsModel? _analytics;
  SellerAnalyticsModel? get analytics => _analytics;

  SellerActivitiesModel? _activities;
  SellerActivitiesModel? get activities => _activities;

  Future<void> getSellerCenterOverview() async {
    ApiResponse apiResponse = await sellerCenterServiceInterface.getOverview();
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      _overview = SellerCenterOverviewModel.fromJson(apiResponse.response!.data);
    } else {
      ApiChecker.checkApi(apiResponse);
    }
    notifyListeners();
  }

  /// Refreshes only the performance metrics, keeping the rest of the overview.
  Future<void> getScorecard() async {
    ApiResponse apiResponse = await sellerCenterServiceInterface.getScorecard();
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      final ScorecardModel performance = ScorecardModel.fromJson(apiResponse.response!.data);
      _overview = SellerCenterOverviewModel(
        verificationStatus: _overview?.verificationStatus,
        kycRequiredForPayout: _overview?.kycRequiredForPayout ?? false,
        performance: performance,
        finance: _overview?.finance,
        openSlaBreachCount: _overview?.openSlaBreachCount ?? 0,
      );
    } else {
      ApiChecker.checkApi(apiResponse);
    }
    notifyListeners();
  }

  Future<void> getVerification() async {
    ApiResponse apiResponse = await sellerCenterServiceInterface.getVerification();
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      _verification = VerificationStatusModel.fromJson(apiResponse.response!.data);
    } else {
      ApiChecker.checkApi(apiResponse);
    }
    notifyListeners();
  }

  void setPickedDocument(XFile? file) {
    _pickedDocument = file;
    notifyListeners();
  }

  /// Returns true when the document reached review, so the caller can close its form.
  Future<bool> submitVerificationDocument({
    required String documentType,
    String? documentNumber,
    String? expiresAt,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    ApiResponse apiResponse = await sellerCenterServiceInterface.submitVerificationDocument(
      documentType: documentType,
      documentNumber: documentNumber,
      expiresAt: expiresAt,
      documentFile: _pickedDocument,
    );
    _isSubmitting = false;

    final bool submitted = apiResponse.response?.statusCode == 200;
    if (submitted) {
      _pickedDocument = null;
      showCustomSnackBarWidget(apiResponse.response?.data['message'], Get.context,
          sanckBarType: SnackBarType.success);
      await getVerification();
    } else {
      _showRefusal(apiResponse);
    }
    notifyListeners();
    return submitted;
  }

  Future<void> getPayouts({int offset = 1}) async {
    ApiResponse apiResponse = await sellerCenterServiceInterface.getPayouts(offset: offset);
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      _payouts = PayoutOverviewModel.fromJson(apiResponse.response!.data);
    } else {
      ApiChecker.checkApi(apiResponse);
    }
    notifyListeners();
  }

  Future<bool> requestPayout({required double amount, String? method, String? payoutCurrency}) async {
    _isSubmitting = true;
    notifyListeners();

    ApiResponse apiResponse = await sellerCenterServiceInterface.requestPayout(
      amount: amount, method: method, payoutCurrency: payoutCurrency,
    );
    _isSubmitting = false;

    final bool requested = apiResponse.response?.statusCode == 200;
    if (requested) {
      showCustomSnackBarWidget(apiResponse.response?.data['message'], Get.context,
          sanckBarType: SnackBarType.success);
      await getPayouts();
      await getSellerCenterOverview();
    } else {
      _showRefusal(apiResponse);
    }
    notifyListeners();
    return requested;
  }

  Future<void> cancelPayout(int id) async {
    ApiResponse apiResponse = await sellerCenterServiceInterface.cancelPayout(id);
    if (apiResponse.response?.statusCode == 200) {
      showCustomSnackBarWidget(apiResponse.response?.data['message'], Get.context,
          sanckBarType: SnackBarType.success);
      await getPayouts();
      await getSellerCenterOverview();
    } else {
      _showRefusal(apiResponse);
    }
    notifyListeners();
  }

  Future<void> getAnalytics({String? range}) async {
    ApiResponse apiResponse = await sellerCenterServiceInterface.getAnalytics(range: range);
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      _analytics = SellerAnalyticsModel.fromJson(apiResponse.response!.data);
    } else {
      ApiChecker.checkApi(apiResponse);
    }
    notifyListeners();
  }

  Future<void> getActivities() async {
    ApiResponse apiResponse = await sellerCenterServiceInterface.getActivities();
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      _activities = SellerActivitiesModel.fromJson(apiResponse.response!.data);
    } else {
      ApiChecker.checkApi(apiResponse);
    }
    notifyListeners();
  }

  /// The API refuses payouts and submissions with a specific reason (balance,
  /// KYC, cooling period, validation). Dio throws on a 403, so there is no
  /// response to read — ApiErrorHandler has already lifted the reason out of
  /// the body into [ApiResponse.error]. Showing that beats a generic failure.
  ///
  /// 'unauthorized' still goes to ApiChecker, which is what signs a seller out
  /// on an expired token.
  void _showRefusal(ApiResponse apiResponse) {
    final String reason = '${apiResponse.error ?? ''}';
    if (reason.isEmpty || reason == 'unauthorized') {
      ApiChecker.checkApi(apiResponse);
      return;
    }
    showCustomSnackBarWidget(getTranslated(reason, Get.context!) ?? reason, Get.context,
        sanckBarType: SnackBarType.error);
  }
}
