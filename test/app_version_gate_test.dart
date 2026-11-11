import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/helper/version_helper.dart';

/// The minimum seller-app version the production backend publishes in
/// `seller_app_version_control` (Admin → Business Settings → App Settings).
///
/// The splash screen force-updates — and therefore blocks the login screen
/// entirely — whenever the installed version is older than this. Shipping a
/// `pubspec.yaml` version below it locks every seller out of the app with no
/// way through, which is exactly what happened when the version dropped to the
/// fork's own `1.1.0` line while the backend still required `14.1`.
///
/// If the backend minimum is lowered, lower this too; never lower the app
/// version below it.
const String kBackendPublishedMinimumVersion = '2.0.1';

String _pubspecVersion() {
  final RegExp versionLine = RegExp(r'^version:\s*([0-9][^\s+]*)', multiLine: true);
  final RegExpMatch? match = versionLine.firstMatch(File('pubspec.yaml').readAsStringSync());
  expect(match, isNotNull, reason: 'pubspec.yaml has no parsable version line');
  return match!.group(1)!;
}

void main() {
  group('force-update gate', () {
    test('the shipped version clears the backend minimum, so login is reachable', () {
      final String shipped = _pubspecVersion();

      expect(
        AppVersion.compare(shipped, kBackendPublishedMinimumVersion),
        greaterThanOrEqualTo(0),
        reason: 'pubspec version $shipped is older than the backend minimum '
            '$kBackendPublishedMinimumVersion — the splash screen would show '
            'UpdateScreen and no seller could reach the login form',
      );
    });

    test('a version below the backend minimum would be force-updated', () {
      // Guards the guard: proves the comparison above actually catches the
      // regression it is written for (this was the shipped state).
      expect(AppVersion.compare('1.1.0', kBackendPublishedMinimumVersion), lessThan(0));
    });
  });
}
