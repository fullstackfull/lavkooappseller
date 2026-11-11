import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The app's real version, read from the platform package at startup.
///
/// The version used to be a hardcoded constant inherited from the upstream
/// template ('16.2.1'), which silently disabled the forced-update check: any
/// minimum version the backend published in the app's real `1.x` scheme
/// compared as older, so the dialog could never fire.
class AppVersion {
  AppVersion._();

  static String _version = '0.0.0';
  static String _buildNumber = '0';

  static String get current => _version;
  static String get buildNumber => _buildNumber;
  static String get display => '$_version+$_buildNumber';

  static Future<void> load() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) _version = info.version;
      if (info.buildNumber.isNotEmpty) _buildNumber = info.buildNumber;
      debugPrint('AppVersion: loaded version=$_version, buildNumber=$_buildNumber');
    } catch (e) {
      debugPrint('AppVersion: could not read package info --- $e');
    }
  }

  /// Compares dotted version strings.
  ///
  /// Returns 1 when [version1] is newer, -1 when it is older, 0 when equal.
  /// Missing components count as 0, so "1.2" and "1.2.0" are equal.
  static int compare(String version1, String version2) {
    final List<String> a = version1.split('.');
    final List<String> b = version2.split('.');
    final int maxLength = a.length > b.length ? a.length : b.length;

    for (int i = 0; i < maxLength; i++) {
      final int p1 = i < a.length ? int.tryParse(a[i].trim()) ?? 0 : 0;
      final int p2 = i < b.length ? int.tryParse(b[i].trim()) ?? 0 : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  /// True when the server's published minimum is newer than what is installed.
  static bool isUpdateRequired(String? minimumVersion) {
    if (minimumVersion == null || minimumVersion.isEmpty) return false;
    return compare(minimumVersion, _version) == 1;
  }
}
