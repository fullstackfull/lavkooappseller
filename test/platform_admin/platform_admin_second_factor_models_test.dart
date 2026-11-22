import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_capability_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';

import 'support/fixtures.dart';

/// The shapes of the second factor, of the capabilities and of the grant's end, read from the
/// contract (`GCC-20-PLATFORM-ADMIN-API.md`, delivery 2). The bodies are written by hand from it,
/// see `support/fixtures.dart`.
void main() {
  group('the fixtures of this contract', () {
    test('say where they come from, and every one that says so is there', () {
      final List<String> handWritten = fixtureNames().where((String name) => fixtureSource(name) != null).toList();

      expect(handWritten, hasLength(14));
      for (final String name in handWritten) {
        expect(fixtureSource(name), contains('GCC-20-PLATFORM-ADMIN-API.md'), reason: name);
        expect(rawFixture(name), isNotEmpty, reason: name);
      }
    });

    test('the recorded ones are untouched: none of them says it was written by hand', () {
      expect(fixtureSource('login_success'), isNull);
      expect(fixtureSource('me_owner'), isNull);
      expect(fixtureSource('sessions_owner'), isNull);
    });
  });

  group('the capabilities of a grant', () {
    test('are the parts of the API the server lists, and only those', () {
      final PlatformAdminProfile viewer = PlatformAdminProfile.fromJson(fixtureData('me_restricted_capabilities'));

      expect(viewer.capabilities, <PlatformCapability>{PlatformCapability.overview, PlatformCapability.alerts});
      expect(viewer.can(PlatformCapability.overview), isTrue);
      expect(viewer.can(PlatformCapability.alerts), isTrue);
      expect(viewer.can(PlatformCapability.markets), isFalse);
      expect(viewer.can(PlatformCapability.audit), isFalse);
      expect(viewer.can(PlatformCapability.sessions), isFalse);
    });

    test('of the platform owner are all five', () {
      final PlatformAdminProfile owner = PlatformAdminProfile.fromJson(fixtureData('me_with_capabilities'));

      expect(owner.capabilities, PlatformCapability.values.toSet());
      expect(PlatformCapability.values.map((PlatformCapability capability) => capability.name),
          <String>['overview', 'markets', 'alerts', 'audit', 'sessions'],
          reason: 'the names are the ones the server uses, in its order');
    });

    test('of a server that sends none are all five, so that an older server loses nothing', () {
      final PlatformAdminProfile older = PlatformAdminProfile.fromJson(fixtureData('me_owner'));

      expect(older.capabilities, PlatformCapability.values.toSet());
      expect(older.grantExpiresAt, isNull);
      expect(older.mfa, isNull, reason: 'a server that says nothing of the second factor has not said');
    });

    test('that are a list with a name the app has never heard of ignore that name', () {
      final PlatformAdminProfile viewer = PlatformAdminProfile.fromJson(<String, dynamic>{
        'admin_id': 5,
        'capabilities': <Object?>['overview', 'exports', 7, null, 'alerts', 'overview'],
      });

      expect(viewer.capabilities, <PlatformCapability>{PlatformCapability.overview, PlatformCapability.alerts});
    });

    test('that are an empty list are none, and not all', () {
      final PlatformAdminProfile viewer =
          PlatformAdminProfile.fromJson(<String, dynamic>{'admin_id': 5, 'capabilities': <Object?>[]});

      expect(viewer.capabilities, isEmpty);
      expect(PlatformCapability.values.any(viewer.can), isFalse);
    });

    test('that are not a list are none, the way the server reads a value it cannot read, and never all', () {
      for (final Object? unreadable in <Object?>[
        'overview',
        7,
        true,
        <String, dynamic>{'overview': true}
      ]) {
        final PlatformAdminProfile viewer =
            PlatformAdminProfile.fromJson(<String, dynamic>{'admin_id': 5, 'capabilities': unreadable});

        expect(viewer.capabilities, isEmpty, reason: '$unreadable');
      }
    });

    test('are not widened by the scope: the owner is not given a part the list leaves out', () {
      final PlatformAdminProfile owner = PlatformAdminProfile.fromJson(<String, dynamic>{
        'admin_id': 7,
        'scope': 'all',
        'capabilities': <Object?>['alerts'],
      });

      expect(owner.scope, PlatformScope.all);
      expect(owner.can(PlatformCapability.overview), isFalse);
    });

    test('parse by the name the server uses, and nothing else', () {
      expect(PlatformCapability.parse('audit'), PlatformCapability.audit);
      expect(PlatformCapability.parse('Audit'), isNull);
      expect(PlatformCapability.parse(null), isNull);
      expect(PlatformCapability.parse(3), isNull);
    });
  });

  group('the end of a grant', () {
    test('is a moment in UTC when the grant has one', () {
      final PlatformAdminProfile viewer = PlatformAdminProfile.fromJson(fixtureData('me_restricted_capabilities'));

      expect(viewer.grantExpiresAt, DateTime.utc(2027, 3, 31, 20, 59, 59));
    });

    test('is none for a grant with no end, which is not a date in 1970', () {
      final PlatformAdminProfile owner = PlatformAdminProfile.fromJson(fixtureData('me_with_capabilities'));

      expect(owner.grantExpiresAt, isNull);
    });

    test('is none when what the server wrote is not a moment, and never a guess', () {
      for (final Object? unreadable in <Object?>['soon', 17, '', true]) {
        final PlatformAdminProfile viewer =
            PlatformAdminProfile.fromJson(<String, dynamic>{'admin_id': 5, 'grant_expires_at': unreadable});

        expect(viewer.grantExpiresAt, isNull, reason: '$unreadable');
      }
    });
  });

  group('what GET /me says of the second factor', () {
    test('is whether the admin has a factor, whether this session passed it, and how', () {
      final PlatformAdminMfaStatus? owner = PlatformAdminProfile.fromJson(fixtureData('me_with_capabilities')).mfa;
      final PlatformAdminMfaStatus? viewer =
          PlatformAdminProfile.fromJson(fixtureData('me_restricted_capabilities')).mfa;

      expect(owner!.enrolled, isTrue);
      expect(owner.verified, isTrue);
      expect(owner.method, PlatformAdminMfaMethod.totp);
      expect(viewer!.method, PlatformAdminMfaMethod.recoveryCode);
    });

    test('of a session opened while no factor was required has no method', () {
      final PlatformAdminMfaStatus? status =
          PlatformAdminMfaStatus.fromJson(<String, dynamic>{'enrolled': true, 'verified': false, 'method': null});

      expect(status!.verified, isFalse);
      expect(status.method, isNull);
    });

    test('is unknown, and not "not verified", when the server says nothing or something that is not an object', () {
      expect(PlatformAdminMfaStatus.fromJson(null), isNull);
      expect(PlatformAdminMfaStatus.fromJson('totp'), isNull);
      expect(PlatformAdminMfaStatus.fromJson(<Object?>[]), isNull);
    });

    test('a method the app has never heard of is no method, and a missing flag is off', () {
      final PlatformAdminMfaStatus? status = PlatformAdminMfaStatus.fromJson(<String, dynamic>{'method': 'passkey'});

      expect(status!.method, isNull);
      expect(status.enrolled, isFalse);
      expect(status.verified, isFalse);
    });
  });

  group('the answer of the password step', () {
    test('that asks for a code carries a challenge, when it ends and what the server takes', () {
      final PlatformAdminSignInStep? step = PlatformAdminSignInStep.fromJson(fixtureData('login_mfa_required'));

      final PlatformAdminMfaChallenge challenge = (step! as PlatformAdminSecondFactorWanted).challenge;
      expect(challenge.value, fixtureChallenge);
      expect(challenge.expiresAt, DateTime.utc(2026, 11, 17, 10, 5));
      expect(challenge.methods, PlatformAdminMfaMethod.values.toSet());
    });

    test('that opens a session is the sign-in of level 1, as it always was', () {
      final PlatformAdminSignInStep? step = PlatformAdminSignInStep.fromJson(fixtureData('login_success'));

      final PlatformAdminSignIn signIn = (step! as PlatformAdminSessionOpened).signIn;
      expect(signIn.token, fixtureToken);
      expect(signIn.profile.adminId, 4);
      expect(signIn.recoveryCodesLeft, isNull);
    });

    test('is told apart by mfa_required alone: present and true is a code wanted, absent or false is a session', () {
      final Map<String, dynamic> session = fixtureData('login_success');

      expect(PlatformAdminSignInStep.fromJson(<String, dynamic>{...session, 'mfa_required': false}),
          isA<PlatformAdminSessionOpened>());
      expect(PlatformAdminSignInStep.fromJson(<String, dynamic>{...session, 'mfa_required': 'true'}),
          isA<PlatformAdminSessionOpened>(),
          reason: 'only a real true asks for a code');
    });

    test('that asks for a code and has a token is a code wanted, and the token is never used', () {
      final PlatformAdminSignInStep? step = PlatformAdminSignInStep.fromJson(
          <String, dynamic>{...fixtureData('login_success'), ...fixtureData('login_mfa_required')});

      expect(step, isA<PlatformAdminSecondFactorWanted>());
    });

    test('that asks for a code and has no challenge to use is nothing the app can go on with', () {
      expect(PlatformAdminSignInStep.fromJson(<String, dynamic>{'mfa_required': true}), isNull);
      expect(PlatformAdminSignInStep.fromJson(<String, dynamic>{'mfa_required': true, 'challenge': ''}), isNull);
      expect(PlatformAdminSignInStep.fromJson(<String, dynamic>{'mfa_required': true, 'challenge': 7}), isNull);
    });
  });

  group('a challenge', () {
    PlatformAdminMfaChallenge challengeOf(Map<String, dynamic> extra) =>
        PlatformAdminMfaChallenge.fromJson(<String, dynamic>{'challenge': 'lkpc_x', ...extra})!;

    test('offers both ways when the server does not say, and what it says when it does', () {
      expect(challengeOf(<String, dynamic>{}).methods, PlatformAdminMfaMethod.values.toSet());
      expect(
          challengeOf(<String, dynamic>{
            'methods': <Object?>['totp']
          }).methods,
          <PlatformAdminMfaMethod>{PlatformAdminMfaMethod.totp});
      expect(
          challengeOf(<String, dynamic>{
            'methods': <Object?>['recovery_code', 'sms']
          }).methods,
          <PlatformAdminMfaMethod>{PlatformAdminMfaMethod.recoveryCode});
    });

    test('offers both ways when the server lists only ways the app has never heard of', () {
      expect(
          challengeOf(<String, dynamic>{
            'methods': <Object?>['sms']
          }).methods,
          PlatformAdminMfaMethod.values.toSet());
      expect(challengeOf(<String, dynamic>{'methods': 'totp'}).methods, PlatformAdminMfaMethod.values.toSet());
    });

    test('is over at the moment it ends and not a moment before', () {
      final PlatformAdminMfaChallenge challenge =
          challengeOf(<String, dynamic>{'challenge_expires_at': '2026-11-17T10:05:00Z'});

      expect(challenge.isOver(DateTime.utc(2026, 11, 17, 10, 4, 59)), isFalse);
      expect(challenge.isOver(DateTime.utc(2026, 11, 17, 10, 5)), isTrue);
      expect(challenge.isOver(DateTime.utc(2026, 11, 17, 10, 6)), isTrue);
    });

    test('is not known to be over when the server does not say when it ends', () {
      expect(challengeOf(<String, dynamic>{}).expiresAt, isNull);
      expect(challengeOf(<String, dynamic>{}).isOver(DateTime.utc(2030)), isFalse);
      expect(challengeOf(<String, dynamic>{'challenge_expires_at': 'soon'}).isOver(DateTime.utc(2030)), isFalse);
    });

    test('can be held without its end, which keeps what the server said about everything else', () {
      final PlatformAdminMfaChallenge challenge = challengeOf(<String, dynamic>{
        'challenge_expires_at': '2026-11-17T10:05:00Z',
        'methods': <Object?>['totp'],
      });

      final PlatformAdminMfaChallenge open = challenge.withoutEnd();

      expect(open.value, challenge.value);
      expect(open.methods, challenge.methods);
      expect(open.expiresAt, isNull);
      expect(open.isOver(DateTime.utc(2030)), isFalse);
    });

    test('allows five wrong codes, which is what the server allows unless it is told otherwise', () {
      expect(PlatformAdminMfaChallenge.maxTries, 5);
    });

    test('is a secret, and nothing that prints it prints it', () {
      final PlatformAdminMfaChallenge challenge = challengeOf(<String, dynamic>{'challenge': fixtureChallenge});

      expect(challenge.toString(), isNot(contains('lkpc_')));
      expect('$challenge', isNot(contains(fixtureChallenge)));
    });
  });

  group('the answer of the second step', () {
    test('is the sign-in of level 1 with how many recovery codes are left', () {
      final PlatformAdminSignIn totp = PlatformAdminSignIn.fromJson(fixtureData('mfa_success_totp'));
      final PlatformAdminSignIn recovery = PlatformAdminSignIn.fromJson(fixtureData('mfa_success_recovery_code'));

      expect(totp.token, fixtureToken);
      expect(totp.expiresAt, DateTime.utc(2026, 11, 17, 18));
      expect(totp.profile.adminId, 4);
      expect(totp.recoveryCodesLeft, 10);
      expect(recovery.recoveryCodesLeft, 2);
    });

    test('says when the last recovery code was used, which is zero and not nothing', () {
      expect(PlatformAdminSignIn.fromJson(fixtureData('mfa_success_recovery_code_none_left')).recoveryCodesLeft, 0);
    });

    test('says nothing of recovery codes when the server does not, and when what it says cannot be a count', () {
      final Map<String, dynamic> body = fixtureData('mfa_success_totp');

      for (final Object? unreadable in <Object?>[null, 'many', -1, 1.5, true]) {
        final Map<String, dynamic> mfa = <String, dynamic>{...body['mfa'] as Map<String, dynamic>};
        mfa['recovery_codes_left'] = unreadable;

        expect(PlatformAdminSignIn.fromJson(<String, dynamic>{...body, 'mfa': mfa}).recoveryCodesLeft, isNull,
            reason: '$unreadable');
      }
      expect(PlatformAdminSignIn.fromJson(<String, dynamic>{...body}..remove('mfa')).recoveryCodesLeft, isNull);
    });

    test('does not give its token to anything that prints it', () {
      final PlatformAdminSignIn signIn = PlatformAdminSignIn.fromJson(fixtureData('mfa_success_totp'));

      expect('$signIn', isNot(contains('lkpa_')));
    });
  });

  group('a session in the list', () {
    test('says how it passed the second factor, and nothing when it did not', () {
      final List<PlatformSessionModel> sessions =
          fixtureRows('sessions_with_mfa_method').map(PlatformSessionModel.fromJson).toList();

      expect(sessions.map((PlatformSessionModel session) => session.mfaMethod), <PlatformAdminMfaMethod?>[
        PlatformAdminMfaMethod.recoveryCode,
        PlatformAdminMfaMethod.totp,
        null,
        PlatformAdminMfaMethod.totp,
      ]);
      expect(sessions.where((PlatformSessionModel session) => session.isCurrent), hasLength(1));
    });

    test('of a server that does not say has no method', () {
      final List<PlatformSessionModel> sessions =
          fixtureRows('sessions_owner').map(PlatformSessionModel.fromJson).toList();

      expect(sessions.every((PlatformSessionModel session) => session.mfaMethod == null), isTrue);
    });
  });

  group('what an admin types for the second step', () {
    test('a code is six digits, with the spaces and hyphens between them dropped', () {
      expect(PlatformSecondFactorInput.code('123456'), '123456');
      expect(PlatformSecondFactorInput.code(' 123 456 '), '123456');
      expect(PlatformSecondFactorInput.code('123-456'), '123456');
      expect(PlatformSecondFactorInput.code('012345'), '012345', reason: 'the leading zero stays');
    });

    test('the digits of an Arabic or a Persian keyboard are the digits they are', () {
      expect(PlatformSecondFactorInput.code('١٢٣٤٥٦'), '123456');
      expect(PlatformSecondFactorInput.code('۱۲۳ ۴۵۶'), '123456');
      expect(PlatformSecondFactorInput.code('١2٣4٥6'), '123456');
    });

    test('anything else is not a code, so that nothing that cannot be right uses up a try', () {
      for (final String typed in <String>['', '12345', '1234567', '12a456', '12.456', '12​3456x', 'abcdef']) {
        expect(PlatformSecondFactorInput.code(typed), isNull, reason: typed);
      }
    });

    test('a recovery code is ten letters and digits in the form the server documents, whatever it was typed with', () {
      expect(PlatformSecondFactorInput.recoveryCode('abcde-fghj2'), 'abcde-fghj2');
      expect(PlatformSecondFactorInput.recoveryCode('ABCDE-FGHJ2'), 'abcde-fghj2');
      expect(PlatformSecondFactorInput.recoveryCode('abcdefghj2'), 'abcde-fghj2');
      expect(PlatformSecondFactorInput.recoveryCode('  abcde fghj2 '), 'abcde-fghj2');
      expect(PlatformSecondFactorInput.recoveryCode('AbCdE-fGhJ2'), 'abcde-fghj2');
    });

    test('anything else is not a recovery code', () {
      for (final String typed in <String>[
        '',
        'abcde-fghj',
        'abcde-fghj23',
        'abcde_fghj2',
        'abcde-fgh!2',
        'اااااا-ااااا'
      ]) {
        expect(PlatformSecondFactorInput.recoveryCode(typed), isNull, reason: typed);
      }
    });

    test('which letters a recovery code may have is the server\'s to say, and the app does not', () {
      expect(PlatformSecondFactorInput.recoveryCode('ilo01-ilo01'), 'ilo01-ilo01');
    });
  });
}
