import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/local/secure_credential_store.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/repositories/auth_repository.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_api_client.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_repository.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_token_store.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/fixtures.dart';
import 'support/scripted_adapter.dart';

const String _sellerToken = 'SELLER-SESSION-TOKEN-THAT-MUST-OUTLIVE-A-PLATFORM-SIGN-OUT-0123456789';
const String _sellerPassword = 'the-sellers-saved-password';

/// A seller and a platform admin are two principals on one phone. Neither's
/// sign-in may start the other's session, neither's sign-out may end it, and
/// the admin's credentials may never go through the seller's login.
///
/// The seller side here is the real one: the real repository, its real
/// sign-out, its real saved password in the same Keystore the platform uses.
void main() {
  late Map<String, String> secure;
  late SharedPreferences preferences;
  late DioClient sellerClient;
  late ScriptedAdapter sellerAdapter;
  late AuthRepository sellerAuth;
  late ScriptedAdapter platformAdapter;
  late PlatformAdminRepository platform;
  late SecurePlatformAdminTokenStore platformStore;

  setUp(() async {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.token: _sellerToken,
      AppConstants.userEmail: 'seller@example.test',
      AppConstants.languageCode: 'en',
    });
    preferences = await SharedPreferences.getInstance();

    sellerAdapter = ScriptedAdapter.replyingWith('error_api_switched_off');
    sellerClient = DioClient(AppConstants.baseUrl, Dio(),
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: preferences);
    sellerClient.dio!.httpClientAdapter = sellerAdapter;
    final SecureCredentialStore sellerCredentials = SecureCredentialStore(sharedPreferences: preferences);
    await sellerCredentials.savePassword(_sellerPassword);
    sellerAuth =
        AuthRepository(dioClient: sellerClient, sharedPreferences: preferences, credentialStore: sellerCredentials);

    platformAdapter = ScriptedAdapter.routing(const <String, String>{
      'POST /auth/login': 'login_success',
      'POST /auth/logout': 'logout',
      'GET /me': 'me_owner',
      'GET /markets': 'markets_owner',
    });
    final PlatformAdminApiClient client =
        PlatformAdminApiClient(baseUrl: AppConstants.baseUrl, languageCode: () => 'en');
    client.dio.httpClientAdapter = platformAdapter;
    platformStore = SecurePlatformAdminTokenStore();
    platform = PlatformAdminRepository(apiClient: client, tokenStore: platformStore);
  });

  Future<void> platformSignsIn() async {
    await platform.signIn(email: 'owner@example.test', password: 'the-admins-own-password', deviceName: 'Pixel 9');
    platformAdapter.requests.clear();
  }

  bool sellerSessionIntact() =>
      preferences.getString(AppConstants.token) == _sellerToken &&
      secure[AppConstants.userPassword] == _sellerPassword &&
      sellerClient.token == _sellerToken &&
      sellerClient.dio!.options.headers['Authorization'] == 'Bearer $_sellerToken';

  group('signing in as a platform admin', () {
    test('goes to the platform API and never to the seller login', () async {
      await platform.signIn(email: 'owner@example.test', password: 'the-admins-own-password', deviceName: 'Pixel 9');

      expect(platformAdapter.requests.single.uri.path, '/api/platform-admin/v1/auth/login');
      expect(platformAdapter.requests.single.uri.path, isNot(AppConstants.loginUri));
      expect(sellerAdapter.requests, isEmpty, reason: 'the seller client was never asked anything');
    });

    test('starts no seller session and changes nothing of the one a seller has', () async {
      await platform.signIn(email: 'owner@example.test', password: 'the-admins-own-password', deviceName: 'Pixel 9');

      expect(sellerSessionIntact(), isTrue);
      expect(preferences.getKeys(), <String>{AppConstants.token, AppConstants.userEmail, AppConstants.languageCode});
      expect(secure.keys.toSet(), <String>{AppConstants.userPassword, SecurePlatformAdminTokenStore.sessionKey});
    });

    test('the platform token is never the seller token, and the seller token never rides a platform request', () async {
      await platformSignsIn();
      await platform.markets();

      expect(platformAdapter.requests.single.header('Authorization'), 'Bearer $fixtureToken');
      expect(platformAdapter.requests.single.everything, isNot(contains(_sellerToken)));
      expect((await platformStore.read())!.token, isNot(_sellerToken));
    });
  });

  group('signing out as a seller', () {
    test('ends the seller session, with the real sign-out of the seller app', () async {
      await platformSignsIn();

      await sellerAuth.clearSharedData();

      expect(preferences.containsKey(AppConstants.token), isFalse);
      expect(secure.containsKey(AppConstants.userPassword), isFalse);
      expect(sellerClient.token, isNull);
    });

    test('leaves the platform session in place, on this phone and in this process', () async {
      await platformSignsIn();

      await sellerAuth.clearSharedData();

      expect((await platformStore.read())!.token, fixtureToken);
      expect((await platform.markets()).isSuccess, isTrue);
      expect(platformAdapter.requests.single.header('Authorization'), 'Bearer $fixtureToken');
    });

    test('and a later launch still finds the platform session', () async {
      await platformSignsIn();
      await sellerAuth.clearSharedData();

      final PlatformAdminApiClient client =
          PlatformAdminApiClient(baseUrl: AppConstants.baseUrl, languageCode: () => 'en');
      client.dio.httpClientAdapter = platformAdapter;
      final PlatformAdminRepository nextLaunch =
          PlatformAdminRepository(apiClient: client, tokenStore: SecurePlatformAdminTokenStore());

      expect((await nextLaunch.restore()).value!.adminId, 4);
    });

    test('clearing the seller\'s saved credentials is not able to take the platform token with it', () async {
      await platformSignsIn();

      await SecureCredentialStore(sharedPreferences: preferences).clearPassword();
      await sellerAuth.clearUserNumberAndPassword();

      expect(secure.containsKey(SecurePlatformAdminTokenStore.sessionKey), isTrue);
    });
  });

  group('signing out as a platform admin', () {
    test('ends the platform session, here and on the server', () async {
      await platformSignsIn();

      await platform.signOut();

      expect(await platformStore.read(), isNull);
      expect(platformAdapter.requests.single.uri.path, '/api/platform-admin/v1/auth/logout');
    });

    test('leaves the seller session as it was: the token, the saved password and the client', () async {
      await platformSignsIn();

      await platform.signOut();

      expect(sellerSessionIntact(), isTrue);
      expect(preferences.getString(AppConstants.userEmail), 'seller@example.test');
      expect(sellerAdapter.requests, isEmpty);
    });

    test('and so does the refusal of a platform token that has run out', () async {
      final ScriptedAdapter refusing = ScriptedAdapter.routing(
          const <String, String>{'GET /me': 'error_unauthenticated', 'POST /auth/login': 'login_success'});
      final PlatformAdminApiClient client =
          PlatformAdminApiClient(baseUrl: AppConstants.baseUrl, languageCode: () => 'en');
      client.dio.httpClientAdapter = refusing;
      final PlatformAdminRepository expired = PlatformAdminRepository(apiClient: client, tokenStore: platformStore);
      await expired.signIn(email: 'owner@example.test', password: 'the-admins-own-password', deviceName: 'Pixel 9');

      await expired.profile();

      expect(await platformStore.read(), isNull);
      expect(sellerSessionIntact(), isTrue);
    });
  });

  group('the seller login', () {
    test('is only ever given what the seller typed: the platform sign-in has no way to reach it', () async {
      await platform.signIn(
          email: 'admin-not-a-seller@example.test', password: 'the-admins-own-password', deviceName: 'Pixel 9');

      expect(sellerAdapter.requests, isEmpty);
      expect(
          sellerAdapter.requests.where((RecordedRequest request) => request.everything.contains('admin-not-a-seller')),
          isEmpty);
      expect(preferences.getString(AppConstants.userEmail), 'seller@example.test',
          reason: 'not even the saved e-mail of the seller login was touched');
    });
  });
}
