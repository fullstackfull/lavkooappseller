import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';

/// The sign-in in two steps, and ending the other sessions, as the controller keeps them.
///
/// What matters most is what is not kept: the challenge and the code are in memory for as long as the
/// step is open and in nothing the controller says about itself. And that five wrong codes, a challenge
/// that has run out and a call that never got an answer are three different things.
void main() {
  late FakePlatformAdminService service;
  late DateTime now;

  setUp(() {
    service = FakePlatformAdminService()
      ..onSignIn = () async => PlatformAdminResult<PlatformAdminSignInStep>.success(secondFactorWanted());
    now = DateTime.utc(2026, 11, 17, 10);
  });

  PlatformAdminController newController() =>
      PlatformAdminController(platformAdminServiceInterface: service, now: () => now);

  Future<PlatformAdminController> atTheSecondStep() async {
    final PlatformAdminController controller = newController();
    await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');
    service.calls.clear();
    return controller;
  }

  Future<bool> typeCode(PlatformAdminController controller, [String code = '123456']) =>
      controller.verifySecondFactor(method: PlatformAdminMfaMethod.totp, code: code);

  PlatformAdminResult<PlatformAdminSignIn> wrongCode() => refused<PlatformAdminSignIn>('mfa_failed');

  group('a password that is not enough', () {
    test('is not a sign-in: it asks for a code, and there is no session, no profile and no failure', () async {
      final PlatformAdminController controller = newController();

      final bool signedIn =
          await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');

      expect(signedIn, isFalse);
      expect(controller.stage, PlatformAdminStage.secondFactor);
      expect(controller.profile, isNull);
      expect(controller.signInFailure, isNull);
      expect(controller.sessionEnded, isFalse);
      expect(service.calls, <String>['signIn owner@example.test/Pixel 9'], reason: 'nothing of the admin is read yet');
    });

    test('offers what the server takes, and five tries', () async {
      final PlatformAdminController controller = await atTheSecondStep();

      expect(controller.secondFactorMethods, PlatformAdminMfaMethod.values.toSet());
      expect(controller.secondFactorTriesLeft, 5);
      expect(controller.isVerifyingSecondFactor, isFalse);
      expect(controller.secondFactorFailure, isNull);
      expect(controller.secondFactorWait, isNull);
      expect(controller.secondFactorEnd, isNull);
    });

    test('says when the challenge ends, as the next time the step has to look at the clock', () async {
      final PlatformAdminController controller = await atTheSecondStep();

      expect(controller.secondFactorNextCheck, const Duration(minutes: 5));
      now = now.add(const Duration(minutes: 2));
      expect(controller.secondFactorNextCheck, const Duration(minutes: 3));
    });

    test('does not say the challenge, anywhere the controller speaks of itself', () async {
      final PlatformAdminController controller = await atTheSecondStep();

      expect(controller.toString(), isNot(contains('lkpc_')));
      expect(controller.toString(), isNot(contains(fixtureChallenge)));
      expect(controller.secondFactorMethods.toString(), isNot(contains('lkpc_')));
    });
  });

  group('the second step', () {
    test(
        'opens the session with a code that is right, for the challenge the password gave, and then asks who the admin is',
        () async {
      final PlatformAdminController controller = await atTheSecondStep();

      final bool signedIn = await typeCode(controller);

      expect(signedIn, isTrue);
      expect(controller.stage, PlatformAdminStage.signedIn);
      expect(controller.profile!.adminId, 4);
      expect(service.calls, <String>['signInWithSecondFactor totp', 'profile']);
      expect(service.secondFactorAttempts.single,
          (challenge: fixtureChallenge, method: PlatformAdminMfaMethod.totp, code: '123456'));
    });

    test('leaves nothing of the step behind once the session is open', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      await typeCode(controller, '000000');
      await typeCode(controller);

      expect(controller.secondFactorMethods, isEmpty);
      expect(controller.secondFactorTriesLeft, 5);
      expect(controller.secondFactorFailure, isNull);
      expect(controller.isVerifyingSecondFactor, isFalse);
      expect(controller.secondFactorNextCheck, isNull);
    });

    test('takes a recovery code in its own way', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor =
          () async => PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn('mfa_success_recovery_code'));

      final bool signedIn =
          await controller.verifySecondFactor(method: PlatformAdminMfaMethod.recoveryCode, code: 'abcde-fghj2');

      expect(signedIn, isTrue);
      expect(service.secondFactorAttempts.single.method, PlatformAdminMfaMethod.recoveryCode);
      expect(service.secondFactorAttempts.single.code, 'abcde-fghj2');
    });

    test('is busy while it waits for the answer, and a second tap is ignored', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      final Gate<PlatformAdminResult<PlatformAdminSignIn>> gate = Gate<PlatformAdminResult<PlatformAdminSignIn>>();
      service.onSignInWithSecondFactor = () => gate.future;

      final Future<bool> first = typeCode(controller);
      final bool second = await typeCode(controller);

      expect(second, isFalse);
      expect(controller.isVerifyingSecondFactor, isTrue);
      gate.open(PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn()));
      expect(await first, isTrue);
      expect(service.count('signInWithSecondFactor'), 1);
    });

    test('is busy until the admin is read too, so that the screen does not look idle while it waits', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      final Gate<PlatformAdminResult<PlatformAdminProfile>> gate = Gate<PlatformAdminResult<PlatformAdminProfile>>();
      service.onProfile = () => gate.future;

      final Future<bool> signingIn = typeCode(controller);
      await Future<void>.delayed(Duration.zero);

      expect(controller.stage, PlatformAdminStage.secondFactor);
      expect(controller.isVerifyingSecondFactor, isTrue);
      gate.open(PlatformAdminResult<PlatformAdminProfile>.success(ownerProfile()));
      expect(await signingIn, isTrue);
    });

    test('does nothing when no second step is open', () async {
      final PlatformAdminController controller = newController();

      expect(await typeCode(controller), isFalse);
      expect(service.calls, isEmpty);

      service.onSignIn =
          () async => PlatformAdminResult<PlatformAdminSignInStep>.success(PlatformAdminSessionOpened(ownerSignIn()));
      await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');
      service.calls.clear();

      expect(await typeCode(controller), isFalse, reason: 'signed in, not asked for a code');
      expect(service.calls, isEmpty);
    });
  });

  group('a code that is wrong', () {
    test('says so without saying why, uses one try and leaves the admin where they are', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor = () async => wrongCode();

      final bool signedIn = await typeCode(controller);

      expect(signedIn, isFalse);
      expect(controller.stage, PlatformAdminStage.secondFactor);
      expect(controller.secondFactorFailure!.kind, PlatformAdminFailureKind.unauthenticated);
      expect(controller.secondFactorTriesLeft, 4);
      expect(controller.isVerifyingSecondFactor, isFalse);
      expect(controller.sessionEnded, isFalse, reason: 'a wrong code is not a session that ended');
      expect(controller.signInFailure, isNull);
    });

    test(
        'counts every refusal, and the fifth sends the admin back to the password, with the reason, and with nothing kept',
        () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor = () async => wrongCode();

      for (final int left in <int>[4, 3, 2, 1]) {
        await typeCode(controller);
        expect(controller.secondFactorTriesLeft, left);
        expect(controller.stage, PlatformAdminStage.secondFactor);
      }
      await typeCode(controller);

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.secondFactorEnd, PlatformAdminSecondFactorEnd.triesUsed);
      expect(controller.secondFactorMethods, isEmpty);
      expect(controller.secondFactorFailure, isNull);
      expect(controller.signInFailure, isNull);
      expect(controller.sessionEnded, isFalse);
      expect(service.count('signInWithSecondFactor'), 5, reason: 'not a sixth: the challenge is gone');
      expect(await typeCode(controller), isFalse);
      expect(service.count('signInWithSecondFactor'), 5);
    });

    test('and then a code that is right still opens the session', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor = () async => wrongCode();
      for (int attempt = 0; attempt < 4; attempt++) {
        await typeCode(controller);
      }

      service.onSignInWithSecondFactor =
          () async => PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn());
      final bool signedIn = await typeCode(controller);

      expect(signedIn, isTrue);
      expect(controller.stage, PlatformAdminStage.signedIn);
    });

    test('a new try clears the last failure while it waits', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor = () async => wrongCode();
      await typeCode(controller);
      final Gate<PlatformAdminResult<PlatformAdminSignIn>> gate = Gate<PlatformAdminResult<PlatformAdminSignIn>>();
      service.onSignInWithSecondFactor = () => gate.future;

      final Future<bool> pending = typeCode(controller);

      expect(controller.secondFactorFailure, isNull);
      gate.open(wrongCode());
      await pending;
    });
  });

  group('a call that did not count', () {
    test('no connection keeps the challenge and every try, and the code can be sent again', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor = () async => unreachable<PlatformAdminSignIn>();

      await typeCode(controller);

      expect(controller.stage, PlatformAdminStage.secondFactor);
      expect(controller.secondFactorFailure!.kind, PlatformAdminFailureKind.network);
      expect(controller.secondFactorTriesLeft, 5);
      expect(controller.secondFactorMethods, isNotEmpty);

      service.onSignInWithSecondFactor =
          () async => PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn());
      expect(await typeCode(controller), isTrue);
      expect(service.secondFactorAttempts.map((attempt) => attempt.challenge).toSet(), <String>{fixtureChallenge});
    });

    test('an API that is not ready, switched off or failing keeps every try too', () async {
      for (final String fixtureName in <String>['error_not_ready', 'error_api_switched_off']) {
        final PlatformAdminController controller = await atTheSecondStep();
        service.onSignInWithSecondFactor = () async => refused<PlatformAdminSignIn>(fixtureName);

        await typeCode(controller);

        expect(controller.secondFactorTriesLeft, 5, reason: fixtureName);
        expect(controller.stage, PlatformAdminStage.secondFactor, reason: fixtureName);
        expect(controller.secondFactorFailure, isNotNull, reason: fixtureName);
      }
    });

    test('an answer that is not what the contract says keeps every try', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor =
          () async => const PlatformAdminResult<PlatformAdminSignIn>.failure(PlatformAdminFailure.malformed());

      await typeCode(controller);

      expect(controller.secondFactorTriesLeft, 5);
      expect(controller.secondFactorFailure!.kind, PlatformAdminFailureKind.malformed);
    });
  });

  group('too many attempts', () {
    PlatformAdminResult<PlatformAdminSignIn> throttled() => refused<PlatformAdminSignIn>('mfa_throttled', now: now);

    test('says how long to wait, from the time the server named, and uses no try', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor = () async => throttled();

      await typeCode(controller);

      expect(controller.secondFactorFailure!.kind, PlatformAdminFailureKind.throttled);
      expect(controller.secondFactorWait, const Duration(minutes: 14));
      expect(controller.secondFactorTriesLeft, 5);
      expect(controller.stage, PlatformAdminStage.secondFactor);
    });

    test('sends nothing while the wait lasts, and is allowed to again when it is over', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor = () async => throttled();
      await typeCode(controller);
      service.calls.clear();

      expect(await typeCode(controller), isFalse);
      now = now.add(const Duration(minutes: 13, seconds: 59));
      expect(await typeCode(controller), isFalse);
      expect(service.calls, isEmpty);

      now = now.add(const Duration(seconds: 1));
      service.onSignInWithSecondFactor =
          () async => PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn());
      expect(controller.secondFactorWait, isNull);
      expect(await typeCode(controller), isFalse,
          reason: 'the challenge of five minutes ended long before the wait did');
      expect(controller.secondFactorEnd, PlatformAdminSecondFactorEnd.expired);
    });

    test('with a wait shorter than the challenge, the next try goes through', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor =
          () async => PlatformAdminResult<PlatformAdminSignIn>.failure(PlatformAdminFailure.fromResponse(
                statusCode: 429,
                body: fixture('mfa_throttled'),
                retryAfter: '60',
                now: now,
              ));
      await typeCode(controller);
      expect(controller.secondFactorNextCheck, const Duration(minutes: 1),
          reason: 'the wait ends before the challenge');

      now = now.add(const Duration(minutes: 1));
      service.onSignInWithSecondFactor =
          () async => PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn());

      expect(await typeCode(controller), isTrue);
    });

    test('with no time named, there is no wait to show and the code can be sent again', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor = () async => PlatformAdminResult<PlatformAdminSignIn>.failure(
          PlatformAdminFailure.fromResponse(statusCode: 429, body: fixture('mfa_throttled'), now: now));

      await typeCode(controller);

      expect(controller.secondFactorFailure!.kind, PlatformAdminFailureKind.throttled);
      expect(controller.secondFactorWait, isNull);
      expect(controller.secondFactorTriesLeft, 5);
      await typeCode(controller);
      expect(service.count('signInWithSecondFactor'), 2);
    });

    test('a wait is not carried over to the next failure', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor = () async => PlatformAdminResult<PlatformAdminSignIn>.failure(
          PlatformAdminFailure.fromResponse(
              statusCode: 429, body: fixture('mfa_throttled'), retryAfter: '5', now: now));
      await typeCode(controller);
      now = now.add(const Duration(seconds: 5));
      service.onSignInWithSecondFactor = () async => wrongCode();

      await typeCode(controller);

      expect(controller.secondFactorWait, isNull);
      expect(controller.secondFactorTriesLeft, 4);
    });
  });

  group('a challenge that has run out', () {
    test('is not sent a code: the server would refuse it, and it would use a try', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      now = DateTime.utc(2026, 11, 17, 10, 5);

      final bool signedIn = await typeCode(controller);

      expect(signedIn, isFalse);
      expect(service.calls, isEmpty);
      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.secondFactorEnd, PlatformAdminSecondFactorEnd.expired);
      expect(controller.secondFactorMethods, isEmpty);
    });

    test('is taken for over by the screen when its time comes, and not before', () async {
      final PlatformAdminController controller = await atTheSecondStep();

      now = DateTime.utc(2026, 11, 17, 10, 4, 59);
      controller.expireSecondFactorIfOver();
      expect(controller.stage, PlatformAdminStage.secondFactor);

      now = DateTime.utc(2026, 11, 17, 10, 5);
      controller.expireSecondFactorIfOver();
      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.secondFactorEnd, PlatformAdminSecondFactorEnd.expired);
    });

    test('is left to the answer while a code is on its way', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      final Gate<PlatformAdminResult<PlatformAdminSignIn>> gate = Gate<PlatformAdminResult<PlatformAdminSignIn>>();
      service.onSignInWithSecondFactor = () => gate.future;
      final Future<bool> pending = typeCode(controller);

      now = DateTime.utc(2026, 11, 17, 10, 6);
      controller.expireSecondFactorIfOver();

      expect(controller.stage, PlatformAdminStage.secondFactor);
      gate.open(PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn()));
      expect(await pending, isTrue);
    });

    test('is nothing to expire when the server does not say when it ends', () async {
      final PlatformAdminController controller = newController();
      service.onSignIn = () async => PlatformAdminResult<PlatformAdminSignInStep>.success(
          PlatformAdminSignInStep.fromJson(<String, dynamic>{'mfa_required': true, 'challenge': 'lkpc_x'})!);
      await controller.signIn(email: 'a@example.test', password: 'x', deviceName: 'Pixel');
      now = DateTime.utc(2030);

      controller.expireSecondFactorIfOver();

      expect(controller.stage, PlatformAdminStage.secondFactor);
      expect(controller.secondFactorNextCheck, isNull);
    });
  });

  group('going back to the password', () {
    test('forgets the challenge, and says nothing, because the admin chose it', () async {
      final PlatformAdminController controller = await atTheSecondStep();

      controller.cancelSecondFactor();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.secondFactorEnd, isNull);
      expect(controller.secondFactorMethods, isEmpty);
      expect(await typeCode(controller), isFalse);
      expect(service.calls, isEmpty);
    });

    test('is not possible while a code is on its way, whose answer would open a session nobody looks at', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      final Gate<PlatformAdminResult<PlatformAdminSignIn>> gate = Gate<PlatformAdminResult<PlatformAdminSignIn>>();
      service.onSignInWithSecondFactor = () => gate.future;
      final Future<bool> pending = typeCode(controller);

      controller.cancelSecondFactor();

      expect(controller.stage, PlatformAdminStage.secondFactor);
      gate.open(PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn()));
      expect(await pending, isTrue);
    });

    test('asks for a new challenge at the next password, and the five tries start again', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor = () async => wrongCode();
      await typeCode(controller);
      controller.cancelSecondFactor();

      await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');

      expect(controller.stage, PlatformAdminStage.secondFactor);
      expect(controller.secondFactorTriesLeft, 5);
      expect(controller.secondFactorFailure, isNull);
    });

    test('is nothing to do when no step is open', () async {
      final PlatformAdminController controller = newController();
      await controller.restoreSession();

      controller.cancelSecondFactor();

      expect(controller.stage, PlatformAdminStage.signedOut);
    });

    test('a new sign-in forgets why the last second step ended', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      now = DateTime.utc(2026, 11, 17, 10, 5);
      await typeCode(controller);
      expect(controller.secondFactorEnd, isNotNull);

      await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');

      expect(controller.secondFactorEnd, isNull);
    });
  });

  group('once the session is open', () {
    test(
        'what the admin may do is read from the API before anything is shown, not taken from the answer that opened it',
        () async {
      final PlatformAdminController controller = await atTheSecondStep();
      final Gate<PlatformAdminResult<PlatformAdminProfile>> gate = Gate<PlatformAdminResult<PlatformAdminProfile>>();
      service.onProfile = () => gate.future;

      final Future<bool> opening = typeCode(controller);
      await Future<void>.delayed(Duration.zero);

      expect(controller.stage, isNot(PlatformAdminStage.signedIn));
      expect(controller.profile, isNull);
      gate.open(PlatformAdminResult<PlatformAdminProfile>.success(
          PlatformAdminProfile.fromJson(fixtureData('me_restricted_capabilities'))));
      await opening;

      expect(controller.stage, PlatformAdminStage.signedIn);
      expect(controller.profile!.adminId, 5, reason: 'who GET /me says, not who the sign-in answer said');
    });

    test('a profile that cannot be read leaves the session open, and the shell can ask again from what it kept',
        () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onProfile = () async => unreachable<PlatformAdminProfile>();

      final bool signedIn = await typeCode(controller);

      expect(signedIn, isFalse);
      expect(controller.stage, PlatformAdminStage.restoreFailed);
      expect(controller.restoreFailure!.kind, PlatformAdminFailureKind.network);
      expect(controller.sessionEnded, isFalse);
      expect(service.calls, isNot(contains('signOut')), reason: 'the session is open and is kept');

      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await controller.restoreSession();
      expect(controller.stage, PlatformAdminStage.signedIn);
    });

    test('a session that is refused at once is over, and says so, once', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onProfile = () async => refused<PlatformAdminProfile>('error_unauthenticated');

      final bool signedIn = await typeCode(controller);

      expect(signedIn, isFalse);
      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isTrue);
      expect(controller.secondFactorMethods, isEmpty);
    });

    test('the sign-in of a server that wants no second factor reads the admin too', () async {
      final PlatformAdminController controller = newController();
      service.onSignIn =
          () async => PlatformAdminResult<PlatformAdminSignInStep>.success(PlatformAdminSessionOpened(ownerSignIn()));

      final bool signedIn =
          await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');

      expect(signedIn, isTrue);
      expect(service.calls.last, 'profile');
    });

    test('leaving the shell while a code is on its way asks for nothing more', () async {
      final PlatformAdminController controller = await atTheSecondStep();
      final Gate<PlatformAdminResult<PlatformAdminSignIn>> gate = Gate<PlatformAdminResult<PlatformAdminSignIn>>();
      service.onSignInWithSecondFactor = () => gate.future;
      final Future<bool> pending = typeCode(controller);

      controller.dispose();
      gate.open(PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn()));

      expect(await pending, isFalse);
      expect(service.calls, <String>['signInWithSecondFactor totp'], reason: 'the admin is not read for nobody');
    });

    test('signing out forgets a step that was open, and a controller that goes forgets it too', () async {
      final PlatformAdminController controller = await atTheSecondStep();

      await controller.signOut();

      expect(controller.secondFactorMethods, isEmpty);
      expect(controller.stage, PlatformAdminStage.signedOut);

      final PlatformAdminController other = await atTheSecondStep();
      other.dispose();
      expect(other.secondFactorMethods, isEmpty);
    });
  });

  group('recovery codes', () {
    Future<PlatformAdminController> signedInWith(String fixtureName, {PlatformAdminMfaMethod? method}) async {
      final PlatformAdminController controller = await atTheSecondStep();
      service.onSignInWithSecondFactor =
          () async => PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn(fixtureName));
      await controller.verifySecondFactor(method: method ?? PlatformAdminMfaMethod.totp, code: '123456');
      return controller;
    }

    test('two left is a warning, whichever way the admin signed in', () async {
      expect(
          (await signedInWith('mfa_success_recovery_code', method: PlatformAdminMfaMethod.recoveryCode))
              .recoveryCodesWarning,
          2);
      expect((await signedInWith('mfa_success_recovery_code')).recoveryCodesWarning, 2);
    });

    test('none left is a warning too, and says none and not nothing', () async {
      expect((await signedInWith('mfa_success_recovery_code_none_left')).recoveryCodesWarning, 0);
    });

    test('three or more is no warning, and a server that does not say has none to give', () async {
      expect((await signedInWith('mfa_success_totp')).recoveryCodesWarning, isNull);

      final PlatformAdminController oneStep = newController();
      service.onSignIn =
          () async => PlatformAdminResult<PlatformAdminSignInStep>.success(PlatformAdminSessionOpened(ownerSignIn()));
      await oneStep.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');
      expect(oneStep.recoveryCodesWarning, isNull);
    });

    test('is put away when the admin says so, and does not come back by itself', () async {
      final PlatformAdminController controller = await signedInWith('mfa_success_recovery_code');
      int heard = 0;
      controller.addListener(() => heard++);

      controller.dismissRecoveryWarning();
      controller.dismissRecoveryWarning();

      expect(controller.recoveryCodesWarning, isNull);
      expect(heard, 1);
      await controller.loadOverview();
      expect(controller.recoveryCodesWarning, isNull);
    });

    test('is over with the session: the next sign-in is told the truth again', () async {
      final PlatformAdminController controller = await signedInWith('mfa_success_recovery_code');
      controller.dismissRecoveryWarning();
      await controller.signOut();

      expect(controller.recoveryCodesWarning, isNull);
      service.onSignIn = () async => PlatformAdminResult<PlatformAdminSignInStep>.success(secondFactorWanted());
      await controller.signIn(email: 'owner@example.test', password: 'a-password', deviceName: 'Pixel 9');
      service.onSignInWithSecondFactor =
          () async => PlatformAdminResult<PlatformAdminSignIn>.success(secondFactorSignIn('mfa_success_recovery_code'));
      await controller.verifySecondFactor(method: PlatformAdminMfaMethod.totp, code: '123456');

      expect(controller.recoveryCodesWarning, 2);
    });
  });

  group('ending the other sessions', () {
    Future<PlatformAdminController> signedIn() async {
      final PlatformAdminController controller = newController();
      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await controller.restoreSession();
      await controller.loadSessions();
      service.calls.clear();
      return controller;
    }

    test('asks once, says how many were ended, and reads the list again', () async {
      final PlatformAdminController controller = await signedIn();

      final PlatformAdminResult<int>? result = await controller.endOtherSessions();

      expect(result!.value, 2);
      expect(service.calls, <String>['endOtherSessions', 'sessions']);
      expect(controller.isEndingOtherSessions, isFalse);
    });

    test('is busy while it asks, and shuts out every other way of ending a session until it is over', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<int>> gate = Gate<PlatformAdminResult<int>>();
      service.onEndOtherSessions = () => gate.future;

      final Future<PlatformAdminResult<int>?> first = controller.endOtherSessions();

      expect(controller.isEndingOtherSessions, isTrue);
      expect(await controller.endOtherSessions(), isNull);
      expect(await controller.endSession(5), isNull);
      expect(service.count('endSession'), 0);
      gate.open(const PlatformAdminResult<int>.success(1));
      expect((await first)!.value, 1);
      expect(controller.isEndingOtherSessions, isFalse);
    });

    test('and while one session is being ended, the others cannot be', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<int>> gate = Gate<PlatformAdminResult<int>>();
      service.onEndSession = (int id) => gate.future;

      final Future<PlatformAdminFailure?> ending = controller.endSession(5);

      expect(await controller.endOtherSessions(), isNull);
      gate.open(const PlatformAdminResult<int>.success(5));
      await ending;
    });

    test('none to end is a success with zero, and the list is read again', () async {
      final PlatformAdminController controller = await signedIn();
      service.onEndOtherSessions = () async => const PlatformAdminResult<int>.success(0);

      final PlatformAdminResult<int>? result = await controller.endOtherSessions();

      expect(result!.isSuccess, isTrue);
      expect(result.value, 0);
      expect(service.count('sessions'), 1);
    });

    test('a call that gets no answer says why, leaves the list as it was and can be asked again', () async {
      final PlatformAdminController controller = await signedIn();
      final List<PlatformSessionModel> before = controller.sessions!;
      service.onEndOtherSessions = () async => unreachable<int>();

      final PlatformAdminResult<int>? result = await controller.endOtherSessions();

      expect(result!.failure!.kind, PlatformAdminFailureKind.network);
      expect(service.count('sessions'), 0);
      expect(identical(controller.sessions, before), isTrue);
      expect(controller.isEndingOtherSessions, isFalse);
      expect((await controller.endOtherSessions()), isNotNull);
    });

    test('a refusal of the session ends the session, once, with the note, and reads nothing again', () async {
      final PlatformAdminController controller = await signedIn();
      service.onEndOtherSessions = () async => refused<int>('error_unauthenticated');

      await controller.endOtherSessions();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isTrue);
      expect(controller.sessions, isNull);
      expect(service.count('sessions'), 0);
    });

    test('an answer that comes after the admin signed out is not acted on', () async {
      final PlatformAdminController controller = await signedIn();
      final Gate<PlatformAdminResult<int>> gate = Gate<PlatformAdminResult<int>>();
      service.onEndOtherSessions = () => gate.future;
      final Future<PlatformAdminResult<int>?> pending = controller.endOtherSessions();

      await controller.signOut();
      gate.open(const PlatformAdminResult<int>.success(3));
      await pending;

      expect(service.count('sessions'), 0, reason: 'nothing is read for a session that is over');
      expect(controller.isEndingOtherSessions, isFalse);
      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isFalse);
    });

    test('is not asked of the server when nobody is signed in', () async {
      final PlatformAdminController controller = newController();

      expect(await controller.endOtherSessions(), isNull);
      expect(service.calls, isEmpty);
    });
  });
}
