import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/models/register_model.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/data/model/response/response_model.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/services/auth_service_interface.dart';
import 'package:syriacosmeticsmanger/features/auth/enums/from_page.dart';
import 'package:syriacosmeticsmanger/features/auth/screens/otp_verification_screen.dart';
import 'package:syriacosmeticsmanger/features/auth/widgets/reset_password_widget.dart';
import 'package:syriacosmeticsmanger/features/shop/controllers/shop_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/models/config_model.dart';
import 'package:syriacosmeticsmanger/helper/image_size_checker.dart';
import 'package:syriacosmeticsmanger/localization/app_localization.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';

class AuthController with ChangeNotifier {
  final AuthServiceInterface authServiceInterface;
  AuthController({required this.authServiceInterface});
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  final String _loginErrorMessage = '';
  String get loginErrorMessage => _loginErrorMessage;
  XFile? _sellerProfileImage;
  XFile? _shopLogo;
  XFile? _shopBanner;
  XFile? secondaryBanner;
  XFile? offerBanner;
  XFile? get sellerProfileImage => _sellerProfileImage;
  XFile? get shopLogo => _shopLogo;
  XFile? get shopBanner => _shopBanner;
  bool? _isTermsAndCondition = false;
  bool? get isTermsAndCondition => _isTermsAndCondition;
  bool _isActiveRememberMe = false;
  bool get isActiveRememberMe => _isActiveRememberMe;
  int _selectionTabIndex = 1;
  int get selectionTabIndex =>_selectionTabIndex;
  String _verificationCode = '';
  String get verificationCode => _verificationCode;
  bool _isEnableVerificationCode = false;
  bool get isEnableVerificationCode => _isEnableVerificationCode;
  String? _verificationMsg = '';
  String? get verificationMessage => _verificationMsg;
  final String _email = '';
  final String _phone = '';
  String get email => _email;
  String get phone => _phone;
  bool _isPhoneNumberVerificationButtonLoading = false;
  bool get isPhoneNumberVerificationButtonLoading => _isPhoneNumberVerificationButtonLoading;
  String? _countryDialCode = '+880';
  String? get countryDialCode => _countryDialCode;

  bool _resendButtonLoading = false;
  bool get resendButtonLoading => _resendButtonLoading;

  String? _verificationID = '';
  String? get verificationID => _verificationID;


  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController shopNameController = TextEditingController();
  TextEditingController shopAddressController = TextEditingController();
  TextEditingController tinNumberController = TextEditingController();

  FocusNode firstNameNode = FocusNode();
  FocusNode lastNameNode = FocusNode();
  FocusNode emailNode = FocusNode();
  FocusNode phoneNode = FocusNode();
  FocusNode passwordNode = FocusNode();
  FocusNode confirmPasswordNode = FocusNode();
  FocusNode shopNameNode = FocusNode();
  FocusNode shopAddressNode = FocusNode();

  bool _lengthCheck = false;
  bool _numberCheck = false;
  bool _uppercaseCheck = false;
  bool _lowercaseCheck = false;
  bool _spatialCheck = false;
  bool _showPassView = false;

  bool get lengthCheck => _lengthCheck;
  bool get numberCheck => _numberCheck;
  bool get uppercaseCheck => _uppercaseCheck;
  bool get lowercaseCheck => _lowercaseCheck;
  bool get spatialCheck => _spatialCheck;
  bool get showPassView => _showPassView;

  bool _isUnAuthorize = false;
  bool get isUnAuthorize => _isUnAuthorize;

  Future<ApiResponse> login(BuildContext context, {String? emailAddress, String? password}) async {
    _isLoading = true;
    notifyListeners();
    ApiResponse apiResponse = await authServiceInterface.login(emailAddress: emailAddress, password: password);
    _isLoading = false;
    notifyListeners();
    if(apiResponse.response?.statusCode == 200) {
      await Provider.of<AuthController>(Get.context!, listen: false).updateToken(Get.context!);
      setCurrentLanguage(Provider.of<LocalizationController>(Get.context!, listen: false).getCurrentLanguage());
      setUnAuthorize(false);
      notifyListeners();
    }
    return apiResponse;
  }

