import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Where the seller's session token lives: the platform secure store, and not
/// plaintext SharedPreferences (K-268).
///
/// SharedPreferences is an unencrypted XML file in the app's data directory, so
/// a token written there survives device backups and is readable on a rooted or
/// cloned device — and a seller's token opens their whole shop: orders,
/// customers, payouts. It now lives in the Android Keystore / iOS Keychain,
/// beside the saved password that moved there before it
/// ([SecureCredentialStore]), and a value left by an older build is migrated
/// and then erased.
///
/// **Why there is a cached copy.** Every caller of the token reads it
/// synchronously — the Dio client builds its Authorization header in its
/// constructor, and `isLoggedIn()` is asked while a frame is being built — and
/// the secure store is async only. So the value is read once, at launch, and
/// held in memory for the life of the process, exactly as the saved password
/// is.
///
/// **Why an unprimed store still reads the old place.** Until [prime] has run,
/// and in a build or a test that never wires it, the legacy key is still
/// consulted. A session is never lost because a migration had not got round to
/// it yet; once primed, the secure store is the only source and the legacy key
/// is gone.
///
/// **Why a failed write keeps the legacy value.** If the keystore cannot be
/// written to, the old plaintext value is left where it is rather than deleted.
/// A seller is never locked out by a device whose secure storage is
/// unavailable, and on a device where it works nothing is left behind.
class SellerSessionToken {
  SellerSessionToken({required SharedPreferences? preferences, FlutterSecureStorage? storage})
      : _preferences = preferences,
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final SharedPreferences? _preferences;
  final FlutterSecureStorage _storage;

  String _cached = '';
  bool _primed = false;

  bool get isPrimed => _primed;

  /// The token to sign a request with, or empty when there is no session.
  String get value => _primed ? _cached : (_preferences?.getString(AppConstants.token) ?? '');

  bool get exists => value.isNotEmpty;

  /// Reads the token into the cache and migrates any value an older build left
  /// in plaintext. Safe to call repeatedly; call it before anything reads the
  /// token, which on this app means inside the dependency setup.
  Future<void> prime() async {
    final String legacy = _preferences?.getString(AppConstants.token) ?? '';

    try {
      if (legacy.isNotEmpty) {
        await _storage.write(key: AppConstants.token, value: legacy);
        await _preferences?.remove(AppConstants.token);
        _cached = legacy;
      } else {
        _cached = await _storage.read(key: AppConstants.token) ?? '';
      }
      _primed = true;
    } catch (e) {
      debugPrint('SellerSessionToken: prime failed --- $e');
      // Not primed: the reads above keep consulting the legacy key, so a device
      // whose secure storage is unavailable keeps the session it already had.
      _cached = '';
    }
  }

  /// Keeps a token the server has just issued. The legacy key is removed as
  /// well, so a session never lands back in plaintext.
  Future<void> save(String token) async {
    if (token.trim().isEmpty) {
      return;
    }

    try {
      await _storage.write(key: AppConstants.token, value: token);
      _cached = token;
      _primed = true;
      await _preferences?.remove(AppConstants.token);
    } catch (e) {
      debugPrint('SellerSessionToken: write failed --- $e');
      // The session must survive a device that cannot be written to securely,
      // so it is kept where this app has always kept it and the cache is not
      // claimed to be authoritative.
      await _preferences?.setString(AppConstants.token, token);
    }
  }

  /// Ends the session. The cache is emptied BEFORE the first `await`, so by the
  /// time this returns to its caller — none of which await it — no synchronous
  /// reader can still be handed the token that was just abandoned.
  Future<void> clear() async {
    _cached = '';
    _primed = true;

    try {
      await _storage.delete(key: AppConstants.token);
    } catch (e) {
      debugPrint('SellerSessionToken: delete failed --- $e');
    }

    await _preferences?.remove(AppConstants.token);
  }
}
