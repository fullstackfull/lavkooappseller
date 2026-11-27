import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/data/datasource/local/secure_credential_store.dart';
import 'package:syriacosmeticsmanger/data/datasource/local/seller_session_token.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/exception/api_error_handler.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/models/register_model.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/repositories/auth_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/storefront/seller_market_choice.dart';
import 'package:syriacosmeticsmanger/notification/seller_push_topics.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

class AuthRepository implements AuthRepositoryInterface {
  final DioClient? dioClient;
  final SharedPreferences? sharedPreferences;
  late final SecureCredentialStore secureCredentialStore;

  /// Where the session token is kept: the platform secure store (K-268). The
  /// dependency setup hands over the one instance it primed, so this repository,
  /// the Dio client and the bank screen read one cache. A repository built
  /// without one makes its own, which reads the legacy plaintext key until
  /// something primes it, so a test or a build that has not been wired behaves
  /// as it did before this store existed.
  late final SellerSessionToken sessionToken;

  /// The market this device is working in, for the topics it subscribes to (K-11). Null in a build or a test that has not wired it, which
  /// subscribes to the platform-wide topics alone -- exactly what this app did before markets existed.
  SellerMarketChoice? get _marketChoice =>
      sharedPreferences == null ? null : SellerMarketChoice(sharedPreferences!);

  AuthRepository(
      {required this.dioClient,
      required this.sharedPreferences,
      SecureCredentialStore? credentialStore,
      SellerSessionToken? sessionToken}) {
    secureCredentialStore = credentialStore ??
        SecureCredentialStore(sharedPreferences: sharedPreferences);
    this.sessionToken =
        sessionToken ?? SellerSessionToken(preferences: sharedPreferences);
  }