  Future<void> setCurrentLanguage(String currentLanguage) async {
    // The endpoint is behind the seller guard, so calling it from the login or
    // splash screen is a guaranteed 401. The locale is applied locally either
    // way; the server only needs telling once there is a session to tell it
    // about, and login sends it again right after.
    if (!isLoggedIn()) {
      return;
    }

    await authServiceInterface.setLanguageCode(currentLanguage);
  }

  Future<ResponseModel?> forgotPassword(String email, bool isNumber, ConfigModel? config, {FromPage? fromPage})async {
    bool isResend = fromPage == FromPage.verification;
    ResponseModel? responseModel;

    _isLoading = true;
    if(isResend) {
      _resendButtonLoading = true;
    }
    notifyListeners();

    if(isNumber && config?.forgotPasswordVerification == 'phone' &&  config?.vendorForgotPasswordSmsMethod == 'firebase') {
      checkVendorExistPhone(email).then((response) {
        if(response.response?.statusCode == 200) {
          firebaseVerifyPhoneNumber(email, isResend: isResend, isForgetPassword: true);
        } else {
          _isLoading = false;
          if(isResend) {
            _resendButtonLoading = false;
          }
          notifyListeners();
          showCustomSnackBarWidget(response.error, Get.context!, sanckBarType: SnackBarType.error);
        }
      });
    } else {
      responseModel = await authServiceInterface.forgotPassword(email);
      _isLoading = false;
    }


    if(isResend) {
      _resendButtonLoading = false;
    }
    notifyListeners();
    return responseModel;
  }

/*
  Future<ResponseModel?> forgotPassword(
      String email,
      bool isNumber,
      ConfigModel? config,
      {FromPage? fromPage}
      ) async {

    bool isResend = fromPage == FromPage.verification;
    ResponseModel? responseModel;

    debugPrint("========== AUTH CONTROLLER FORGOT START ==========");
    debugPrint("EMAIL/IDENTITY: $email");
    debugPrint("IS NUMBER: $isNumber");
    debugPrint("FORGOT TYPE: ${config?.forgotPasswordVerification}");
    debugPrint("SMS METHOD: ${config?.vendorForgotPasswordSmsMethod}");
    debugPrint("=================================================");


    _isLoading = true;

    if(isResend) {
      _resendButtonLoading = true;
    }

    notifyListeners();


    if(isNumber &&
        config?.forgotPasswordVerification == 'phone' &&
        config?.vendorForgotPasswordSmsMethod == 'firebase') {


      debugPrint("========== FIREBASE PHONE FLOW ==========");


      checkVendorExistPhone(email).then((response) {

        debugPrint("CHECK PHONE STATUS: ${response.response?.statusCode}");
        debugPrint("CHECK PHONE DATA: ${response.response?.data}");
        debugPrint("CHECK PHONE ERROR: ${response.error}");


        if(response.response?.statusCode == 200) {

          debugPrint("PHONE EXISTS -> START FIREBASE OTP");

          firebaseVerifyPhoneNumber(
            email,
            isResend: isResend,
            isForgetPassword: true,
          );


        } else {

          debugPrint("PHONE NOT FOUND");

          _isLoading = false;

          if(isResend) {
            _resendButtonLoading = false;
          }

          notifyListeners();


          showCustomSnackBarWidget(
            response.error,
            Get.context!,
            sanckBarType: SnackBarType.error,
          );
        }

      });


    } else {


      debugPrint("========== EMAIL API FLOW ==========");


      responseModel = await authServiceInterface.forgotPassword(email);


      debugPrint("API RESPONSE MODEL: ${responseModel?.isSuccess}");
      debugPrint("API MESSAGE: ${responseModel?.message}");


      _isLoading = false;

    }


    if(isResend) {
      _resendButtonLoading = false;
    }


    notifyListeners();


    debugPrint("========== AUTH CONTROLLER FORGOT END ==========");


    return responseModel;
  }
 */

