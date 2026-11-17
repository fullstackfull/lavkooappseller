import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_api_client.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_token_store.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/services/platform_admin_service_interface.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/platform_admin_config.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/platform_admin_dependencies.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/scripted_adapter.dart';

/// What the app builds for the platform admin shell, and when.
void main() {
  late GetIt locator;
  late Map<String, String> secure;
  late SharedPreferences preferences;

  setUp(() async {
    locator = GetIt.asNewInstance();
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
    SharedPreferences.setMockInitialValues(<String, Object>{AppConstants.languageCode: 'ar'});
    preferences = await SharedPreferences.getInstance();
    locator.registerLazySingleton<SharedPreferences>(() => preferences);
  });

  bool registered(GetIt locator) => <bool>[
        locator.isRegistered<PlatformAdminTokenStore>(),
        locator.isRegistered<PlatformAdminApiClient>(),
        locator.isRegistered<PlatformAdminRepositoryInterface>(),
        locator.isRegistered<PlatformAdminServiceInterface>(),
        locator.isRegistered<PlatformAdminController>(),
      ].every((bool isRegistered) => isRegistered);

  bool anythingRegistered(GetIt locator) => <bool>[
        locator.isRegistered<PlatformAdminTokenStore>(),
        locator.isRegistered<PlatformAdminApiClient>(),
        locator.isRegistered<PlatformAdminRepositoryInterface>(),
        locator.isRegistered<PlatformAdminServiceInterface>(),
        locator.isRegistered<PlatformAdminController>(),
      ].any((bool isRegistered) => isRegistered);

  group('with the flag off', () {
    test('nothing is registered: no client, no storage, no repository, no service and no controller', () {
      registerPlatformAdminDependencies(locator, enabled: false);

      expect(anythingRegistered(locator), isFalse);
    });

    test('and nothing is read or written anywhere', () {
      registerPlatformAdminDependencies(locator, enabled: false);

      expect(secure, isEmpty);
      expect(preferences.getKeys(), <String>{AppConstants.languageCode});
    });
  });

  group('with the flag on', () {
    setUp(() => registerPlatformAdminDependencies(locator, enabled: true));

    test('registers everything the shell is made of', () {
      expect(registered(locator), isTrue);
    });

    test('builds none of it until it is asked for', () {
      expect(secure, isEmpty);
    });

    test('has one repository for the app, which holds the session, and a new controller each time the shell opens', () {
      expect(
          identical(locator<PlatformAdminRepositoryInterface>(), locator<PlatformAdminRepositoryInterface>()), isTrue);
      expect(identical(locator<PlatformAdminController>(), locator<PlatformAdminController>()), isFalse);
    });

    test(
        'has a client that reaches the host of the seller API, and asks in the language the app is set to at the time it asks',
        () async {
      final PlatformAdminApiClient client = locator<PlatformAdminApiClient>();
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWith('me_owner');
      client.dio.httpClientAdapter = adapter;

      await client.get('/me', bearerToken: 'a-token');
      await preferences.setString(AppConstants.languageCode, 'en');
      await client.get('/me', bearerToken: 'a-token');

      expect(adapter.requests.first.uri.host, Uri.parse(AppConstants.baseUrl).host);
      expect(
          adapter.requests.map((RecordedRequest request) => request.header('Accept-Language')), <String>['ar', 'en']);
    });

    test('falls back to English when the app has no language stored', () async {
      await preferences.remove(AppConstants.languageCode);
      final PlatformAdminApiClient client = locator<PlatformAdminApiClient>();
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWith('me_owner');
      client.dio.httpClientAdapter = adapter;

      await client.get('/me', bearerToken: 'a-token');

      expect(adapter.requests.single.header('Accept-Language'), 'en');
    });
  });

  group('with the flag the build was made with', () {
    test('registers exactly when the build says so', () {
      registerPlatformAdminDependencies(locator);

      expect(registered(locator), PlatformAdminConfig.enabled);
      expect(anythingRegistered(locator), PlatformAdminConfig.enabled);
    });
  });
}
