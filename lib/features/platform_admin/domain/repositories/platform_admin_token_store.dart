import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';

/// What the app keeps of a platform session between launches: the token, and
/// when it ends. Not the e-mail, not the password, not who signed in.
class StoredPlatformSession {
  final String token;
  final DateTime? expiresAt;

  const StoredPlatformSession({required this.token, this.expiresAt});
}

abstract class PlatformAdminTokenStore {
  Future<StoredPlatformSession?> read();

  Future<void> write(StoredPlatformSession session);

  Future<void> clear();
}

/// The platform admin's own corner of the Keystore and the Keychain.
///
/// The seller keeps a saved password in the default store of the same plugin.
/// Nothing here shares that: the Android storage and its Keystore aliases live
/// under their own namespace, the Keychain service has its own name, and the
/// token stays on this phone and is readable only while it is unlocked. So a
/// reset of one store, or a call that clears one, cannot reach the other.
const FlutterSecureStorage platformAdminSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(storageNamespace: 'lavkoo_platform_admin'),
  iOptions: IOSOptions(accountName: 'lavkoo.platform_admin', accessibility: KeychainAccessibility.unlocked_this_device),
  mOptions:
      MacOsOptions(accountName: 'lavkoo.platform_admin', accessibility: KeychainAccessibility.unlocked_this_device),
);

/// Keeps the platform session in [platformAdminSecureStorage], under one key of
/// its own, and never in the preferences, which are a plain file.
///
/// A Keystore that fails is not allowed to stop a sign-in or a sign-out. What
/// cannot be read is no session, so the admin signs in again; what cannot be
/// written is simply not remembered; what cannot be deleted was also revoked on
/// the server by the sign-out that asked for it.
class SecurePlatformAdminTokenStore implements PlatformAdminTokenStore {
  static const String sessionKey = 'platform_admin.session.v1';

  final FlutterSecureStorage _storage;

  SecurePlatformAdminTokenStore({FlutterSecureStorage? storage}) : _storage = storage ?? platformAdminSecureStorage;

  @override
  Future<StoredPlatformSession?> read() async {
    final String? stored = await _guarded(() => _storage.read(key: sessionKey));
    if (stored == null) return null;

    final StoredPlatformSession? session = _decode(stored);
    if (session == null) await clear();
    return session;
  }

  @override
  Future<void> write(StoredPlatformSession session) => _guarded(
        () => _storage.write(
          key: sessionKey,
          value: jsonEncode(<String, Object?>{
            'token': session.token,
            'expires_at': session.expiresAt?.toUtc().toIso8601String(),
          }),
        ),
      );

  @override
  Future<void> clear() => _guarded(() => _storage.delete(key: sessionKey));

  Future<T?> _guarded<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } on PlatformException {
      return null;
    }
  }

  StoredPlatformSession? _decode(String stored) {
    try {
      final Map<String, dynamic> body = PlatformJson.map(jsonDecode(stored));
      final String? token = PlatformJson.string(body['token']);
      return token == null || token.isEmpty
          ? null
          : StoredPlatformSession(token: token, expiresAt: PlatformJson.moment(body['expires_at']));
    } on FormatException {
      return null;
    }
  }
}