  Future<void> updateToken(BuildContext context) async {
      await authServiceInterface.updateToken();
  }

  void updateTermsAndCondition(bool? value) {
    _isTermsAndCondition = value;
    notifyListeners();
  }

  void toggleRememberMe() {
    _isActiveRememberMe = !_isActiveRememberMe;
    notifyListeners();
  }

  void setIndexForTabBar(int index, {bool isNotify = true}){
    _selectionTabIndex = index;
    if(isNotify){
      notifyListeners();
    }
  }

  bool isLoggedIn() {
    return authServiceInterface.isLoggedIn();
  }

  Future<bool> clearSharedData({bool fromUnAuthorizationError = false}) async {
    if(fromUnAuthorizationError){
      if (kDebugMode) {
        print("===Inside==fromUnAuthorizationError");
      }
    }
    Provider.of<ShopController>(Get.context!, listen: false).clearShopModel();
    return await authServiceInterface.clearSharedData();
  }

  void saveUserNumberAndPassword(String number, String password) {
    authServiceInterface.saveUserNumberAndPassword(number, password);
  }

  String getUserEmail() {
    return authServiceInterface.getUserEmail();
  }

  String getUserPassword() {
    return authServiceInterface.getUserPassword();
  }

  /// Must complete before the login screen prefills its fields.
  Future<void> primeCredentialCache() => authServiceInterface.primeCredentialCache();

  Future<bool> clearUserEmailAndPassword() async {
    return await authServiceInterface.clearUserNumberAndPassword();
  }

  String getUserToken() {
    return authServiceInterface.getUserToken();
  }

  /// Adopt a session token the server issued outside the login flow.
  ///
  /// Changing the password ends every other session; the server hands the
  /// caller its replacement in the same response. Without adopting it the app
  /// keeps sending the credential it just invalidated, and every request after
  /// a password change comes back 401 — all the way back to the login screen.
  Future<void> adoptSessionToken(String token) async {
    if (token.trim().isEmpty) {
      return;
    }

    await authServiceInterface.saveUserToken(token);
  }


  void updateVerificationCode(String query) {
    if (query.length == 6) {
      _isEnableVerificationCode = true;
    } else {
      _isEnableVerificationCode = false;
    }
    _verificationCode = query;
    notifyListeners();
  }



  Future<ResponseModel> verifyOtp(String phone) async {
    _isPhoneNumberVerificationButtonLoading = true;
    _verificationMsg = '';
    notifyListeners();
    ResponseModel responseModel = await authServiceInterface.verifyOtp(phone, _verificationCode);
    _isPhoneNumberVerificationButtonLoading = false;
    _verificationMsg = responseModel.message;
    notifyListeners();
    return responseModel;
  }


  Future<ResponseModel> resetPassword(String identity, String otp, String password, String confirmPassword, String? token) async {
    _isPhoneNumberVerificationButtonLoading = true;
    _verificationMsg = '';
    notifyListeners();
    ResponseModel responseModel = await authServiceInterface.resetPassword(identity,otp,password,confirmPassword, token);
    _isPhoneNumberVerificationButtonLoading = false;
    _verificationMsg = responseModel.message;
    notifyListeners();
    return responseModel;
  }


  void pickImage(bool isProfile, bool shopLogo, bool isRemove, {bool secondary = false, bool offer = false}) async {
    if(isRemove) {
      _sellerProfileImage = null;
      _shopLogo = null;
      _shopBanner = null;
      secondaryBanner = null;
    } else {
      XFile? image = await ImageValidationHelper.validateAndPickImage(
        source: ImageSource.gallery,
        context: Get.context!
      );


      if (isProfile && image != null) {
        _sellerProfileImage = image;
      } else if(shopLogo && image != null) {
        _shopLogo = image;
      }else if(secondary && image != null) {
        secondaryBanner = image;
      }else if(offer && image != null) {
        offerBanner = image;
      }else if ( image != null) {
        _shopBanner = image;
      }
    }
    notifyListeners();
  }

