import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/data/datasource/local/seller_session_token.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:syriacosmeticsmanger/features/auth/domain/repositories/auth_repository.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_token_store.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Where the seller's session token lives, and where it must not (K-268).
///
/// SharedPreferences is a plain file a device backup carries away, and a
/// seller's token opens their whole shop. It belongs in the Keystore or the
/// Keychain, a value an older build left in the plain file belongs nowhere, and
/// a sign-out must take it from both.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
  });

  const String token = 'a-real-looking-session-token-value';

  Future<SharedPreferences> preferencesWith(
      [Map<String, Object> values = const <String, Object>{}]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('where the token is kept', () {
    test(
        'a token the server issued goes to the secure store and not to the preferences',
        () async {
      final SharedPreferences preferences = await preferencesWith();
      final SellerSessionToken store =
          SellerSessionToken(preferences: preferences);

      await store.save(token);

      expect(secure[AppConstants.token], token);
      expect(preferences.getKeys(), isEmpty,
          reason:
              'the plain file is where it used to be written and must stay empty');
      expect(store.value, token);
      expect(store.exists, isTrue);
    });

    test(
        'a value an older build left in the plain file is moved into the secure store and erased',
        () async {
      final SharedPreferences preferences =
          await preferencesWith(<String, Object>{AppConstants.token: token});
      final SellerSessionToken store =
          SellerSessionToken(preferences: preferences);

      await store.prime();

      expect(secure[AppConstants.token], token);
      expect(preferences.containsKey(AppConstants.token), isFalse,
          reason: 'migrated means moved, not copied');
      expect(store.value, token,
          reason: 'the seller stays signed in across the migration');
    });

    test(
        'an unprimed store still reads the old place, so no session is lost waiting for a migration',
        () async {
      final SharedPreferences preferences =
          await preferencesWith(<String, Object>{AppConstants.token: token});

      final SellerSessionToken store =
          SellerSessionToken(preferences: preferences);

      expect(store.isPrimed, isFalse);
      expect(store.value, token);
    });

    test('nothing stored anywhere is no session', () async {
      final SellerSessionToken store =
          SellerSessionToken(preferences: await preferencesWith());

      await store.prime();

      expect(store.value, isEmpty);
      expect(store.exists, isFalse);
    });

    test('a blank token is not a session and is not written', () async {
      final SellerSessionToken store =
          SellerSessionToken(preferences: await preferencesWith());

      await store.save('   ');

      expect(secure, isEmpty);
      expect(store.exists, isFalse);
    });

    test('its key is the seller\'s own and is not the platform admin\'s', () {
      expect(
          AppConstants.token, isNot(SecurePlatformAdminTokenStore.sessionKey));
      expect(platformAdminSecureStorage.aOptions.storageNamespace, isNotEmpty,
          reason:
              'the platform keeps its own namespace, so one store cannot read the other\'s');
    });
  });

  group('ending the session', () {
    test(
        'the cache is empty before the clearing returns, and both stores lose the token',
        () async {
      final SharedPreferences preferences =
          await preferencesWith(<String, Object>{AppConstants.token: token});
      final SellerSessionToken store =
          SellerSessionToken(preferences: preferences);
      await store.save(token);

      final Future<void> clearing = store.clear();

      expect(store.value, isEmpty,
          reason:
              'a synchronous reader must not be handed the session that was just abandoned');
      await clearing;
      expect(secure, isEmpty);
      expect(preferences.containsKey(AppConstants.token), isFalse);
    });
  });

  group('what the app reads it through', () {
    Future<DioClient> clientWith(
            SharedPreferences preferences, SellerSessionToken store) async =>
        DioClient(
          AppConstants.baseUrl,
          Dio(),
          loggingInterceptor: LoggingInterceptor(),
          sharedPreferences: preferences,
          sessionToken: store,
        );

    test(
        'the Dio client signs its requests with the token the secure store holds',
        () async {
      final SharedPreferences preferences = await preferencesWith();
      final SellerSessionToken store =
          SellerSessionToken(preferences: preferences);
      await store.save(token);

      final DioClient client = await clientWith(preferences, store);

      expect(client.dio!.options.headers['Authorization'], 'Bearer $token');
    });

    test('and sends no credential at all when the store holds none', () async {
      final SharedPreferences preferences = await preferencesWith();
      final SellerSessionToken store =
          SellerSessionToken(preferences: preferences);
      await store.prime();

      final DioClient client = await clientWith(preferences, store);

      expect(client.dio!.options.headers['Authorization'], 'Bearer ');
      expect(client.token, isNull,
          reason: 'absent is null, as it was before the token moved');
    });

    test(
        'the auth repository keeps, reads and ends the session through the secure store',
        () async {
      final SharedPreferences preferences = await preferencesWith();
      final SellerSessionToken store =
          SellerSessionToken(preferences: preferences);
      final DioClient client = await clientWith(preferences, store);
      final AuthRepository auth = AuthRepository(
          dioClient: client,
          sharedPreferences: preferences,
          sessionToken: store);

      await auth.saveUserToken(token);

      expect(secure[AppConstants.token], token);
      expect(preferences.containsKey(AppConstants.token), isFalse,
          reason: 'the repository must not write a token to the plain file');
      expect(auth.getUserToken(), token);
      expect(auth.isLoggedIn(), isTrue);

      await auth.clearSharedData();

      expect(auth.isLoggedIn(), isFalse);
      expect(auth.getUserToken(), isEmpty);
      expect(secure[AppConstants.token], isNull);
    });
  });
}
