import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_sessions_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_session_tile.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

/// The devices the admin is signed in on, and the two things that are not reads.
void main() {
  late FakePlatformAdminService service;
  late PlatformAdminController controller;

  setUp(() async {
    service = FakePlatformAdminService();
    controller = PlatformAdminController(platformAdminServiceInterface: service);
    service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
    await controller.restoreSession();
  });

  Future<void> pumpSessions(
    WidgetTester tester, {
    Locale locale = PlatformAdminHarness.english,
    double textScale = 1.0,
    Size size = PlatformAdminHarness.phone,
    bool loaded = true,
    bool darkTheme = false,
  }) async {
    if (loaded) await controller.loadSessions();
    service.calls.clear();
    PlatformAdminHarness.useScreen(tester, size);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      home: const Scaffold(body: PlatformAdminSessionsScreen()),
      controller: controller,
      locale: locale,
      textScale: textScale,
      darkTheme: darkTheme,
    ));
    await tester.pump();
  }

  group('the list', () {
    testWidgets('shows who is signed in and every open session, newest first, the one in use marked',
        (WidgetTester tester) async {
      await pumpSessions(tester);

      expect(find.text('Signed in as ${ownerProfile().name}'), findsOneWidget);
      final List<String> devices = <String>['Pixel 9', 'Owner iPad', 'Owner iPhone'];
      final List<double> tops = devices.map((String device) => tester.getTopLeft(find.text(device)).dy).toList();
      expect(tops, <double>[...tops]..sort(), reason: 'newest first, as the server sent them');
      expect(find.text('This device'), findsOneWidget);
      final Finder tileInUse =
          find.byWidgetPredicate((Widget widget) => widget is PlatformSessionTile && widget.session.isCurrent);
      expect(find.descendant(of: tileInUse, matching: find.text('This device')), findsOneWidget,
          reason: 'on the device that is in use');
      expect(find.descendant(of: tileInUse, matching: find.text('Owner iPhone')), findsOneWidget);
    });

    testWidgets('says when each was opened and when it ends, in the zone of the phone', (WidgetTester tester) async {
      await pumpSessions(tester);

      expect(find.text(PlatformAdminTexts.moment(DateTime.utc(2026, 11, 17, 4))), findsOneWidget,
          reason: 'Owner iPhone was opened at 04:00 UTC');
      expect(find.text(PlatformAdminTexts.moment(DateTime.utc(2026, 11, 17, 14))), findsWidgets,
          reason: 'and all three end at 14:00 UTC');
    });

    testWidgets('a session that was never used says so, and is not given the time it was opened as its last use',
        (WidgetTester tester) async {
      await pumpSessions(tester);

      expect(find.text('Not used yet'), findsNWidgets(2));
      expect(find.text(PlatformAdminTexts.moment(DateTime.utc(2026, 11, 17, 6))), findsNWidgets(2),
          reason: 'Owner iPhone was last used at 06:00, and Pixel 9 was opened at 06:00');
    });

    testWidgets('shows what it is doing while it has not heard yet', (WidgetTester tester) async {
      final Gate<PlatformAdminResult<List<PlatformSessionModel>>> gate =
          Gate<PlatformAdminResult<List<PlatformSessionModel>>>();
      service.onSessions = () => gate.future;
      final Future<void> loading = controller.loadSessions();
      await pumpSessions(tester, loaded: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('This device'), findsNothing);
      gate.open(PlatformAdminResult<List<PlatformSessionModel>>.success(
          fixtureRows('sessions_owner').map(PlatformSessionModel.fromJson).toList()));
      await loading;
      await tester.pump();
      expect(find.text('Owner iPad'), findsOneWidget);
    });

    testWidgets('says that there are none when there are none', (WidgetTester tester) async {
      service.onSessions =
          () async => const PlatformAdminResult<List<PlatformSessionModel>>.success(<PlatformSessionModel>[]);

      await pumpSessions(tester);

      expect(find.text('No open sessions.'), findsOneWidget);
    });

    testWidgets(
        'a list that cannot be read says why and offers to try again, the way the app does when it has no connection',
        (WidgetTester tester) async {
      service.onSessions = () async => unreachable<List<PlatformSessionModel>>();
      await pumpSessions(tester);

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.text('Check your internet connection and try again'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      service.onSessions = () async => PlatformAdminResult<List<PlatformSessionModel>>.success(
          fixtureRows('sessions_owner').map(PlatformSessionModel.fromJson).toList());
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Owner iPad'), findsOneWidget);
    });

    testWidgets('pulling down asks again', (WidgetTester tester) async {
      await pumpSessions(tester);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(service.count('sessions'), 1);
    });
  });

  group('ending a session', () {
    testWidgets('is offered for every device but the one in use', (WidgetTester tester) async {
      await pumpSessions(tester);

      expect(find.text('End session'), findsNWidgets(2));
    });

    testWidgets('asks first, naming what will happen, and asks nothing of the server if it is declined',
        (WidgetTester tester) async {
      await pumpSessions(tester);

      await tester.tap(find.text('End session').first);
      await tester.pumpAndSettle();

      expect(find.text('End this session? That device will be signed out.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.calls, isEmpty);
    });

    testWidgets('ends it when confirmed, by its own id, and reads the list again', (WidgetTester tester) async {
      await pumpSessions(tester);

      await tester.tap(find.text('End session').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(service.calls, <String>['endSession 5', 'sessions']);
    });

    testWidgets('one that cannot be reached says so, and the list is left as it was', (WidgetTester tester) async {
      service.onEndSession = (int id) async => unreachable<int>();
      await pumpSessions(tester);

      await tester.tap(find.text('End session').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.text('Owner iPad'), findsOneWidget);
    });

    testWidgets('one that had already ended says that, and is gone from the list', (WidgetTester tester) async {
      service.onEndSession = (int id) async => refused<int>('error_session_not_found');
      await pumpSessions(tester);

      await tester.tap(find.text('End session').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('That session has already ended.'), findsOneWidget);
      expect(service.calls, contains('sessions'));
    });

    testWidgets('shows which one is being ended and lets no second be ended while it waits',
        (WidgetTester tester) async {
      final Gate<PlatformAdminResult<int>> gate = Gate<PlatformAdminResult<int>>();
      service.onEndSession = (int id) => gate.future;
      await pumpSessions(tester);

      await tester.tap(find.text('End session').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final Finder others = find.widgetWithText(TextButton, 'End session');
      expect(others, findsOneWidget);
      expect(tester.widget<TextButton>(others).onPressed, isNull,
          reason: 'the other session waits until this one is over');
      gate.open(const PlatformAdminResult<int>.success(5));
      await tester.pumpAndSettle();
      expect(find.text('End session'), findsNWidgets(2));
      expect(
          tester
              .widgetList<TextButton>(find.widgetWithText(TextButton, 'End session'))
              .every((TextButton button) => button.onPressed != null),
          isTrue);
    });
  });

  group('signing out', () {
    testWidgets('is a button of its own, and says what it does', (WidgetTester tester) async {
      await pumpSessions(tester);
      await tester.scrollUntilVisible(find.text('Logout'), 300, scrollable: find.byType(Scrollable).first);

      expect(find.text('Logout'), findsOneWidget);
      expect(find.text('Sign out of platform admin on this phone'), findsOneWidget);
    });

    testWidgets('signs out here, and tells the server', (WidgetTester tester) async {
      await pumpSessions(tester);
      await tester.scrollUntilVisible(find.text('Logout'), 300, scrollable: find.byType(Scrollable).first);

      await tester.ensureVisible(find.text('Logout'));
      await tester.pump();
      await tester.tap(find.text('Logout'));
      await tester.pump();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(service.calls, <String>['signOut']);
      expect(controller.sessions, isNull);
    });
  });

  group('how each session passed the second factor', () {
    setUp(() {
      service.onSessions = () async => PlatformAdminResult<List<PlatformSessionModel>>.success(
          fixtureRows('sessions_with_mfa_method').map(PlatformSessionModel.fromJson).toList());
    });

    testWidgets('is on its tile in words, and a session that passed none says nothing of one',
        (WidgetTester tester) async {
      await pumpSessions(tester, size: PlatformAdminHarness.tallPhone);

      expect(find.text('Second factor:'), findsNWidgets(3));
      expect(find.text('Authenticator app'), findsNWidgets(2));
      expect(find.text('Recovery code'), findsOneWidget);
      final Finder staging = find.byWidgetPredicate(
          (Widget widget) => widget is PlatformSessionTile && widget.session.deviceName == 'Staging phone');
      expect(find.descendant(of: staging, matching: find.text('Second factor:')), findsNothing);
    });

    testWidgets('is said in Arabic too', (WidgetTester tester) async {
      await pumpSessions(tester, locale: PlatformAdminHarness.arabic, size: PlatformAdminHarness.tallPhone);

      expect(find.text('التحقق بخطوتين:'), findsNWidgets(3));
      expect(find.text('تطبيق المصادقة'), findsNWidgets(2));
      expect(find.text('رمز الاسترداد'), findsOneWidget);
    });

    testWidgets('is not said for a server that does not say it', (WidgetTester tester) async {
      service.onSessions = () async => PlatformAdminResult<List<PlatformSessionModel>>.success(
          fixtureRows('sessions_owner').map(PlatformSessionModel.fromJson).toList());

      await pumpSessions(tester);

      expect(find.text('Second factor:'), findsNothing);
    });
  });

  group('ending all the other sessions', () {
    Finder button() => find.widgetWithText(OutlinedButton, 'End all other sessions');

    Future<void> tapEndOthers(WidgetTester tester) async {
      await tester.scrollUntilVisible(button(), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(button());
      await tester.pumpAndSettle();
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
    }

    testWidgets('is offered under the list while there is another session, and says what it is',
        (WidgetTester tester) async {
      await pumpSessions(tester);
      await tester.scrollUntilVisible(button(), 300, scrollable: find.byType(Scrollable).first);

      expect(button(), findsOneWidget);
      expect(find.byIcon(Icons.devices_other_outlined), findsOneWidget);
      expect(tester.widget<OutlinedButton>(button()).onPressed, isNotNull);
    });

    testWidgets('is not offered when this is the only session there is, or while there is no list',
        (WidgetTester tester) async {
      service.onSessions = () async => PlatformAdminResult<List<PlatformSessionModel>>.success(
          fixtureRows('sessions_owner')
              .map(PlatformSessionModel.fromJson)
              .where((PlatformSessionModel session) => session.isCurrent)
              .toList());
      await pumpSessions(tester);
      expect(button(), findsNothing);

      service.onSessions = () async => unreachable<List<PlatformSessionModel>>();
      controller = PlatformAdminController(platformAdminServiceInterface: service);
      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await controller.restoreSession();
      await tester.pumpWidget(const SizedBox());
      await pumpSessions(tester);
      expect(button(), findsNothing);
    });

    testWidgets('is not offered to a grant that does not include the sessions', (WidgetTester tester) async {
      controller = PlatformAdminController(platformAdminServiceInterface: service);
      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(
          PlatformAdminProfile.fromJson(fixtureData('me_restricted_capabilities')));
      await controller.restoreSession();

      await pumpSessions(tester);

      expect(find.text('Owner iPad'), findsOneWidget, reason: 'the list is there: it was asked for');
      expect(button(), findsNothing);
    });

    testWidgets('asks first, naming what will happen, and asks nothing of the server if it is declined',
        (WidgetTester tester) async {
      await pumpSessions(tester);

      await tapEndOthers(tester);

      expect(find.text('Every other device signed in as you will be signed out. This device stays signed in.'),
          findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);
    });

    testWidgets('ends them when confirmed, says how many it ended, and reads the list again',
        (WidgetTester tester) async {
      await pumpSessions(tester);

      await tapEndOthers(tester);
      await confirm(tester);

      expect(service.calls, <String>['endOtherSessions', 'sessions']);
      expect(find.text('Sessions ended: 2'), findsOneWidget);
    });

    testWidgets('says when there was nothing to end', (WidgetTester tester) async {
      service.onEndOtherSessions = () async => const PlatformAdminResult<int>.success(0);
      await pumpSessions(tester);

      await tapEndOthers(tester);
      await confirm(tester);

      expect(find.text('There were no other open sessions.'), findsOneWidget);
    });

    testWidgets('says why when it could not, and leaves the list as it was', (WidgetTester tester) async {
      service.onEndOtherSessions = () async => unreachable<int>();
      await pumpSessions(tester);

      await tapEndOthers(tester);
      await confirm(tester);

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.text('Owner iPad'), findsOneWidget);
      expect(service.count('sessions'), 0);
    });

    testWidgets('a part the grant leaves out is said as that, and the app reads what the grant includes again',
        (WidgetTester tester) async {
      service.onEndOtherSessions = () async => refused<int>('error_capability_not_allowed');
      await pumpSessions(tester);

      await tapEndOthers(tester);
      await confirm(tester);

      expect(find.text('This part is not included in your access.'), findsOneWidget);
      expect(service.count('profile'), 1);
    });

    testWidgets('a session that is over ends the shell\'s session, once, instead of saying anything here',
        (WidgetTester tester) async {
      service.onEndOtherSessions = () async => refused<int>('error_unauthenticated');
      await pumpSessions(tester);

      await tapEndOthers(tester);
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isTrue);
      expect(service.count('sessions'), 0);
    });

    testWidgets('is busy while it waits, and every other way of ending a session waits with it',
        (WidgetTester tester) async {
      final Gate<PlatformAdminResult<int>> gate = Gate<PlatformAdminResult<int>>();
      service.onEndOtherSessions = () => gate.future;
      await pumpSessions(tester);

      await tapEndOthers(tester);
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.widget<OutlinedButton>(button()).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
          tester
              .widgetList<TextButton>(find.widgetWithText(TextButton, 'End session'))
              .every((TextButton ending) => ending.onPressed == null),
          isTrue);
      gate.open(const PlatformAdminResult<int>.success(2));
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(button()).onPressed, isNotNull);
    });

    testWidgets('is said in Arabic', (WidgetTester tester) async {
      await pumpSessions(tester, locale: PlatformAdminHarness.arabic);
      final Finder arabic = find.widgetWithText(OutlinedButton, 'إنهاء جميع الجلسات الأخرى');

      await tester.scrollUntilVisible(arabic, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(arabic);
      await tester.pumpAndSettle();

      expect(find.textContaining('سيتم تسجيل خروج جميع الأجهزة الأخرى'), findsOneWidget);
    });
  });

  group('in Arabic', () {
    testWidgets('reads from the right, in Arabic, with no key showing through', (WidgetTester tester) async {
      await pumpSessions(tester, locale: PlatformAdminHarness.arabic);

      expect(Directionality.of(tester.element(find.byType(PlatformAdminSessionsScreen))), TextDirection.rtl);
      expect(find.text('هذا الجهاز'), findsOneWidget);
      expect(find.text('إنهاء الجلسة'), findsNWidgets(2));
      expect(PlatformAdminHarness.texts(tester).where((String text) => text.startsWith('platform_admin_')), isEmpty);
    });
  });

  group('on a small phone with large text', () {
    testWidgets('fits at the narrowest width with the text at twice its size, in either language',
        (WidgetTester tester) async {
      for (final Locale locale in <Locale>[PlatformAdminHarness.english, PlatformAdminHarness.arabic]) {
        await pumpSessions(tester, locale: locale, textScale: 2.0, size: PlatformAdminHarness.narrowPhone);

        expect(tester.takeException(), isNull, reason: locale.languageCode);
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${locale.languageCode} scrolled');
      }
    });

    testWidgets('and in the dark theme, with the sessions of a second factor and the button that ends the others',
        (WidgetTester tester) async {
      service.onSessions = () async => PlatformAdminResult<List<PlatformSessionModel>>.success(
          fixtureRows('sessions_with_mfa_method').map(PlatformSessionModel.fromJson).toList());

      for (final Locale locale in <Locale>[PlatformAdminHarness.english, PlatformAdminHarness.arabic]) {
        await pumpSessions(tester,
            locale: locale, textScale: 2.0, size: PlatformAdminHarness.narrowPhone, darkTheme: true);
        await tester.scrollUntilVisible(find.byType(OutlinedButton), 300, scrollable: find.byType(Scrollable).first);

        expect(find.byType(OutlinedButton), findsOneWidget, reason: locale.languageCode);
        expect(tester.takeException(), isNull, reason: '${locale.languageCode} dark');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