  Future<ApiResponse> registration(BuildContext context,RegisterModel registerModel, XFile? tinCertificate) async {
    _isLoading = true;
    notifyListeners();
    ApiResponse  response = await authServiceInterface.registration(_sellerProfileImage, _shopLogo, _shopBanner, secondaryBanner, registerModel, tinCertificate);

    if(response.response?.statusCode == 200) {
      _isLoading = false;
      firstNameController.clear();
      lastNameController.clear();
      phoneController.clear();
      emailController.clear();
      passwordController.clear();
      confirmPasswordController.clear();
      shopNameController.clear();
      shopAddressController.clear();
      _sellerProfileImage = null;
      _shopLogo = null;
      _shopBanner = null;
      secondaryBanner = null;
      Provider.of<ShopController>(Get.context!, listen: false).clearShopModel();
      showCustomSnackBarWidget(getTranslated("you_are_successfully_registered", Get.context!), Get.context!, isError: false, sanckBarType: SnackBarType.success);
    } else {
      _isLoading = false;
      // The old code claimed "The email has already been taken" for every
      // failure shape, and threw (leaving the spinner stuck) whenever the body
      // was not the one JSON layout it expected. Parse defensively and report
      // whatever the server actually said.
      final String? serverMessage = _extractRegistrationError(response);
      final BuildContext? context = Get.context;
      if (context != null && context.mounted) {
        showCustomSnackBarWidget(
          serverMessage ?? getTranslated('something_went_wrong', context),
          context,
          sanckBarType: SnackBarType.warning,
        );
      }
    }
    _isLoading = false;
    notifyListeners();
    return response;
  }

  /// Pulls a human-readable validation message out of a registration response
  /// whose body may be a JSON string, a decoded map, or an HTML error page.
  String? _extractRegistrationError(ApiResponse response) {
    dynamic data = response.response?.data;
    try {
      if (data is String) {
        final String trimmed = data.trim();
        if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
        data = jsonDecode(trimmed);
      }
      if (data is Map) {
        final dynamic message = data['message'];
        if (message is List && message.isNotEmpty) {
          final dynamic first = message.first;
          if (first is Map && first['message'] != null) return first['message'].toString();
          return first.toString();
        }
        if (message is String && message.isNotEmpty) return message;
        final dynamic errors = data['errors'];
        if (errors is List && errors.isNotEmpty) {
          final dynamic first = errors.first;
          if (first is Map && first['message'] != null) return first['message'].toString();
        }
      }
    } catch (e) {
      debugPrint('registration error parse failed: $e');
    }
    final Object? fallback = response.error;
    if (fallback is String && fallback.isNotEmpty) return fallback;
    return null;
  }

  void setCountryDialCode (String? setValue){
    _countryDialCode = setValue;
  }


  void emptyRegistrationData ({bool isUpdate = false}) {
    firstNameController.clear();
    lastNameController.clear();
    phoneController.clear();
    emailController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    shopNameController.clear();
    shopAddressController.clear();
    _sellerProfileImage = null;
    _shopLogo = null;
    _shopBanner = null;
    secondaryBanner = null;
    if(isUpdate){
      notifyListeners();
    }
  }

  void validPassCheck(String pass, {bool isUpdate = true}){
    _lengthCheck = false;
    _numberCheck = false;
    _uppercaseCheck = false;
    _lowercaseCheck = false;
    _spatialCheck = false;

    if(pass.length > 7){
      _lengthCheck = true;
    }
    if(pass.contains(RegExp(r'[a-z]'))){
      _lowercaseCheck = true;
    }
    if(pass.contains(RegExp(r'[A-Z]'))){
      _uppercaseCheck = true;
    }
    if(pass.contains(RegExp(r'[ .!@#$&*~^%]'))){
      _spatialCheck = true;
    }
    if(pass.contains(RegExp(r'[\d+]'))){
      _numberCheck = true;
    }
    if(isUpdate) {
      notifyListeners();
    }
  }

