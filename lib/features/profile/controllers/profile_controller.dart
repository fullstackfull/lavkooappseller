import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_body.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/data/model/response/response_model.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/models/profile_info.dart';
import 'package:syriacosmeticsmanger/features/profile/domain/services/profice_service_interface.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/helper/api_checker.dart';
import 'package:http/http.dart' as http;
import 'package:syriacosmeticsmanger/helper/country_code_helper.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';

class ProfileController with ChangeNotifier {
  final ProfileServiceInterface profileServiceInterface;

  ProfileController({required this.profileServiceInterface});

  ProfileInfoModel? _userInfoModel;
  ProfileInfoModel? get userInfoModel => _userInfoModel;
  int? _userId;
  int? get userId =>_userId;
  String? _profileImage;
  String? get profileImage =>_profileImage;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _countryDialCode = '+880';
  String? get countryDialCode => _countryDialCode;


  Future<ResponseModel> getSellerInfo() async {
    ResponseModel responseModel;
    ApiResponse apiResponse = await profileServiceInterface.getSellerInfo();
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      _userInfoModel = ProfileInfoModel.fromJson(apiResponse.response!.data);
      _userId = _userInfoModel!.id;
      _profileImage = _userInfoModel!.image;
      responseModel = ResponseModel(true, 'successful');
    } else {
      String? errorMessage;
      if (apiResponse.error is String) {
        errorMessage = apiResponse.error.toString();
      } else {
        errorMessage = apiResponse.error.errors[0].message;
      }
      if (kDebugMode) {
        print(errorMessage);
      }
      responseModel = ResponseModel(false, errorMessage);
      ApiChecker.checkApi(apiResponse);
    }
    notifyListeners();
    return responseModel;
  }

  void setFreeDeliveryStatus(String val){
    _userInfoModel?.freeOverDeliveryAmountStatus = int.parse(val);
    notifyListeners();
  }




  Future<void> updateUserInfo(ProfileInfoModel updateUserModel, ProfileBody seller, File? file, String token, String password) async {
    _isLoading = true;
    notifyListeners();

    http.StreamedResponse response = await profileServiceInterface.updateProfile(updateUserModel, seller, file, token, password);
    final String body = await response.stream.bytesToString();
    _isLoading = false;

    if (response.statusCode == 200) {
      // A password change ends every other session, this one included. The
      // server hands back the replacement token in the same response; adopting
      // it before the next call is what keeps the seller signed in.
      await _adoptRotatedToken(body);

      _userInfoModel = updateUserModel;
      getSellerInfo();
      showCustomSnackBarWidget(getTranslated('updated_successfully', Get.context!) ?? "", Get.context!, isError: false);
    }
    notifyListeners();
  }





  /// Older builds of the API answer with a bare string and no token; a body we
  /// cannot read is simply an update that did not rotate anything.
  Future<void> _adoptRotatedToken(String body) async {
    if (body.isEmpty || Get.context == null) {
      return;
    }

    try {
      final dynamic decoded = jsonDecode(body);
      final Object? token = decoded is Map ? decoded['token'] : null;
      if (token is String && token.isNotEmpty) {
        await Provider.of<AuthController>(Get.context!, listen: false).adoptSessionToken(token);
      }
    } catch (_) {
      // Not JSON, so there is no token in it to adopt.
    }
  }

  Future<ApiResponse> deleteCustomerAccount(BuildContext context) async {
    _isLoading = true;
    notifyListeners();
    ApiResponse apiResponse = await profileServiceInterface.deleteUserAccount();
    _isLoading = false;
    notifyListeners();
    return apiResponse;
  }

  void setCountryDialCode (String? setValue){
    if(setValue != null && setValue.trim() != '') {
      _countryDialCode = setValue;
    } else {
      _countryDialCode = CountryCodeHelper.getCountryCodebyCode(Provider.of<SplashController>(Get.context!, listen: false).configModel!.countryCode)!;
    }
  }

  void updateWalletAmount(String balance) {
    if( _userInfoModel!.wallet!.totalEarning != null){
      _userInfoModel!.wallet!.totalEarning = (_userInfoModel?.wallet?.totalEarning ?? 0) + double.parse(balance);
      if(_userInfoModel?.wallet?.pendingWithdraw != null) {
        _userInfoModel!.wallet!.pendingWithdraw = (_userInfoModel?.wallet?.pendingWithdraw ?? 0) - double.parse(balance);
      }
      notifyListeners();
    }
  }

}