  @override
  Future<ApiResponse> login({String? emailAddress, String? password}) async {
    try {
      Response response = await dioClient!.post(
        AppConstants.loginUri,
        data: {"email": emailAddress, "password": password},
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> setLanguageCode(String languageCode) async {
    try {
      final response = await dioClient!.post(AppConstants.setCurrentLanguageUri,
          data: {'current_language': languageCode, '_method': 'put'});
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> forgotPassword(String identity) async {
    try {
      Response response = await dioClient!
          .post(AppConstants.forgotPasswordUri, data: {"identity": identity});
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> resetPassword(String identity, String otp,
      String password, String confirmPassword, String? token) async {
    try {
      Response response =
          await dioClient!.post(AppConstants.resetPasswordUri, data: {
        "_method": "put",
        "identity": identity.trim(),
        "otp": token ?? otp,
        "password": password,
        "confirm_password": confirmPassword
      });
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> verifyOtp(String identity, String otp) async {
    try {
      Response response = await dioClient!.post(AppConstants.verifyOtpUri,
          data: {"identity": identity.trim(), "otp": otp});
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> updateToken() async {
    try {
      String? deviceToken = await _getDeviceToken();
      // The platform-wide topics AND the one of the market this device is working in (K-11): a maintenance of one market must not tell the
      // sellers of the others to stop working. With storefronts off the list is the two topics this app has always subscribed to.
      for (final String topic
          in SellerPushTopics.forMarket(_marketChoice?.current())) {
        FirebaseMessaging.instance.subscribeToTopic(topic);
      }
      Response response = await dioClient!.post(
        AppConstants.tokenUri,
        data: {"_method": "put", "cm_firebase_token": deviceToken},
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<String?> _getDeviceToken() async {
    String? deviceToken;
    deviceToken = await FirebaseMessaging.instance.getToken();

    if (deviceToken != null) {
      if (kDebugMode) {
        print('--------Device Token---------- $deviceToken');
      }
    }
    return deviceToken;
  }

  @override
  Future<void> saveUserToken(String token) async {
    dioClient!.updateAuthToken(token);

    await sessionToken.save(token);
  }

  @override
  String getUserToken() {
    return sessionToken.value;
  }

  /// Whether there is a session, which is whether a token is HELD and not
  /// whether a key exists: the token moved to the secure store, where the
  /// question "is this key present" is an asynchronous one and this is asked
  /// while a frame is being built.
  @override
  bool isLoggedIn() {
    return sessionToken.exists;
  }

  /// What the device holds for whoever is signed in, and for nobody else: the market the seller works in, the till they are ringing up
  /// and the currency they chose. A sign-out takes all three, so that the next seller to sign in on the same device starts in no
  /// market, with an empty till and the currency of the shop rather than carrying on where the seller before them left off.
  ///
  /// The sales that could not be sent are deliberately not here. They are money already taken, each one owed to the seller who rang it
  /// up, so they stay on the device under their own key and are listed and sent only in that seller's session.
  static const List<String> _keysOfTheSignedInSeller = <String>[
    AppConstants.storefrontCountry,
    AppConstants.cartList,
    AppConstants.currency,
  ];

  @override
  Future<ApiResponse> endServerSession(String token) async {
    try {
      // The token is passed in and set on this one request rather than read
      // from the client, because the client's credential is already gone:
      // `clearSharedData` drops it first thing, and that order is deliberate
      // -- see the note there.
      final Response response = await dioClient!.post(
        AppConstants.logoutUri,
        data: const <String, dynamic>{},
        options: Options(
          headers: <String, dynamic>{'Authorization': 'Bearer $token'},
        ),
      );

      return ApiResponse.withSuccess(response);
    } catch (e) {
      // A sign-out that cannot reach the server is still a sign-out. The phone
      // has already forgotten the session; a server that is unreachable, or
      // old enough not to know this route, must not leave the seller on a
      // screen they have signed out of. The token then expires on its own,
      // which is what happened to every sign-out before this call existed.
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<bool> clearSharedData() async {
    // Everything destructive happens first, before anything can suspend.
    //
    // This used to sit behind two Firebase round-trips while its callers — none
    // of which await it — navigated straight to the login screen. With the
    // credentials prefilled, a seller could be signed back in before those
    // round-trips returned, and the tail of the old sign-out then erased the
    // brand-new session: the header became `Bearer ` and the stored token went
    // with it, so every request that followed came back 401 and bounced them to
    // the login screen again. A dashboard load fires about twenty requests at
    // once, so one expired token started twenty of these at a time.
    dioClient!.clearAuthToken();
    // Empties the token cache before its first `await`, so a synchronous reader
    // cannot still be handed the session that was just abandoned; the stores it
    // then clears are the secure one and, belt and braces, the legacy key.
    final Future<void> sessionEnded = sessionToken.clear();
    final Future<bool> tokenRemoved =
        sharedPreferences!.remove(AppConstants.token);
    final Future<List<bool>> sellerDataRemoved = Future.wait<bool>(
      _keysOfTheSignedInSeller.map(sharedPreferences!.remove).toList(),
    );
    final bool removed = await tokenRemoved;
    await sellerDataRemoved;
    await sessionEnded;
    await secureCredentialStore.clearPassword();

    // Best effort, and last: unsubscribing is a courtesy to the push service,
    // not part of ending the session. It must never be able to outlive the
    // sign-out it belongs to.
    try {
      for (final String topic
          in SellerPushTopics.forMarket(_marketChoice?.current())) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      }
    } catch (e) {
      if (kDebugMode) {
        print("====Execption====>>$e");
      }
    }

    return removed;
  }

  @override
  Future<void> saveUserCredentials(String number, String password) async {
    try {
      await secureCredentialStore.savePassword(password);
      await sharedPreferences!.setString(AppConstants.userEmail, number);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> primeCredentialCache() async {
    await secureCredentialStore.prime();
    await sessionToken.prime();
  }

  @override
  String getUserEmail() {
    return sharedPreferences!.getString(AppConstants.userEmail) ?? "";
  }

  @override
  String getUserPassword() {
    return secureCredentialStore.cachedPassword;
  }

  @override
  Future<bool> clearUserNumberAndPassword() async {
    await secureCredentialStore.clearPassword();
    return await sharedPreferences!.remove(AppConstants.userEmail);
  }

  @override
  Future<ApiResponse> registration(
      XFile? profileImage,
      XFile? shopLogo,
      XFile? shopBanner,
      XFile? secondaryBanner,
      RegisterModel registerModel,
      XFile? tinCertificate) async {
    http.MultipartRequest request = http.MultipartRequest('POST',
        Uri.parse('${AppConstants.baseUrl}${AppConstants.registration}'));
    request.headers.addAll(dioClient!.multipartHeaders());
    if (profileImage != null) {
      Uint8List list = await profileImage.readAsBytes();
      var part = http.MultipartFile(
          'image', profileImage.readAsBytes().asStream(), list.length,
          filename: basename(profileImage.path));
      request.files.add(part);
    }
    if (shopLogo != null) {
      Uint8List list = await shopLogo.readAsBytes();
      var part = http.MultipartFile(
          'logo', shopLogo.readAsBytes().asStream(), list.length,
          filename: basename(shopLogo.path));
      request.files.add(part);
    }
    if (shopBanner != null) {
      Uint8List list = await shopBanner.readAsBytes();
      var part = http.MultipartFile(
          'banner', shopBanner.readAsBytes().asStream(), list.length,
          filename: basename(shopBanner.path));
      request.files.add(part);
    }
    if (secondaryBanner != null) {
      Uint8List list = await secondaryBanner.readAsBytes();
      var part = http.MultipartFile('bottom_banner',
          secondaryBanner.readAsBytes().asStream(), list.length,
          filename: basename(secondaryBanner.path));
      request.files.add(part);
    }
    if (tinCertificate != null) {
      Uint8List list = await tinCertificate.readAsBytes();
      var part = http.MultipartFile('tin_certificate',
          tinCertificate.readAsBytes().asStream(), list.length,
          filename: basename(tinCertificate.path));
      request.files.add(part);
    }

    Map<String, String> fields = {};
    fields.addAll(<String, String>{
      'f_name': registerModel.fName!,
      'l_name': registerModel.lName!,
      'phone': registerModel.phone!,
      'email': registerModel.email!,
      'password': registerModel.password!,
      'confirm_password': registerModel.confirmPassword!,
      'shop_name': registerModel.shopName!,
      'shop_address': registerModel.shopAddress!,
      'tax_identification_number': registerModel.businessTin!,
      'tin_expire_date': registerModel.tinExpireDate ?? ''
    });

    request.fields.addAll(fields);
    if (kDebugMode) {
      print('=====> ${request.url.path}\n${request.fields}');
    }

    http.StreamedResponse response = await request.send();
    var res = await http.Response.fromStream(response);
    if (kDebugMode) {
      print('=====Response body is here==>${res.body}');
    }

    try {
      return ApiResponse.withSuccess(Response(
          statusCode: response.statusCode,
          requestOptions: RequestOptions(path: ''),
          statusMessage: response.reasonPhrase,
          data: res.body));
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> firebaseAuthTokenStore(
      String userInput, String token) async {
    try {
      Response response = await dioClient!.post(
          AppConstants.firebaseAuthTokenStore,
          data: {"identity": userInput, "token": token});
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> firebaseAuthVerify(
      {required String phoneNumber,
      required String session,
      required String otp,
      required bool isForgetPassword}) async {
    try {
      Response response = await dioClient!.post(
        AppConstants.firebaseAuthVerify,
        data: {'sessionInfo': session, 'phoneNumber': phoneNumber, 'code': otp},
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future<ApiResponse> checkVendorExistPhone(
      {required String phoneNumber}) async {
    try {
      Response response = await dioClient!.post(
        AppConstants.checkVendorExistInfoPhone,
        data: {
          'phone': phoneNumber,
        },
      );
      return ApiResponse.withSuccess(response);
    } catch (e) {
      return ApiResponse.withError(ApiErrorHandler.getMessage(e));
    }
  }

  @override
  Future add(value) {
    // TODO: implement add
    throw UnimplementedError();
  }

  @override
  Future delete(int id) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future get(String id) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset = 1}) {
    // TODO: implement getList
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int id) {
    // TODO: implement update
    throw UnimplementedError();
  }
}