  void showHidePass({bool isUpdate = true}) {
    _showPassView = ! _showPassView;
    if(isUpdate) {
      notifyListeners();
    }
  }


  bool isPasswordValid (){
    return (_lengthCheck && _numberCheck && _lowercaseCheck && _uppercaseCheck && _spatialCheck && _numberCheck);
  }


  void setUnAuthorize(bool value, {bool update = false}) {
    _isUnAuthorize = value;
    if(update) {
      notifyListeners();
    }
  }



  Future<void> firebaseVerifyPhoneNumber(String phoneNumber, {bool isForgetPassword = false, bool isResend = false, String? toNavigateScreen, VoidCallback? onLoginSuccess}) async {
    if(!isResend) {
      _isLoading = true;
    }
    _resendButtonLoading = true;
    notifyListeners();

    // String? vID;

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        _isPhoneNumberVerificationButtonLoading = false;
        _isLoading = false;
        notifyListeners();

        // Navigator.of(Get.context!).pop();

        if(e.code == 'invalid-phone-number') {

          showCustomSnackBarWidget(getTranslated('please_submit_a_valid_phone_number', Get.context!), Get.context!);
        }else{
          showCustomSnackBarWidget(getTranslated('${e.message}'.replaceAll('_', ' ').toCapitalized(), Get.context!), Get.context!);
        }

      },
      codeSent: (String vId, int? resendToken) async {
        _isPhoneNumberVerificationButtonLoading = false;
        _resendButtonLoading = false;
        notifyListeners();

        bool callRoute = !isResend;


        await callFirebaseStoretiken(phoneNumber, vId);

        _verificationID = vId;


        if(isResend) {
          showCustomSnackBarWidget(getTranslated('resend_code_successful', Get.context!), Get.context!, isError: false);
        }

        if(callRoute) {
          Navigator.push(Get.context!, MaterialPageRoute(builder: (_) => VerificationScreen(phoneNumber, session: vId)));
          _isLoading = false;
        }
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        _resendButtonLoading = false;
        _isLoading = false;
      },
    );


    //await Future.delayed(Duration(seconds: 10));

    _resendButtonLoading = false;
    notifyListeners();
  }


  Future<void> callFirebaseStoretiken (String phoneNumber, String vID) async {
     await authServiceInterface.firebaseAuthTokenStore(userInput: phoneNumber, token: vID);
  }


  Future<ApiResponse> checkVendorExistPhone(String  phone) async {
    notifyListeners();
    ApiResponse responseModel = await authServiceInterface.checkVendorExistPhone(phoneNumber: phone);


    notifyListeners();
    return responseModel;
  }



  Future<void> firebaseOtpVerification({required String phoneNumber, required String session, required String otp, bool isForgetPassword = false}) async {
    _isPhoneNumberVerificationButtonLoading = true;
    notifyListeners();

    ApiResponse apiResponse = await authServiceInterface.firebaseAuthVerify(
      session: session, phoneNumber: phoneNumber,
      otp: otp, isForgetPassword: isForgetPassword,
    );

    if(apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      Navigator.pushAndRemoveUntil(Get.context!, MaterialPageRoute(
        builder: (_) => ResetPasswordWidget(
          mobileNumber: phoneNumber,
          otp: otp,
          token: session,
        )), (route) => false
      );
    } else {
      // A wrong or expired code answers 401, which ApiChecker reads as an
      // expired session and responds to by wiping one. There is no session to
      // wipe here — the seller is verifying a phone number to reset a password
      // — so the failure is reported as what it is.
      showCustomSnackBarWidget(
        getTranslated('input_valid_otp', Get.context!) ?? '${apiResponse.error ?? ''}',
        Get.context!,
        sanckBarType: SnackBarType.error,
      );
    }

    _isPhoneNumberVerificationButtonLoading = false;
    notifyListeners();
  }







}
