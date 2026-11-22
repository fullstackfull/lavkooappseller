import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_home_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_second_factor_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_shell_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_sign_in_screen.dart';

import 'support/fake_service.dart';
import 'support/harness.dart';

/// Which screen the admin is on follows the state of the platform session, and
/// nothing else.
void main() {
  late FakePlatformAdminService service;
  late PlatformAdminController controller;

  setUp(() {
    service = FakePlatformAdminService();
    controller = PlatformAdminController(platformAdminServiceInterface: service);
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  /// The shell in front of a screen standing for the seller's login, as it is in the app.
  Future<void> pumpShellOverLogin(WidgetTester tester) async {
    PlatformAdminHarness.useScreen(tester, PlatformAdminHarness.phone);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      controller: controller,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider<PlatformAdminController>.value(
                    value: controller, child: const PlatformAdminShellScreen()))),
            child: const Text('the seller\'s login screen'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('the seller\'s login screen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('opening the shell', () {
    testWidgets('looks for a session of an earlier launch, and shows that it is looking', (WidgetTester tester) async {
      final Gate<PlatformAdminResult<PlatformAdminProfile?>> gate = Gate<PlatformAdminResult<PlatformAdminProfile?>>();
      service.onRestore = () => gate.future;

      await pumpShellOverLogin(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PlatformAdminSignInScreen), findsNothing);
      gate.open(const PlatformAdminResult<PlatformAdminProfile?>.success(null));
      await tester.pumpAndSettle();
      expect(find.byType(PlatformAdminSignInScreen), findsOneWidget);
    });

    testWidgets('with none, shows the sign-in and nothing of the platform', (WidgetTester tester) async {
      await pumpShellOverLogin(tester);
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminSignInScreen), findsOneWidget);
      expect(find.byType(PlatformAdminHomeScreen), findsNothing);
      expect(service.calls, <String>['restore']);
    });

    testWidgets(
        'with one the server confirms, goes straight to the signed-in screens, and asks who the admin is only once',
        (WidgetTester tester) async {
      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());

      await pumpShellOverLogin(tester);
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminHomeScreen), findsOneWidget);
      expect(find.byType(PlatformAdminSignInScreen), findsNothing);
      expect(service.calls, <String>['restore', 'markets', 'overview all null']);
    });

    testWidgets(
        'with one that could not be checked, says so the way the app does when it has no connection, and tries again when asked',
        (WidgetTester tester) async {
      service.onRestore = () async => unreachable<PlatformAdminProfile?>();
      await pumpShellOverLogin(tester);
      await tester.pumpAndSettle();

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminHomeScreen), findsOneWidget);
    });

    testWidgets('with one the server refuses, shows the sign-in and says the session ended, without an alarm',
        (WidgetTester tester) async {
      service.onRestore = () async => refused<PlatformAdminProfile?>('error_unauthenticated');

      await pumpShellOverLogin(tester);
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminSignInScreen), findsOneWidget);
      expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an API that is switched off is said as that, not as a connection that failed',
        (WidgetTester tester) async {
      service.onRestore = () async => refused<PlatformAdminProfile?>('error_api_switched_off');

      await pumpShellOverLogin(tester);
      await tester.pumpAndSettle();

      expect(find.text('Platform admin is not available right now.'), findsOneWidget);
    });
  });

  group('when the server wants a second factor', () {
    late DateTime now;

    setUp(() {
      service.onSignIn = () async => PlatformAdminResult<PlatformAdminSignInStep>.success(secondFactorWanted());
      now = DateTime.utc(2026, 11, 17, 10);
      controller = PlatformAdminController(platformAdminServiceInterface: service, now: () => now);
    });

    Future<void> passwordStep(WidgetTester tester) async {
      await pumpShellOverLogin(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'owner@example.test');
      await tester.enterText(find.byType(TextField).at(1), 'a-password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
    }

    Finder codeField() => find.descendant(of: find.byType(CustomTextFieldWidget), matching: find.byType(TextField));

    testWidgets('a good password leads to the second step, in the same route, and not to the signed-in screens',
        (WidgetTester tester) async {
      await passwordStep(tester);

      expect(find.byType(PlatformAdminSecondFactorScreen), findsOneWidget);
      expect(find.byType(PlatformAdminSignInScreen), findsNothing);
      expect(find.byType(PlatformAdminHomeScreen), findsNothing);
      expect(controller.stage, PlatformAdminStage.secondFactor);
    });

    testWidgets('a right code leads to the signed-in screens, and the second step is gone',
        (WidgetTester tester) async {
      await passwordStep(tester);

      await tester.enterText(codeField(), '123456');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminHomeScreen), findsOneWidget);
      expect(find.byType(PlatformAdminSecondFactorScreen), findsNothing);
    });

    testWidgets('going back shows the password step again, with the password gone and no note',
        (WidgetTester tester) async {
      await passwordStep(tester);

      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminSignInScreen), findsOneWidget);
      expect(find.text('The sign-in took too long. Enter your password again.'), findsNothing);
      expect(find.text('Too many wrong codes. Enter your password again.'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, isEmpty);
    });

    testWidgets('five wrong codes show the password step again, with the reason, calmly', (WidgetTester tester) async {
      service.onSignInWithSecondFactor = () async => refused<PlatformAdminSignIn>('mfa_failed');
      await passwordStep(tester);

      for (int attempt = 0; attempt < 5; attempt++) {
        await tester.enterText(codeField(), '123456');
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();
      }

      expect(find.byType(PlatformAdminSignInScreen), findsOneWidget);
      expect(find.text('Too many wrong codes. Enter your password again.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        'a challenge that ran out shows the password step again, with the reason, when the admin tries to use it',
        (WidgetTester tester) async {
      await passwordStep(tester);

      now = DateTime.utc(2026, 11, 17, 10, 5);
      await tester.enterText(codeField(), '123456');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminSignInScreen), findsOneWidget);
      expect(find.text('The sign-in took too long. Enter your password again.'), findsOneWidget);
      expect(service.count('signInWithSecondFactor'), 0);
    });

    testWidgets('a session that is refused as soon as it is open shows the password step with the note that it ended',
        (WidgetTester tester) async {
      service.onProfile = () async => refused<PlatformAdminProfile>('error_unauthenticated');
      await passwordStep(tester);

      await tester.enterText(codeField(), '123456');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminSignInScreen), findsOneWidget);
      expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
    });
  });

  group('while the admin is in the shell', () {
    testWidgets('signing in shows the signed-in screens, in the same route', (WidgetTester tester) async {
      await pumpShellOverLogin(tester);
      await tester.pumpAndSettle();

      await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminHomeScreen), findsOneWidget);
      expect(find.byType(PlatformAdminSignInScreen), findsNothing);
    });

    testWidgets('a refusal of the token, met by any screen, puts the admin back at the sign-in with a note, silently',
        (WidgetTester tester) async {
      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await pumpShellOverLogin(tester);
      await tester.pumpAndSettle();
      service.onOverview =
          (String market, int? windowDays) async => refused<PlatformOverviewModel>('error_unauthenticated');

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminSignInScreen), findsOneWidget);
      expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(PlatformAdminHomeScreen), findsNothing);
      expect(controller.overview, isNull);
      expect(controller.profile, isNull);
    });

    testWidgets('signing out leaves the shell, and the seller\'s login screen is what is in front',
        (WidgetTester tester) async {
      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await pumpShellOverLogin(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Sessions')));
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Logout'), 300, scrollable: find.byType(Scrollable).first);

      await tester.ensureVisible(find.text('Logout'));
      await tester.pump();
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(find.text('the seller\'s login screen'), findsOneWidget);
      expect(find.byType(PlatformAdminShellScreen), findsNothing);
      expect(service.calls.last, 'signOut');
      expect(controller.stage, PlatformAdminStage.signedOut);
    });

    testWidgets(
        'leaving with the back button also returns to the login screen, and leaves the session where it was for the next opening',
        (WidgetTester tester) async {
      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await pumpShellOverLogin(tester);
      await tester.pumpAndSettle();

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(find.text('the seller\'s login screen'), findsOneWidget);
      expect(service.calls, isNot(contains('signOut')), reason: 'leaving is not signing out');
    });
  });
}
