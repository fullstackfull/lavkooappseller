import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/helper/version_helper.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Tells the server the one thing it cannot observe: that the app kept running.
///
/// A crash produces no request. It is the absence of traffic, and no server-side
/// monitor can tell that apart from a quiet evening — so the console's Android
/// and iOS sections could describe how much the app talked and how fast it was
/// answered, and never whether it stayed alive in the seller's hand. The backend
/// endpoint for this, its rate limit and its documentation all shipped; nothing
/// in the app had ever called it, so both sections reported crash-free sessions
/// as "not configured" on every installation.
///
/// Counters are banked locally and flushed on the NEXT launch, never at the
/// moment they happen. An app that is in the middle of crashing is in no state to
/// complete an HTTP round trip, and a reporter that only manages to send from a
/// healthy process reports only healthy processes — which is exactly the bias
/// that makes a crash-free figure worthless.
///
/// Nothing identifying is sent. Three counters, the platform and the version:
/// no stack trace, no device id, no seller. Crash detail belongs to Crashlytics,
/// which the app already reports to; this is the denominator that turns a count
/// of crashes into a rate.
class AppHealthReporter {
  AppHealthReporter._();

  static const String _sessionsKey = 'app_health_pending_sessions';
  static const String _crashesKey = 'app_health_pending_crashes';

  /// A banked figure this large means the flush has been failing for weeks; past
  /// it the number says "something is wrong with reporting", not "with the app".
  static const int _maxBanked = 5000;

  static SharedPreferences? _preferences;

  /// Call once at startup, after shared preferences exist and before the first
  /// frame. Banks this launch as a session and sends whatever is outstanding.
  static Future<void> begin(SharedPreferences preferences, Dio client) async {
    _preferences = preferences;
    await _bump(_sessionsKey);
    await _flush(client);
  }

  /// Call from the app's crash handlers. Only banks — never sends.
  static Future<void> recordCrash() => _bump(_crashesKey);

  static Future<void> _bump(String key) async {
    final SharedPreferences? preferences = _preferences;
    if (preferences == null) return;

    try {
      final int next = (preferences.getInt(key) ?? 0) + 1;
      if (next <= _maxBanked) await preferences.setInt(key, next);
    } catch (e) {
      debugPrint('AppHealthReporter: could not bank $key --- $e');
    }
  }

  static Future<void> _flush(Dio client) async {
    final SharedPreferences? preferences = _preferences;
    if (preferences == null) return;

    final int sessions = preferences.getInt(_sessionsKey) ?? 0;
    final int crashes = preferences.getInt(_crashesKey) ?? 0;
    if (sessions == 0 && crashes == 0) return;

    try {
      final Response<dynamic> response = await client.post<dynamic>(
        AppConstants.appHealthUri,
        data: <String, dynamic>{
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'app_version': AppVersion.current,
          'sessions': sessions,
          'crashes': crashes,
        },
      );

      // The endpoint answers 204 to everything it accepts, including a payload
      // it rejects. Clearing only on a 2xx is what stops a network failure from
      // erasing the counters it never managed to deliver.
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        await preferences.setInt(_sessionsKey, 0);
        await preferences.setInt(_crashesKey, 0);
      }
    } catch (e) {
      // Reporting that the app is healthy must never be the reason it is not.
      debugPrint('AppHealthReporter: could not report app health --- $e');
    }
  }
}
