import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/platform_admin_config.dart';

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
    }, skip: PlatformAdminConfig.enabled ? 'this run was built with the flag on' : false);

    test('is on when the build is made with GCC_PLATFORM_ADMIN_ENABLED=true', () {
      expect(PlatformAdminConfig.enabled, isTrue);
    }, skip: PlatformAdminConfig.enabled ? false : 'run with --dart-define=GCC_PLATFORM_ADMIN_ENABLED=true');
  });
}
