import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Keeps the seller's saved password out of plaintext SharedPreferences.
///
/// SharedPreferences is an unencrypted XML file in the app's data directory, so
/// anything written there survives device backups and is readable on a rooted
/// or cloned device. Credentials now live in the Android Keystore / iOS
/// Keychain instead, and any value written by an older build is migrated then
/// erased on first launch.
class SecureCredentialStore {
  final FlutterSecureStorage _storage;
  final SharedPreferences? sharedPreferences;

  SecureCredentialStore({required this.sharedPreferences, FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  /// Cached so the login screen can prefill synchronously; the secure store
  /// itself is async-only.
  String _cachedPassword = '';
  String get cachedPassword => _cachedPassword;

  bool _primed = false;
  bool get isPrimed => _primed;

  /// Reads the stored password into the cache and migrates any legacy value.
  /// Safe to call repeatedly.
  Future<void> prime() async {
    try {
      final String? legacy = sharedPreferences?.getString(AppConstants.userPassword);
      if (legacy != null && legacy.isNotEmpty) {
        await _storage.write(key: AppConstants.userPassword, value: legacy);
        await sharedPreferences?.remove(AppConstants.userPassword);
        _cachedPassword = legacy;
      } else {
        _cachedPassword = await _storage.read(key: AppConstants.userPassword) ?? '';
      }
    } catch (e) {
      debugPrint('SecureCredentialStore: prime failed --- $e');
      _cachedPassword = '';
    }
    _primed = true;
  }

  Future<void> savePassword(String password) async {
    _cachedPassword = password;
    try {
      await _storage.write(key: AppConstants.userPassword, value: password);
    } catch (e) {
      debugPrint('SecureCredentialStore: write failed --- $e');
    }
  }

  Future<void> clearPassword() async {
    _cachedPassword = '';
    try {
      await _storage.delete(key: AppConstants.userPassword);
    } catch (e) {
      debugPrint('SecureCredentialStore: delete failed --- $e');
    }
    // Belt and braces: wipe the legacy plaintext key too.
    await sharedPreferences?.remove(AppConstants.userPassword);
  }
}
