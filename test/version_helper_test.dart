import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/helper/version_helper.dart';

void main() {
  group('AppVersion.compare', () {
    test('orders versions by numeric component, not string order', () {
      expect(AppVersion.compare('1.10.0', '1.9.0'), 1);
      expect(AppVersion.compare('1.9.0', '1.10.0'), -1);
      expect(AppVersion.compare('2.0.0', '10.0.0'), -1);
    });

    test('treats missing components as zero', () {
      expect(AppVersion.compare('1.2', '1.2.0'), 0);
      expect(AppVersion.compare('1.2.1', '1.2'), 1);
    });

    test('equal versions compare equal', () {
      expect(AppVersion.compare('1.0.3', '1.0.3'), 0);
    });

    test('tolerates whitespace and non-numeric junk', () {
      expect(AppVersion.compare(' 1.0.3 ', '1.0.3'), 0);
      expect(AppVersion.compare('1.0.x', '1.0.0'), 0);
    });
  });

  group('AppVersion.isUpdateRequired', () {
    test('is false when no minimum is published', () {
      expect(AppVersion.isUpdateRequired(null), isFalse);
      expect(AppVersion.isUpdateRequired(''), isFalse);
    });

    test('is false when the installed version is not older', () {
      // AppVersion.current defaults to 0.0.0 until load() runs against the
      // platform, so a published minimum of 0.0.0 must not force an update.
      expect(AppVersion.isUpdateRequired('0.0.0'), isFalse);
    });

    test('is true when the published minimum is newer', () {
      expect(AppVersion.isUpdateRequired('99.0.0'), isTrue);
    });
  });
}
