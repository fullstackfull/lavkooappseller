import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/models/config_model.dart';
import 'package:syriacosmeticsmanger/helper/version_helper.dart';

/// The platform's switch for the seller force-update gate (K-V5, Discovery E19-F06).
///
/// The minimum version is a number typed into a form in the admin panel. Typed one digit too high it locks every seller out of
/// the app BEFORE the login screen, and until now the only way back was to type another number -- so a platform that had locked
/// itself out had to guess its way out. The platform has published a per-platform `status` beside the minimum all along, and the
/// app parsed it and then read nothing but the minimum.
///
/// `AppVersion.current` is '0.0.0' in a test, because `load()` reads the real package and is not run here, so a published
/// minimum of '99.0.0' is "newer than installed" and '0.0.0' is not.
void main() {
  group('the switch as the platform publishes it', () {
    test('1 is on and 0 is off', () {
      expect(PlatformVersion.fromJson(<String, dynamic>{'status': 1, 'version': '2.0.1', 'link': 'x'}).status, 1);
      expect(PlatformVersion.fromJson(<String, dynamic>{'status': 0, 'version': '2.0.1', 'link': 'x'}).status, 0);
      expect(PlatformVersion.fromJson(<String, dynamic>{'status': '1', 'version': '2.0.1', 'link': 'x'}).status, 1);
      expect(PlatformVersion.fromJson(<String, dynamic>{'status': '0', 'version': '2.0.1', 'link': 'x'}).status, 0);
    });

    test('a platform that published no switch published no switch, and is never read as having switched it off', () {
      for (final Map<String, dynamic> published in <Map<String, dynamic>>[
        <String, dynamic>{'version': '99.0.0', 'link': 'x'},
        <String, dynamic>{'status': null, 'version': '99.0.0', 'link': 'x'},
        <String, dynamic>{'status': '', 'version': '99.0.0', 'link': 'x'},
        <String, dynamic>{'status': 'on', 'version': '99.0.0', 'link': 'x'},
      ]) {
        final PlatformVersion version = PlatformVersion.fromJson(published);

        expect(version.status, isNull, reason: '$published');
        expect(AppVersion.isGateOn(version.status), isTrue, reason: '$published: the gate stays where it was');
        expect(
          AppVersion.refusesEntryUntilUpdated(minimumVersion: version.version, publishedStatus: version.status),
          isTrue,
          reason: '$published: an absent switch must not open the gate on every installation at once',
        );
      }
    });

    test('each platform carries its own switch, and neither is read for the other', () {
      final SellerAppVersionControl published = SellerAppVersionControl.fromJson(<String, dynamic>{
        'for_android': <String, dynamic>{'status': 0, 'version': '99.0.0', 'link': 'play'},
        'for_ios': <String, dynamic>{'status': 1, 'version': '99.0.0', 'link': 'app-store'},
      });

      expect(published.forAndroid?.status, 0);
      expect(published.forIos?.status, 1);
      expect(
        AppVersion.refusesEntryUntilUpdated(
            minimumVersion: published.forAndroid?.version, publishedStatus: published.forAndroid?.status),
        isFalse,
        reason: 'Android was let through',
      );
      expect(
        AppVersion.refusesEntryUntilUpdated(
            minimumVersion: published.forIos?.version, publishedStatus: published.forIos?.status),
        isTrue,
        reason: 'and iOS was not',
      );
    });

    test('a platform that published nothing for a platform at all leaves that platform alone', () {
      final SellerAppVersionControl published =
          SellerAppVersionControl.fromJson(<String, dynamic>{'for_android': <String, dynamic>{'status': 1, 'version': '99.0.0'}});

      expect(published.forIos, isNull);
      expect(
        AppVersion.refusesEntryUntilUpdated(
            minimumVersion: published.forIos?.version, publishedStatus: published.forIos?.status),
        isFalse,
        reason: 'no minimum published for iOS refuses nobody, as it always did',
      );
    });
  });

  group('what the gate does with the switch', () {
    test('the gate on, with a minimum newer than what is installed, refuses entry -- as it always has', () {
      expect(AppVersion.refusesEntryUntilUpdated(minimumVersion: '99.0.0', publishedStatus: 1), isTrue);
    });

    test('THE GATE OFF lets a seller below the minimum reach the login form', () {
      expect(AppVersion.refusesEntryUntilUpdated(minimumVersion: '99.0.0', publishedStatus: 0), isFalse);
      expect(AppVersion.isGateOn(0), isFalse);
    });

    test('the gate off refuses nobody, whatever minimum was published', () {
      for (final String minimum in <String>['99.0.0', '2.0.1', '0.0.1', '', '0.0.0']) {
        expect(AppVersion.refusesEntryUntilUpdated(minimumVersion: minimum, publishedStatus: 0), isFalse,
            reason: 'minimum $minimum');
      }
    });

    test('the gate on still refuses nobody when the minimum is not newer, or was not published', () {
      expect(AppVersion.refusesEntryUntilUpdated(minimumVersion: '0.0.0', publishedStatus: 1), isFalse);
      expect(AppVersion.refusesEntryUntilUpdated(minimumVersion: '', publishedStatus: 1), isFalse);
      expect(AppVersion.refusesEntryUntilUpdated(minimumVersion: null, publishedStatus: 1), isFalse);
    });

    test('a status the app has never seen is not an off switch: only 0 is', () {
      for (final int published in <int>[1, 2, -1, 7]) {
        expect(AppVersion.isGateOn(published), isTrue, reason: 'status $published');
      }
    });
  });

  group('by reading the source', () {
    test('the splash gate consults the switch and no longer decides on the minimum alone', () {
      final String splash = File('lib/features/splash/screens/splash_screen.dart').readAsStringSync();

      expect(
        splash,
        contains('AppVersion.refusesEntryUntilUpdated(minimumVersion: minimumVersion, publishedStatus: versionGateStatus)'),
      );
      expect(splash, isNot(contains('AppVersion.isUpdateRequired(')),
          reason: 'the minimum alone is no longer the whole decision');
    });

    test('it reads the switch of the platform it is running on, from the same branch as that platform\'s minimum', () {
      final String splash = File('lib/features/splash/screens/splash_screen.dart').readAsStringSync();

      expect(splash, contains('versionGateStatus = appVersion?.forAndroid?.status;'));
      expect(splash, contains('versionGateStatus = appVersion?.forIos?.status;'));
      expect(
        splash.indexOf('versionGateStatus = appVersion?.forAndroid?.status;'),
        lessThan(splash.indexOf('versionGateStatus = appVersion?.forIos?.status;')),
        reason: 'each in the branch of its own platform, in the order the branches are written',
      );
    });

    test('switching the gate off needs no release: the rule is not behind a build flag', () {
      final String helper = File('lib/helper/version_helper.dart').readAsStringSync();

      expect(helper, isNot(contains('fromEnvironment')),
          reason: 'a dart-define would put the off switch behind a release, which is the thing this requirement forbids');
    });

    test('the parse of the switch does not fall back to a value that means off', () {
      final String config = File('lib/features/splash/domain/models/config_model.dart').readAsStringSync();

      expect(config, contains("status: int.tryParse(json['status']?.toString() ?? ''),"));
      expect(config, isNot(contains("json['status']?.toString() ?? '0'")),
          reason: 'an absent switch read as 0 is a platform that switched the gate off without asking');
    });
  });
}
