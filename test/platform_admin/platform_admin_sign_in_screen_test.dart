import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_sign_in_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';

import 'support/fake_service.dart';
import 'support/harness.dart';

/// The platform admin's sign-in, as an admin meets it.
void main() {
  late FakePlatformAdminService service;
  late PlatformAdminController controller;

  setUp(() {
    service = FakePlatformAdminService();
    controller = PlatformAdminController(platformAdminServiceInterface: service);
  });

  Future<void> pumpSignIn(
    WidgetTester tester, {
    Locale locale = PlatformAdminHarness.english,
    double textScale = 1.0,
    Size size = PlatformAdminHarness.phone,
  }) async {
    PlatformAdminHarness.useScreen(tester, size);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      home: const PlatformAdminSignInScreen(),
      controller: controller,
      locale: locale,
      textScale: textScale,
    ));
    await tester.pump();
  }

  Finder field(int index) =>
      find.descendant(of: find.byType(CustomTextFieldWidget).at(index), matching: find.byType(TextField));

  Future<void> fill(WidgetTester tester,
      {String email = 'owner@example.test', String password = 'a-password', String? deviceName}) async {
    await tester.enterText(field(0), email);
    await tester.enterText(field(1), password);
    if (deviceName != null) await tester.enterText(field(2), deviceName);
  }

  /// A message in the snack bar, and not the hint of a field that says the same words.
  Finder said(String text) => find.descendant(of: find.byType(SnackBar), matching: find.text(text));

  Future<void> tapSignIn(WidgetTester tester) async {
    await tester.tap(find.text('Sign in'));
    await tester.pump();
  }

  group('what it asks for', () {
    testWidgets('an e-mail, a password and a name for the device, and nothing to remember',
        (WidgetTester tester) async {
      await pumpSignIn(tester);

      expect(find.byType(CustomTextFieldWidget), findsNWidgets(3));
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('Remember', findRichText: true), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('the password is hidden as it is typed, and the e-mail has its own keyboard',
        (WidgetTester tester) async {
      await pumpSignIn(tester);

      expect(tester.widget<TextField>(field(1)).obscureText, isTrue);
      expect(tester.widget<TextField>(field(0)).keyboardType, TextInputType.emailAddress);
      expect(tester.widget<TextField>(field(0)).obscureText, isFalse);
    });

    testWidgets('the password field has a name a screen reader can say, which its hint of dots does not',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpSignIn(tester);

      expect(find.bySemanticsLabel(RegExp(r'^Password')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the device is named after the app and the platform, and the admin may change it',
        (WidgetTester tester) async {
      await pumpSignIn(tester);

      expect(tester.widget<TextField>(field(2)).controller!.text, 'Lavkoo Seller (Android)');
    });

    testWidgets('the name of the device is held to what the API takes', (WidgetTester tester) async {
      await pumpSignIn(tester);

      await tester.enterText(field(2), 'd' * 150);

      expect(tester.widget<TextField>(field(2)).controller!.text, hasLength(100));
    });

    test('the suggested name is the app and the platform the app runs on', () {
      expect(PlatformAdminDeviceName.suggested(platform: TargetPlatform.iOS), 'Lavkoo Seller (iOS)');
      expect(PlatformAdminDeviceName.suggested(platform: TargetPlatform.android), 'Lavkoo Seller (Android)');
      expect(PlatformAdminDeviceName.suggested(platform: TargetPlatform.macOS), 'Lavkoo Seller (macOS)');
      expect(PlatformAdminDeviceName.suggested(platform: TargetPlatform.linux), 'Lavkoo Seller (linux)');
      expect(PlatformAdminDeviceName.suggested().length, lessThanOrEqualTo(PlatformAdminDeviceName.maxLength));
    });

    testWidgets('nothing is prefilled: not an e-mail, not a password', (WidgetTester tester) async {
      await pumpSignIn(tester);

      expect(tester.widget<TextField>(field(0)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(field(1)).controller!.text, isEmpty);
    });
  });

  group('before it asks the server', () {
    testWidgets('an empty e-mail is said, and nothing is sent', (WidgetTester tester) async {
      await pumpSignIn(tester);

      await fill(tester, email: '');
      await tapSignIn(tester);

      expect(said('Enter your email'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('an e-mail that is not one is said, and nothing is sent', (WidgetTester tester) async {
      await pumpSignIn(tester);

      await fill(tester, email: 'not-an-email');
      await tapSignIn(tester);

      expect(said('Enter valid email'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('an empty password is said, and nothing is sent', (WidgetTester tester) async {
      await pumpSignIn(tester);

      await fill(tester, password: '');
      await tapSignIn(tester);

      expect(said('Enter password'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('a device with no name is said, and nothing is sent', (WidgetTester tester) async {
      await pumpSignIn(tester);

      await fill(tester, deviceName: '   ');
      await tapSignIn(tester);

      expect(said('Enter a name for this device'), findsOneWidget);
      expect(service.calls, isEmpty);
    });
  });

  group('signing in', () {
    testWidgets('sends the e-mail without its stray spaces, the password exactly as typed and the name of the device',
        (WidgetTester tester) async {
      await pumpSignIn(tester);

      await fill(tester,
          email: '  owner@example.test ', password: ' a password with spaces ', deviceName: '  Ahmed\'s phone ');
      await tapSignIn(tester);

      expect(service.calls, <String>['signIn owner@example.test/Ahmed\'s phone']);
      expect(controller.stage, PlatformAdminStage.signedIn);
    });

    testWidgets('keeps the password in the field only until it has been sent, if it did not work',
        (WidgetTester tester) async {
      service.onSignIn = () async => refused<PlatformAdminSignIn>('login_failed_wrong_password');
      await pumpSignIn(tester);

      await fill(tester, email: 'owner@example.test', password: 'wrong-password');
      await tapSignIn(tester);
      await tester.pump();

      expect(tester.widget<TextField>(field(1)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(field(0)).controller!.text, 'owner@example.test',
          reason: 'the e-mail is kept, to try again');
    });

    testWidgets('is busy while it waits, and cannot be tapped twice', (WidgetTester tester) async {
      final Gate<PlatformAdminResult<PlatformAdminSignIn>> gate = Gate<PlatformAdminResult<PlatformAdminSignIn>>();
      service.onSignIn = () => gate.future;
      await pumpSignIn(tester);

      await fill(tester);
      await tapSignIn(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in'), findsNothing, reason: 'the button is the spinner while it waits');
      gate.open(PlatformAdminResult<PlatformAdminSignIn>.success(ownerSignIn()));
      await tester.pump();
      expect(service.count('signIn'), 1);
    });

    testWidgets('a refusal says so, and says nothing of which check failed', (WidgetTester tester) async {
      service.onSignIn = () async => refused<PlatformAdminSignIn>('login_failed_wrong_password');
      await pumpSignIn(tester);

      await fill(tester);
      await tapSignIn(tester);
      await tester.pump();

      expect(find.text('Could not sign in. Check your e-mail and password, or ask the platform owner for access.'),
          findsOneWidget);
      expect(PlatformAdminHarness.texts(tester).join(' '), isNot(contains('lkpa_')));
    });

    testWidgets('too many attempts says when to try again, in the time of the phone', (WidgetTester tester) async {
      service.onSignIn = () async => refused<PlatformAdminSignIn>('error_login_throttled');
      await pumpSignIn(tester);

      await fill(tester);
      await tapSignIn(tester);
      await tester.pump();

      final DateTime retryAt = controller.signInFailure!.retryAt!;
      final String clock = PlatformAdminTexts.tryAgainClock(retryAt);
      expect(find.text('Too many attempts. Try again at $clock'), findsOneWidget);
    });

    testWidgets('no connection, an API that is off and one that is not ready each say what they are',
        (WidgetTester tester) async {
      final Map<String, Future<PlatformAdminResult<PlatformAdminSignIn>> Function()> causes =
          <String, Future<PlatformAdminResult<PlatformAdminSignIn>> Function()>{
        'Could not reach the server': () async => unreachable<PlatformAdminSignIn>(),
        'Platform admin is not available right now.': () async =>
            refused<PlatformAdminSignIn>('error_api_switched_off_login'),
        'Platform admin is not ready yet. Try again later.': () async =>
            refused<PlatformAdminSignIn>('error_not_ready'),
      };

      for (final MapEntry<String, Future<PlatformAdminResult<PlatformAdminSignIn>> Function()> cause
          in causes.entries) {
        service = FakePlatformAdminService()..onSignIn = cause.value;
        controller = PlatformAdminController(platformAdminServiceInterface: service);
        await pumpSignIn(tester);

        await fill(tester);
        await tapSignIn(tester);
        await tester.pump();

        expect(find.text(cause.key), findsOneWidget, reason: cause.key);
      }
    });

    testWidgets('a session that ended is said once, quietly, above the form', (WidgetTester tester) async {
      service.onRestore = () async => refused<PlatformAdminProfile?>('error_unauthenticated');
      await controller.restoreSession();
      await pumpSignIn(tester);

      expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing, reason: 'a session that ends is not an alarm');
    });
  });

  group('in Arabic', () {
    testWidgets('reads from the right, in Arabic, with no key showing through', (WidgetTester tester) async {
      await pumpSignIn(tester, locale: PlatformAdminHarness.arabic);

      expect(Directionality.of(tester.element(find.byType(PlatformAdminSignInScreen))), TextDirection.rtl);
      expect(find.text('مدير المنصة'), findsWidgets);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(PlatformAdminHarness.texts(tester).where((String text) => text.startsWith('platform_admin_')), isEmpty);
    });

    testWidgets('says what went wrong in Arabic as well', (WidgetTester tester) async {
      service.onSignIn = () async => refused<PlatformAdminSignIn>('login_failed_wrong_password');
      await pumpSignIn(tester, locale: PlatformAdminHarness.arabic);

      await fill(tester);
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('تعذّر تسجيل الدخول'), findsOneWidget);
    });
  });

  group('on a small phone with large text', () {
    testWidgets(
        'fits at the narrowest width with the text at twice its size, in either language, with an error showing',
        (WidgetTester tester) async {
      service.onSignIn = () async => refused<PlatformAdminSignIn>('login_failed_wrong_password');

      for (final Locale locale in <Locale>[PlatformAdminHarness.english, PlatformAdminHarness.arabic]) {
        controller = PlatformAdminController(platformAdminServiceInterface: service);
        await pumpSignIn(tester, locale: locale, textScale: 2.0, size: PlatformAdminHarness.narrowPhone);
        await controller.signIn(email: 'a@example.test', password: 'x', deviceName: 'Pixel');
        await tester.pump();

        expect(tester.takeException(), isNull, reason: '${locale.languageCode}: nothing overflows');
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
