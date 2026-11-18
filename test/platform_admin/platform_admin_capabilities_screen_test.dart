import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_home_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_overview_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_shell_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_choice_chips.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

/// The shell of an admin whose grant includes only some parts of the API.
///
/// The example of the backend's runbook is a country manager with the overview and the alerts: no markets, no
/// audit log and no sessions. Such an admin is shown those two screens, can still sign out, and is told when the access ends.
void main() {
  late FakePlatformAdminService service;
  late PlatformAdminController controller;
  late DateTime now;

  setUp(() {
    service = FakePlatformAdminService();
    now = DateTime.utc(2026, 11, 17, 10);
    controller = PlatformAdminController(platformAdminServiceInterface: service, now: () => now);
  });

  PlatformAdminProfile countryManager() => PlatformAdminProfile.fromJson(fixtureData('me_restricted_capabilities'));

  PlatformAdminProfile ownerWith(List<String> capabilities) => PlatformAdminProfile.fromJson(
      <String, dynamic>{...fixtureData('me_with_capabilities'), 'capabilities': capabilities});

  Future<void> signIn(PlatformAdminProfile profile) async {
    service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(profile);
    service.onProfile = () async => PlatformAdminResult<PlatformAdminProfile>.success(profile);
    await controller.restoreSession();
    service.calls.clear();
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    Locale locale = PlatformAdminHarness.english,
    double textScale = 1.0,
    Size size = PlatformAdminHarness.phone,
    bool darkTheme = false,
  }) async {
    PlatformAdminHarness.useScreen(tester, size);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      home: const PlatformAdminHomeScreen(),
      controller: controller,
      locale: locale,
      textScale: textScale,
      darkTheme: darkTheme,
    ));
    await tester.pump();
    await tester.pump();
  }

  Finder tab(String label) => find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label));

  Finder inTitle(String title) => find.descendant(of: find.byType(AppBar), matching: find.text(title));

  Finder signOutInTheBar() => find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.logout_rounded));

  group('a country manager with the overview and the alerts', () {
    testWidgets('is offered those two screens and no others, and in their order', (WidgetTester tester) async {
      await signIn(countryManager());

      await pumpHome(tester);

      expect(tab('Overview'), findsOneWidget);
      expect(tab('Alerts'), findsOneWidget);
      expect(tab('Sessions'), findsNothing);
      expect(tab('Audit log'), findsNothing);
      expect(
          find.descendant(of: find.byType(BottomNavigationBar), matching: find.byType(InkResponse)), findsNWidgets(2));
      expect(inTitle('Overview'), findsOneWidget);
    });

    testWidgets('asks for the overview and for nothing the grant leaves out: not the markets, not the sessions',
        (WidgetTester tester) async {
      await signIn(countryManager());

      await pumpHome(tester);
      await tester.tap(tab('Alerts'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['overview all null', 'alerts all p1 null']);
    });

    testWidgets('chooses between the two markets of the grant, without the directory of markets',
        (WidgetTester tester) async {
      await signIn(countryManager());

      await pumpHome(tester);

      final Finder chips = find.byType(PlatformChipRow<String>);
      expect(find.descendant(of: chips, matching: find.text('My markets')), findsOneWidget);
      expect(find.descendant(of: chips, matching: find.text('UAE')), findsOneWidget);
      expect(find.descendant(of: chips, matching: find.text('Kuwait')), findsOneWidget);
      expect(find.descendant(of: chips, matching: find.text('Saudi Arabia')), findsNothing,
          reason: 'a market the grant does not name is not offered');
    });

    testWidgets('can sign out, which the server never withholds, from the bar, after being asked',
        (WidgetTester tester) async {
      await signIn(countryManager());
      await pumpHome(tester);

      await tester.tap(signOutInTheBar());
      await tester.pumpAndSettle();

      expect(find.text('Sign out of platform admin on this phone?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.calls, isNot(contains('signOut')), reason: 'a slip of the finger signs nobody out');

      await tester.tap(signOutInTheBar());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(service.calls, contains('signOut'));
    });

    testWidgets('says when the access ends, in the zone of the phone, under the bar and nowhere else',
        (WidgetTester tester) async {
      await signIn(countryManager());

      await pumpHome(tester);

      final String moment = PlatformAdminTexts.moment(DateTime.utc(2027, 3, 31, 20, 59, 59));
      expect(find.text('Your access ends: $moment'), findsOneWidget);
      final double bar = tester.getBottomLeft(find.byType(AppBar)).dy;
      expect(tester.getTopLeft(find.text('Your access ends: $moment')).dy, greaterThanOrEqualTo(bar));
    });

    testWidgets('and says it in Arabic, with nothing left as a key', (WidgetTester tester) async {
      await signIn(countryManager());

      await pumpHome(tester, locale: PlatformAdminHarness.arabic);

      expect(find.textContaining('ينتهي وصولك'), findsOneWidget);
      expect(tab('ملخص'), findsOneWidget);
      expect(PlatformAdminHarness.texts(tester).where((String text) => text.startsWith('platform_admin_')), isEmpty);
    });
  });

  group('the platform owner', () {
    testWidgets('has the four screens, as before, with no sign-out in the bar, because the sessions screen has it',
        (WidgetTester tester) async {
      await signIn(PlatformAdminProfile.fromJson(fixtureData('me_with_capabilities')));

      await pumpHome(tester);

      for (final String label in <String>['Overview', 'Alerts', 'Sessions', 'Audit log']) {
        expect(tab(label), findsOneWidget, reason: label);
      }
      expect(signOutInTheBar(), findsNothing);
      expect(find.textContaining('Your access ends'), findsNothing, reason: 'a grant with no end says nothing of one');
    });

    testWidgets('and a server that lists no capabilities gives the same four screens', (WidgetTester tester) async {
      await signIn(ownerProfile());

      await pumpHome(tester);

      expect(
          find.descendant(of: find.byType(BottomNavigationBar), matching: find.byType(InkResponse)), findsNWidgets(4));
    });
  });

  group('a grant with one part, or none', () {
    testWidgets('one part is the screen itself: no bar to choose with, its name in the title, and a way out',
        (WidgetTester tester) async {
      await signIn(ownerWith(<String>['alerts']));

      await pumpHome(tester);

      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(inTitle('Alerts'), findsOneWidget);
      expect(signOutInTheBar(), findsOneWidget);
      expect(service.calls, <String>['alerts all p1 null']);
    });

    testWidgets('only the sessions is the screen with its own sign-out, and none is added',
        (WidgetTester tester) async {
      await signIn(ownerWith(<String>['sessions']));

      await pumpHome(tester);

      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(inTitle('Sessions'), findsOneWidget);
      expect(signOutInTheBar(), findsNothing);
      await tester.scrollUntilVisible(find.text('Logout'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('no part says so, asks for nothing and still lets the admin out', (WidgetTester tester) async {
      await signIn(ownerWith(<String>[]));

      await pumpHome(tester);

      expect(find.text('No part of the platform admin is included in your access yet.'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(inTitle('Platform admin'), findsOneWidget);
      expect(signOutInTheBar(), findsOneWidget);
      expect(service.calls, isEmpty);
    });
  });

  group('a part the server says is not included, though it was offered', () {
    testWidgets('is said as that, calmly, with no way to ask again, and the list is read again',
        (WidgetTester tester) async {
      await signIn(PlatformAdminProfile.fromJson(fixtureData('me_with_capabilities')));
      service.onAuditLogs = (int page) async => refused<PlatformAuditPage>('error_capability_not_allowed');
      await pumpHome(tester);

      await tester.tap(tab('Audit log'));
      await tester.pump();
      await tester.pump();

      expect(find.text('This part is not included in your access.'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(service.count('profile'), 1);
    });

    testWidgets(
        'and when the list says it is gone, its tab goes, and the admin is where they can be: the first screen, loaded',
        (WidgetTester tester) async {
      await signIn(PlatformAdminProfile.fromJson(fixtureData('me_with_capabilities')));
      service.onAuditLogs = (int page) async => refused<PlatformAuditPage>('error_capability_not_allowed');
      service.onProfile = () async => PlatformAdminResult<PlatformAdminProfile>.success(
          ownerWith(<String>['overview', 'markets', 'alerts', 'sessions']));
      await pumpHome(tester);

      await tester.tap(tab('Audit log'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(tab('Audit log'), findsNothing);
      expect(inTitle('Overview'), findsOneWidget);
      expect(find.text('This part is not included in your access.'), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(
          find.descendant(of: find.byType(BottomNavigationBar), matching: find.byType(InkResponse)), findsNWidgets(3));
      expect(controller.overview, isNotNull, reason: 'the screen it landed on asked for what it shows');
    });

    testWidgets('an overview that is refused is said the same way, and a retry is not offered for it either',
        (WidgetTester tester) async {
      await signIn(countryManager());
      service.onOverview =
          (String market, int? windowDays) async => refused<PlatformOverviewModel>('error_capability_not_allowed');

      await pumpHome(tester);

      expect(find.text('This part is not included in your access.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('when what the grant includes changes while the app is open', () {
    testWidgets('a part that is added gets its tab, and a part that is taken away loses it',
        (WidgetTester tester) async {
      await signIn(countryManager());
      await pumpHome(tester);

      service.onProfile =
          () async => PlatformAdminResult<PlatformAdminProfile>.success(PlatformAdminProfile.fromJson(<String, dynamic>{
                ...fixtureData('me_restricted_capabilities'),
                'capabilities': <String>['overview', 'alerts', 'sessions']
              }));
      await controller.refreshProfile();
      await tester.pump();
      await tester.pump();

      expect(tab('Sessions'), findsOneWidget);
      expect(
          find.descendant(of: find.byType(BottomNavigationBar), matching: find.byType(InkResponse)), findsNWidgets(3));
      expect(signOutInTheBar(), findsNothing, reason: 'the sessions screen has the sign-out now');

      service.onProfile =
          () async => PlatformAdminResult<PlatformAdminProfile>.success(PlatformAdminProfile.fromJson(<String, dynamic>{
                ...fixtureData('me_restricted_capabilities'),
                'capabilities': <String>['alerts', 'sessions']
              }));
      await controller.refreshProfile();
      await tester.pump();
      await tester.pump();

      expect(tab('Overview'), findsNothing);
      expect(inTitle('Alerts'), findsOneWidget,
          reason: 'the overview was in front, and is gone: the first that is left is shown');
    });

    testWidgets('a grant that went from nothing to something shows it at once, loaded', (WidgetTester tester) async {
      await signIn(ownerWith(<String>[]));
      await pumpHome(tester);

      service.onProfile =
          () async => PlatformAdminResult<PlatformAdminProfile>.success(ownerWith(<String>['overview', 'alerts']));
      await controller.refreshProfile();
      await tester.pump();
      await tester.pump();

      expect(find.text('No part of the platform admin is included in your access yet.'), findsNothing);
      expect(find.byType(PlatformAdminOverviewScreen), findsOneWidget);
      expect(controller.overview, isNotNull);
    });

    testWidgets('a scope that changed throws away what the screen in front held, and it asks again',
        (WidgetTester tester) async {
      await signIn(countryManager());
      await pumpHome(tester);
      expect(controller.overview, isNotNull);
      service.calls.clear();
      service.onProfile =
          () async => PlatformAdminResult<PlatformAdminProfile>.success(PlatformAdminProfile.fromJson(<String, dynamic>{
                ...fixtureData('me_restricted_capabilities'),
                'markets': <String>['AE']
              }));

      await controller.refreshProfile();
      await tester.pump();
      await tester.pump();

      expect(service.count('overview'), 1);
      expect(controller.overview, isNotNull);
    });
  });

  group('a session that is over', () {
    testWidgets('puts the admin back at the sign-in, once, with the calm note, whatever the grant',
        (WidgetTester tester) async {
      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(countryManager());
      service.onOverview =
          (String market, int? windowDays) async => refused<PlatformOverviewModel>('error_unauthenticated');
      PlatformAdminHarness.useScreen(tester, PlatformAdminHarness.phone);
      await tester.pumpWidget(
          await PlatformAdminHarness.app(tester, home: const PlatformAdminShellScreen(), controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(service.count('overview'), 1, reason: 'no retry loop');
      expect(service.calls.where((String call) => call.startsWith('signIn')), isEmpty,
          reason: 'the password is never sent again by itself');
    });
  });

  group('the warning about recovery codes', () {
    Future<void> signedInWithRecovery(String fixtureName) async {
      service.onSignIn = () async => PlatformAdminResult<PlatformAdminSignInStep>.success(secondFactorWanted());
      service.onSignInWithSecondFactor =
          () async => PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn(fixtureName));
      await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');
      await controller.verifySecondFactor(method: PlatformAdminMfaMethod.recoveryCode, code: 'abcde-fghj2');
      service.calls.clear();
    }

    testWidgets('is shown when two are left, says how many, and can be put away', (WidgetTester tester) async {
      await signedInWithRecovery('mfa_success_recovery_code');

      await pumpHome(tester);

      expect(
          find.text('Recovery codes left: 2. Ask the platform owner for new ones before you run out.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.textContaining('Recovery codes left'), findsNothing);
    });

    testWidgets('says that none are left in words of its own', (WidgetTester tester) async {
      await signedInWithRecovery('mfa_success_recovery_code_none_left');

      await pumpHome(tester);

      expect(find.text('You have no recovery codes left. Ask the platform owner to set up your second factor again.'),
          findsOneWidget);
    });

    testWidgets('is not shown when there are enough, and is said in Arabic when there are not',
        (WidgetTester tester) async {
      await signedInWithRecovery('mfa_success_totp');
      await pumpHome(tester);
      expect(find.textContaining('Recovery codes left'), findsNothing);

      controller = PlatformAdminController(platformAdminServiceInterface: service, now: () => now);
      await signedInWithRecovery('mfa_success_recovery_code');
      await tester.pumpWidget(const SizedBox());
      await pumpHome(tester, locale: PlatformAdminHarness.arabic);

      expect(find.textContaining('رموز الاسترداد المتبقية: 2'), findsOneWidget);
    });
  });

  group('on a small phone with large text', () {
    testWidgets('a country manager with an end to the access and a warning fits, in either language, light and dark',
        (WidgetTester tester) async {
      for (final Locale locale in <Locale>[PlatformAdminHarness.english, PlatformAdminHarness.arabic]) {
        for (final bool dark in <bool>[false, true]) {
          service = FakePlatformAdminService();
          controller = PlatformAdminController(platformAdminServiceInterface: service, now: () => now);
          service.onSignIn = () async => PlatformAdminResult<PlatformAdminSignInStep>.success(secondFactorWanted());
          service.onSignInWithSecondFactor = () async =>
              PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn('mfa_success_recovery_code'));
          service.onProfile = () async => PlatformAdminResult<PlatformAdminProfile>.success(countryManager());
          await controller.signIn(email: 'a@example.test', password: 'x', deviceName: 'Pixel');
          await controller.verifySecondFactor(method: PlatformAdminMfaMethod.recoveryCode, code: 'abcde-fghj2');

          await pumpHome(tester,
              locale: locale, textScale: 2.0, size: PlatformAdminHarness.narrowPhone, darkTheme: dark);

          expect(tester.takeException(), isNull, reason: '${locale.languageCode} dark: $dark');
          await tester.drag(find.byType(ListView).first, const Offset(0, -600));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${locale.languageCode} dark: $dark, scrolled');
          await tester.pumpWidget(const SizedBox());
        }
      }
    });

    testWidgets('and so does a grant with nothing in it', (WidgetTester tester) async {
      await signIn(ownerWith(<String>[]));

      await pumpHome(tester, textScale: 2.0, size: PlatformAdminHarness.narrowPhone);

      expect(tester.takeException(), isNull);
    });
  });
}
