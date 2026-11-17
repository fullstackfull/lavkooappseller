import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/platform_admin_config.dart';

/// What this run was told about the flag, read here and not through the config,
/// so that a default that was changed to "on" cannot hide behind the very run it
/// spoils: it would only look like a run that was built with the flag on.
const String _told = String.fromEnvironment('GCC_PLATFORM_ADMIN_ENABLED');

/// The platform admin shell ships off. A build that is not made with
/// `--dart-define=GCC_PLATFORM_ADMIN_ENABLED=true` has to behave exactly as the
/// app did before the shell existed, and these two tests say which kind of build
/// this run is, so that neither a flag left on nor a flag that cannot be turned
/// on goes unnoticed.
///
/// Run the flag-on half with:
/// `flutter test --dart-define=GCC_PLATFORM_ADMIN_ENABLED=true test/platform_admin`
void main() {
  group('the platform admin flag', () {
    test('is off unless the build is made with GCC_PLATFORM_ADMIN_ENABLED=true', () {
      expect(PlatformAdminConfig.enabled, isFalse);
    }, skip: _told == 'true' ? 'this run was built with the flag on' : false);

    test('is on when the build is made with GCC_PLATFORM_ADMIN_ENABLED=true', () {
      expect(PlatformAdminConfig.enabled, isTrue);
    }, skip: _told == 'true' ? false : 'run with --dart-define=GCC_PLATFORM_ADMIN_ENABLED=true');
  });
}
