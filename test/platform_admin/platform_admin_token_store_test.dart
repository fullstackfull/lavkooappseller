import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_token_store.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/fixtures.dart';

/// Where the platform session lives between launches, and where it must not.
///
/// The token of a platform admin is the keys to every market. It belongs in the
/// Keystore or the Keychain, under names that cannot be mistaken for the
/// seller's, and nowhere a backup, a screenshot of preferences or the seller's
/// own sign-out could reach it.
void main() {
  late Map<String, String> secure;

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  final DateTime expiry = DateTime.utc(2026, 11, 17, 14);

  group('what is kept', () {
    test('the token and when it ends, together under one key of its own', () async {
      final SecurePlatformAdminTokenStore store = SecurePlatformAdminTokenStore();

      await store.write(StoredPlatformSession(token: fixtureToken, expiresAt: expiry));

      expect(secure.keys, <String>[SecurePlatformAdminTokenStore.sessionKey]);
      expect(jsonDecode(secure.values.single),
          <String, Object?>{'token': fixtureToken, 'expires_at': '2026-11-17T14:00:00.000Z'});
    });

    test('and is read back as it was written', () async {
      final SecurePlatformAdminTokenStore store = SecurePlatformAdminTokenStore();
      await store.write(StoredPlatformSession(token: fixtureToken, expiresAt: expiry));

      final StoredPlatformSession? session = await SecurePlatformAdminTokenStore().read();

      expect(session!.token, fixtureToken);
      expect(session.expiresAt, expiry);
    });

    test('a token that never expires is kept without an expiry', () async {
      final SecurePlatformAdminTokenStore store = SecurePlatformAdminTokenStore();
      await store.write(const StoredPlatformSession(token: fixtureToken));

      final StoredPlatformSession? session = await store.read();

      expect(session!.token, fixtureToken);
      expect(session.expiresAt, isNull);
    });

    test('nothing stored reads as nothing', () async {
      expect(await SecurePlatformAdminTokenStore().read(), isNull);
    });

    test('a second sign-in replaces the first and does not add to it', () async {
      final SecurePlatformAdminTokenStore store = SecurePlatformAdminTokenStore();
      await store.write(const StoredPlatformSession(token: 'first-token-0123456789'));
      await store.write(const StoredPlatformSession(token: 'second-token-0123456789'));

      expect((await store.read())!.token, 'second-token-0123456789');
      expect(secure, hasLength(1));
    });

    test('a value that is not a stored session is no session, and is thrown away', () async {
      for (final String garbage in <String>['not json', '[]', '{}', '{"token": ""}', '{"token": 7}', '"text"']) {
        secure[SecurePlatformAdminTokenStore.sessionKey] = garbage;

        expect(await SecurePlatformAdminTokenStore().read(), isNull, reason: garbage);
        expect(secure, isEmpty, reason: '$garbage must not be left behind to fail again');
      }
    });
  });

  group('where it is kept', () {
    test('its key is not one of the seller\'s, in either store', () {
      const Set<String> sellerKeys = <String>{
        AppConstants.token,
        AppConstants.userPassword,
        AppConstants.userEmail,
        AppConstants.userNumber,
        AppConstants.languageCode,
      };

      expect(sellerKeys, isNot(contains(SecurePlatformAdminTokenStore.sessionKey)));
      expect(SecurePlatformAdminTokenStore.sessionKey, startsWith('platform_admin.'));
    });

    test('never in the preferences, which are a plain file a backup carries away', () async {
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      final SecurePlatformAdminTokenStore store = SecurePlatformAdminTokenStore();

      await store.write(StoredPlatformSession(token: fixtureToken, expiresAt: expiry));
      await store.read();
      await store.clear();

      expect(preferences.getKeys(), isEmpty);
    });

    test(
        'in a store of its own, where the platform keeps the Keystore aliases and the Keychain service apart from the seller\'s',
        () {
      expect(platformAdminSecureStorage.aOptions.storageNamespace, isNotEmpty);
      expect(platformAdminSecureStorage.iOptions.accountName, isNot(AppleOptions.defaultAccountName));
      expect(platformAdminSecureStorage.mOptions.accountName, isNot(AppleOptions.defaultAccountName));
      expect(platformAdminSecureStorage.iOptions.accessibility, KeychainAccessibility.unlocked_this_device,
          reason:
              'it is used with the app open and the phone unlocked, and must not move to another phone with a backup');
    });
  });

  group('taking it away', () {
    test('clearing removes the platform session and only that', () async {
      secure[AppConstants.userPassword] = 'the-sellers-saved-password';
      secure['some.other.feature'] = 'its value';
      final SecurePlatformAdminTokenStore store = SecurePlatformAdminTokenStore();
      await store.write(StoredPlatformSession(token: fixtureToken, expiresAt: expiry));

      await store.clear();

      expect(await store.read(), isNull);
      expect(secure,
          <String, String>{AppConstants.userPassword: 'the-sellers-saved-password', 'some.other.feature': 'its value'});
    });

    test('clearing what is not there is harmless', () async {
      await SecurePlatformAdminTokenStore().clear();

      expect(secure, isEmpty);
    });
  });

  group('a Keystore that fails', () {
    test('reads as no session, because a session that cannot be read is a session to sign in again', () async {
      final SecurePlatformAdminTokenStore store = SecurePlatformAdminTokenStore(storage: const _BrokenStorage());

      expect(await store.read(), isNull);
    });

    test('is not allowed to stop a sign-in: the session is simply not remembered', () async {
      final SecurePlatformAdminTokenStore store = SecurePlatformAdminTokenStore(storage: const _BrokenStorage());

      await store.write(StoredPlatformSession(token: fixtureToken, expiresAt: expiry));
    });

    test('nor a sign-out', () async {
      final SecurePlatformAdminTokenStore store = SecurePlatformAdminTokenStore(storage: const _BrokenStorage());

      await store.clear();
    });
  });
}

/// Storage whose Keystore or Keychain has stopped answering, which happens
/// after a device restore and on some handsets after a lock screen change.
class _BrokenStorage extends FlutterSecureStorage {
  const _BrokenStorage();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      throw PlatformException(code: 'keystore', message: 'unavailable');

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      throw PlatformException(code: 'keystore', message: 'unavailable');

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      throw PlatformException(code: 'keystore', message: 'unavailable');
}
