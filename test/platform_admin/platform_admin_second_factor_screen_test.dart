import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_second_factor_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

/// The second step of the sign-in, as an admin meets it: a code, or a recovery code, and a way back.
void main() {
  late FakePlatformAdminService service;
  late PlatformAdminController controller;
  late DateTime now;

  setUp(() {
    service = FakePlatformAdminService()
      ..onSignIn = () async => PlatformAdminResult<PlatformAdminSignInStep>.success(secondFactorWanted());
    now = DateTime.utc(2026, 11, 17, 10);
    controller = PlatformAdminController(platformAdminServiceInterface: service, now: () => now);
  });

  Future<void> pumpSecondStep(
    WidgetTester tester, {
    Locale locale = PlatformAdminHarness.english,
    double textScale = 1.0,
    Size size = PlatformAdminHarness.phone,
    bool darkTheme = false,
  }) async {
    await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');
    service.calls.clear();
    PlatformAdminHarness.useScreen(tester, size);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      home: const PlatformAdminSecondFactorScreen(),
      controller: controller,
      locale: locale,
      textScale: textScale,
      darkTheme: darkTheme,
    ));
    await tester.pump();
  }

  Finder field() => find.descendant(of: find.byType(CustomTextFieldWidget), matching: find.byType(TextField));

  TextField fieldWidget(WidgetTester tester) => tester.widget<TextField>(field());

  String typed(WidgetTester tester) => fieldWidget(tester).controller!.text;

  /// A message in the snack bar, and not a hint that says the same words.
  Finder said(String text) => find.descendant(of: find.byType(SnackBar), matching: find.text(text));

  Future<void> tapVerify(WidgetTester tester) async {
    await tester.tap(find.text('Verify'));
    await tester.pump();
  }

  Future<void> typeAndVerify(WidgetTester tester, String text) async {
    await tester.enterText(field(), text);
    await tapVerify(tester);
  }

  bool verifyIsOn(WidgetTester tester) =>
      tester.widget<CustomButtonWidget>(find.byType(CustomButtonWidget)).onTap != null;

  PlatformAdminResult<PlatformAdminSignIn> wrongCode() => refused<PlatformAdminSignIn>('mfa_failed');

  group('what it asks for', () {
    testWidgets('one code, a way to verify it, a way to use a recovery code, and a way back',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);

      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.text('Open your authenticator app and enter the 6-digit code.'), findsOneWidget);
      expect(find.byType(CustomTextFieldWidget), findsOneWidget);
      expect(find.text('6-digit code'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Use a recovery code instead'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
      expect(typed(tester), isEmpty, reason: 'nothing is prefilled');
      expect(find.byType(Checkbox), findsNothing, reason: 'nothing to remember');
    });

    testWidgets(
        'the field has a numeric keyboard, does not correct, suggest or remember, and takes no part in autofill',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);

      final TextField input = fieldWidget(tester);
      expect(input.keyboardType, TextInputType.number);
      expect(input.autocorrect, isFalse);
      expect(input.enableSuggestions, isFalse);
      expect(input.enableIMEPersonalizedLearning, isFalse);
      expect(input.autofillHints, isNull,
          reason: 'null is what keeps a field out of autofill; an empty list would not');
      expect(input.obscureText, isFalse);
      expect(input.textInputAction, TextInputAction.done);
    });

    testWidgets('and is the shared field, which is what it was for every screen that does not ask otherwise',
        (WidgetTester tester) async {
      PlatformAdminHarness.useScreen(tester, PlatformAdminHarness.phone);
      await tester.pumpWidget(await PlatformAdminHarness.app(tester,
          home: const Scaffold(body: CustomTextFieldWidget(hintText: 'Anything'))));
      await tester.pump();

      final TextField input = fieldWidget(tester);
      expect(input.autocorrect, isTrue);
      expect(input.enableSuggestions, isTrue);
      expect(input.enableIMEPersonalizedLearning, isTrue);
      expect(input.autofillHints, isNull);
    });

    testWidgets('takes digits and only digits, six of them, whatever it is given', (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await tester.enterText(field(), '12a 34-5.6 78');
      expect(typed(tester), '123456');

      await tester.enterText(field(), '١٢٣ ٤٥٦٧');
      expect(typed(tester), '123456', reason: 'the digits of an Arabic keyboard are digits');

      await tester.enterText(field(), 'abc');
      expect(typed(tester), isEmpty);
    });

    testWidgets('puts the caret after what it kept', (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await tester.enterText(field(), '12 34');

      expect(fieldWidget(tester).controller!.selection, const TextSelection.collapsed(offset: 4));
    });
  });

  group('before it asks the server', () {
    testWidgets('nothing typed is said, and nothing is sent', (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await tapVerify(tester);

      expect(said('Enter the 6-digit code'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('five digits are said, and nothing is sent, so that no try is used on a code that cannot be right',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await typeAndVerify(tester, '12345');

      expect(said('Enter the 6-digit code'), findsOneWidget);
      expect(service.calls, isEmpty);
      expect(controller.secondFactorTriesLeft, 5);
    });
  });

  group('sending a code', () {
    testWidgets('sends the six digits as a code for the challenge the password gave, and signs in',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await typeAndVerify(tester, '012 345');
      await tester.pump();

      expect(service.secondFactorAttempts.single,
          (challenge: fixtureChallenge, method: PlatformAdminMfaMethod.totp, code: '012345'));
      expect(controller.stage, PlatformAdminStage.signedIn);
    });

    testWidgets('the done key of the keyboard sends it too', (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await tester.enterText(field(), '123456');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(service.count('signInWithSecondFactor'), 1);
    });

    testWidgets('is busy while it waits, cannot be tapped twice, and cannot be left', (WidgetTester tester) async {
      await pumpSecondStep(tester);
      final Gate<PlatformAdminResult<PlatformAdminSignIn>> gate = Gate<PlatformAdminResult<PlatformAdminSignIn>>();
      service.onSignInWithSecondFactor = () => gate.future;

      await typeAndVerify(tester, '123456');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Verify'), findsNothing, reason: 'the button is the spinner while it waits');
      await tester.tap(find.text('Back to sign in'), warnIfMissed: false);
      await tester.pump();
      expect(controller.stage, PlatformAdminStage.secondFactor,
          reason: 'the code on its way would open a session nobody sees');
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Back to sign in')).onPressed, isNull);
      expect(
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Use a recovery code instead')).onPressed, isNull);
      gate.open(PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn()));
      await tester.pump();
      expect(service.count('signInWithSecondFactor'), 1);
    });

    testWidgets(
        'a wrong code says so, calmly and without saying why, and how many tries are left, and empties the field',
        (WidgetTester tester) async {
      service.onSignInWithSecondFactor = () async => wrongCode();
      await pumpSecondStep(tester);

      await typeAndVerify(tester, '123456');
      await tester.pump();

      expect(find.textContaining('That code did not work. Check it and try again.'), findsOneWidget);
      expect(find.textContaining('Tries left: 4'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing, reason: 'a wrong code is not an alarm');
      expect(typed(tester), isEmpty);
      final String everything = PlatformAdminHarness.texts(tester).join(' ').toLowerCase();
      for (final String hint in <String>['expired', 'password', 'locked', 'replay', 'used', 'challenge', 'lkpc_']) {
        expect(everything, isNot(contains(hint)), reason: hint);
      }
    });

    testWidgets('counts the tries down on the screen, and the last wrong code sends the admin back to the password',
        (WidgetTester tester) async {
      service.onSignInWithSecondFactor = () async => wrongCode();
      await pumpSecondStep(tester);

      for (final int left in <int>[4, 3, 2, 1]) {
        await typeAndVerify(tester, '123456');
        await tester.pump();
        expect(find.textContaining('Tries left: $left'), findsOneWidget);
      }
      await typeAndVerify(tester, '123456');
      await tester.pump();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.secondFactorEnd, PlatformAdminSecondFactorEnd.triesUsed);
      expect(service.count('signInWithSecondFactor'), 5);
    });

    testWidgets('no connection says so, keeps the code that was typed and every try, and sends it again when asked',
        (WidgetTester tester) async {
      service.onSignInWithSecondFactor = () async => unreachable<PlatformAdminSignIn>();
      await pumpSecondStep(tester);

      await typeAndVerify(tester, '123456');
      await tester.pump();

      expect(find.textContaining('Could not reach the server'), findsOneWidget);
      expect(find.textContaining('Tries left'), findsNothing);
      expect(typed(tester), '123456');
      expect(controller.secondFactorTriesLeft, 5);

      service.onSignInWithSecondFactor =
          () async => PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn());
      await tapVerify(tester);
      await tester.pump();
      expect(controller.stage, PlatformAdminStage.signedIn);
    });

    testWidgets(
        'too many attempts says when to try again, turns the button off, keeps the code, and turns it on when the wait is over',
        (WidgetTester tester) async {
      service.onSignInWithSecondFactor = () async => PlatformAdminResult<PlatformAdminSignIn>.failure(
          PlatformAdminFailure.fromResponse(
              statusCode: 429, body: fixture('mfa_throttled'), retryAfter: '60', now: now));
      await pumpSecondStep(tester);

      await typeAndVerify(tester, '123456');
      await tester.pump();

      final String clock = PlatformAdminTexts.tryAgainClock(now.add(const Duration(seconds: 60)));
      expect(find.textContaining('Too many attempts. Try again at $clock'), findsOneWidget);
      expect(verifyIsOn(tester), isFalse);
      expect(typed(tester), '123456');
      service.calls.clear();
      await tapVerify(tester);
      expect(service.calls, isEmpty, reason: 'a button that is off sends nothing');

      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();

      expect(verifyIsOn(tester), isTrue);
      expect(controller.stage, PlatformAdminStage.secondFactor);
    });

    testWidgets('a wait that the server did not put a time on turns nothing off', (WidgetTester tester) async {
      service.onSignInWithSecondFactor = () async => PlatformAdminResult<PlatformAdminSignIn>.failure(
          PlatformAdminFailure.fromResponse(statusCode: 429, body: fixture('mfa_throttled'), now: now));
      await pumpSecondStep(tester);

      await typeAndVerify(tester, '123456');
      await tester.pump();

      expect(find.textContaining('Too many attempts. Try again in a moment.'), findsOneWidget);
      expect(verifyIsOn(tester), isTrue);
    });
  });

  group('a challenge that runs out', () {
    testWidgets('while the screen is open ends the step by itself, when its time comes', (WidgetTester tester) async {
      await pumpSecondStep(tester);

      now = DateTime.utc(2026, 11, 17, 10, 5);
      await tester.pump(const Duration(minutes: 5));

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.secondFactorEnd, PlatformAdminSecondFactorEnd.expired);
    });

    testWidgets('is not waited for when the screen was not looking: a code typed after it is not sent',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);
      await tester.enterText(field(), '123456');

      now = DateTime.utc(2026, 11, 17, 10, 6);
      await tapVerify(tester);

      expect(service.calls, isEmpty);
      expect(controller.secondFactorEnd, PlatformAdminSecondFactorEnd.expired);
    });

    testWidgets('leaves no timer running when the screen is left first: nothing acts for a screen that is gone',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await tester.pumpWidget(const SizedBox());
      now = DateTime.utc(2026, 11, 17, 10, 10);
      await tester.pump(const Duration(minutes: 10));

      expect(tester.takeException(), isNull);
      expect(controller.stage, PlatformAdminStage.secondFactor,
          reason: 'it is the shell that decides, when it shows the screen');
      expect(controller.secondFactorEnd, isNull);
    });
  });

  group('a recovery code', () {
    Future<void> useRecoveryCode(WidgetTester tester) async {
      await tester.tap(find.text('Use a recovery code instead'));
      await tester.pump();
    }

    testWidgets(
        'is a field of its own, with a keyboard of letters, that corrects, suggests and remembers nothing either',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await useRecoveryCode(tester);

      expect(find.text('Recovery code'), findsOneWidget);
      expect(find.textContaining('Enter one of your recovery codes, like abcde-fghij.'), findsOneWidget);
      expect(find.text('Use your authenticator code instead'), findsOneWidget);
      final TextField input = fieldWidget(tester);
      expect(input.keyboardType, TextInputType.text);
      expect(input.autocorrect, isFalse);
      expect(input.enableSuggestions, isFalse);
      expect(input.enableIMEPersonalizedLearning, isFalse);
      expect(input.autofillHints, isNull);
      expect(input.obscureText, isFalse);
    });

    testWidgets('empties the field when the way is changed, in either direction', (WidgetTester tester) async {
      await pumpSecondStep(tester);
      await tester.enterText(field(), '123456');

      await useRecoveryCode(tester);
      expect(typed(tester), isEmpty);

      await tester.enterText(field(), 'abcde');
      await tester.tap(find.text('Use your authenticator code instead'));
      await tester.pump();
      expect(typed(tester), isEmpty);
      expect(find.text('6-digit code'), findsOneWidget);
    });

    testWidgets('is sent in the form the server documents, whatever case and spaces it was typed with',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);
      await useRecoveryCode(tester);

      await typeAndVerify(tester, 'ABCDE fghj2');
      await tester.pump();

      expect(service.secondFactorAttempts.single,
          (challenge: fixtureChallenge, method: PlatformAdminMfaMethod.recoveryCode, code: 'abcde-fghj2'));
    });

    testWidgets('that is short is said, and nothing is sent', (WidgetTester tester) async {
      await pumpSecondStep(tester);
      await useRecoveryCode(tester);

      await typeAndVerify(tester, 'abcde-fgh');

      expect(said('Enter your recovery code: 10 letters and numbers'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('takes only what a recovery code is written with, and no more than it can be',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);
      await useRecoveryCode(tester);

      await tester.enterText(field(), 'ab!cd_e fg*hj2xyzxyz');

      expect(typed(tester), 'abcde fghj2xyz');
    });

    testWidgets('a wrong one says the same as a wrong code, and uses a try', (WidgetTester tester) async {
      service.onSignInWithSecondFactor = () async => wrongCode();
      await pumpSecondStep(tester);
      await useRecoveryCode(tester);

      await typeAndVerify(tester, 'abcde-fghj2');
      await tester.pump();

      expect(find.textContaining('That code did not work. Check it and try again.'), findsOneWidget);
      expect(find.textContaining('Tries left: 4'), findsOneWidget);
      expect(typed(tester), isEmpty);
    });

    testWidgets('is the only way when the server takes nothing else, and no way to the other is offered',
        (WidgetTester tester) async {
      service.onSignIn = () async =>
          PlatformAdminResult<PlatformAdminSignInStep>.success(PlatformAdminSignInStep.fromJson(<String, dynamic>{
            ...fixtureData('login_mfa_required'),
            'methods': <String>['recovery_code'],
          })!);
      await pumpSecondStep(tester);

      expect(find.text('Recovery code'), findsOneWidget);
      expect(find.text('Use your authenticator code instead'), findsNothing);
      expect(find.text('Use a recovery code instead'), findsNothing);
    });

    testWidgets('and when the server takes only a code, there is no way to the recovery code',
        (WidgetTester tester) async {
      service.onSignIn = () async =>
          PlatformAdminResult<PlatformAdminSignInStep>.success(PlatformAdminSignInStep.fromJson(<String, dynamic>{
            ...fixtureData('login_mfa_required'),
            'methods': <String>['totp'],
          })!);
      await pumpSecondStep(tester);

      expect(find.text('6-digit code'), findsOneWidget);
      expect(find.text('Use a recovery code instead'), findsNothing);
    });
  });

  group('going back to the password', () {
    testWidgets('the link says what it does, forgets the challenge, and says nothing: the admin chose it',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await tester.tap(find.text('Back to sign in'));
      await tester.pump();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.secondFactorEnd, isNull);
      expect(controller.secondFactorMethods, isEmpty);
    });

    testWidgets('the back arrow of the bar does the same', (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await tester.tap(find.byIcon(Icons.arrow_back_ios));
      await tester.pump();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.secondFactorEnd, isNull);
    });

    testWidgets('and so does the back key of the phone, which does not leave the shell from here',
        (WidgetTester tester) async {
      await pumpSecondStep(tester);

      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pump();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(find.byType(PlatformAdminSecondFactorScreen), findsOneWidget,
          reason: 'the shell shows the password step; this screen only goes with it');
    });

    testWidgets('empties the field when the screen is left, whichever way it was left', (WidgetTester tester) async {
      await pumpSecondStep(tester);
      await tester.enterText(field(), '123456');
      final TextEditingController input = fieldWidget(tester).controller!;

      await tester.pumpWidget(const SizedBox());

      expect(input.text, isEmpty);
    });
  });

  group('in Arabic', () {
    testWidgets('reads from the right, in Arabic, with no key showing through', (WidgetTester tester) async {
      await pumpSecondStep(tester, locale: PlatformAdminHarness.arabic);

      expect(Directionality.of(tester.element(find.byType(PlatformAdminSecondFactorScreen))), TextDirection.rtl);
      expect(find.text('أدخل رمز التحقق'), findsOneWidget);
      expect(find.text('تحقّق'), findsOneWidget);
      expect(find.text('استخدم رمز استرداد بدلًا من ذلك'), findsOneWidget);
      expect(find.text('العودة إلى تسجيل الدخول'), findsOneWidget);
      expect(PlatformAdminHarness.texts(tester).where((String text) => text.startsWith('platform_admin_')), isEmpty);
    });

    testWidgets('takes the digits of an Arabic keyboard and sends them as the digits the server reads',
        (WidgetTester tester) async {
      await pumpSecondStep(tester, locale: PlatformAdminHarness.arabic);

      await tester.enterText(field(), '٠١٢٣٤٥');
      await tester.tap(find.text('تحقّق'));
      await tester.pump();

      expect(service.secondFactorAttempts.single.code, '012345');
    });

    testWidgets('says what went wrong in Arabic as well', (WidgetTester tester) async {
      service.onSignInWithSecondFactor = () async => wrongCode();
      await pumpSecondStep(tester, locale: PlatformAdminHarness.arabic);

      await tester.enterText(field(), '123456');
      await tester.tap(find.text('تحقّق'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('لم يعمل هذا الرمز'), findsOneWidget);
      expect(find.textContaining('المحاولات المتبقية: 4'), findsOneWidget);
    });
  });

  group('on a small phone with large text', () {
    Future<void> scrolled(WidgetTester tester, String reason) async {
      expect(tester.takeException(), isNull, reason: reason);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$reason, scrolled');
    }

    testWidgets('fits at the narrowest width with the text at twice its size, in either language, light and dark',
        (WidgetTester tester) async {
      for (final Locale locale in <Locale>[PlatformAdminHarness.english, PlatformAdminHarness.arabic]) {
        for (final bool dark in <bool>[false, true]) {
          controller = PlatformAdminController(platformAdminServiceInterface: service, now: () => now);
          await pumpSecondStep(tester,
              locale: locale, textScale: 2.0, size: PlatformAdminHarness.narrowPhone, darkTheme: dark);

          await scrolled(tester, '${locale.languageCode} dark: $dark');
        }
      }
    });

    testWidgets('and with a wrong code, with the wait, and with a recovery code showing', (WidgetTester tester) async {
      for (final Locale locale in <Locale>[PlatformAdminHarness.english, PlatformAdminHarness.arabic]) {
        service.onSignInWithSecondFactor = () async => wrongCode();
        controller = PlatformAdminController(platformAdminServiceInterface: service, now: () => now);
        await pumpSecondStep(tester, locale: locale, textScale: 2.0, size: PlatformAdminHarness.narrowPhone);
        await controller.verifySecondFactor(method: PlatformAdminMfaMethod.totp, code: '123456');
        await tester.pump();
        await scrolled(tester, '${locale.languageCode} wrong code');

        service.onSignInWithSecondFactor = () async => PlatformAdminResult<PlatformAdminSignIn>.failure(
            PlatformAdminFailure.fromResponse(
                statusCode: 429, body: fixture('mfa_throttled'), retryAfter: '600', now: now));
        await controller.verifySecondFactor(method: PlatformAdminMfaMethod.totp, code: '123456');
        await tester.pump();
        await scrolled(tester, '${locale.languageCode} waiting');

        await tester.tap(find.byType(TextButton).first);
        await tester.pump();
        await scrolled(tester, '${locale.languageCode} recovery code');
      }
    });
  });
}
