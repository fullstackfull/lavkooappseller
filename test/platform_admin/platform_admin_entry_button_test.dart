import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/platform_admin_config.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_sign_in_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_entry_button.dart';

import 'support/fake_service.dart';
import 'support/harness.dart';

/// The way in. Switched off it is nothing at all: the seller's login screen is
/// what it was, and no object of the shell exists.
void main() {
  late FakePlatformAdminService service;
  late int controllersMade;

  setUp(() {
    service = FakePlatformAdminService();
    controllersMade = 0;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  PlatformAdminController makeController() {
    controllersMade++;
    return PlatformAdminController(platformAdminServiceInterface: service);
  }

  Future<void> pumpLoginWith(WidgetTester tester,
      {required bool enabled, Locale locale = PlatformAdminHarness.english}) async {
    PlatformAdminHarness.useScreen(tester, PlatformAdminHarness.phone);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      locale: locale,
      home: Scaffold(
        body: Column(children: [
          const Text('the seller\'s login screen'),
          PlatformAdminEntryButton(enabled: enabled, createController: makeController),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('with the flag off', () {
    testWidgets('there is no entry: not a button, not a word, not a space', (WidgetTester tester) async {
      await pumpLoginWith(tester, enabled: false);

      expect(find.byType(TextButton), findsNothing);
      expect(find.textContaining('Platform admin'), findsNothing);
      expect(tester.getSize(find.byType(PlatformAdminEntryButton)), Size.zero);
      expect(find.text('the seller\'s login screen'), findsOneWidget);
    });

    testWidgets('and no object of the shell is made', (WidgetTester tester) async {
      await pumpLoginWith(tester, enabled: false);

      expect(controllersMade, 0);
      expect(service.calls, isEmpty);
    });
  });

  group('with the flag on', () {
    testWidgets('the entry is a discreet text button in the language of the app', (WidgetTester tester) async {
      await pumpLoginWith(tester, enabled: true);

      expect(find.widgetWithText(TextButton, 'Platform admin sign-in'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing, reason: 'not a call to action');
    });

    testWidgets('in Arabic too', (WidgetTester tester) async {
      await pumpLoginWith(tester, enabled: true, locale: PlatformAdminHarness.arabic);

      expect(find.widgetWithText(TextButton, 'دخول مدير المنصة'), findsOneWidget);
    });

    testWidgets('nothing is made until it is tapped', (WidgetTester tester) async {
      await pumpLoginWith(tester, enabled: true);

      expect(controllersMade, 0);
      expect(service.calls, isEmpty);
    });

    testWidgets(
        'tapping opens the shell as a route of its own, with a controller of its own, which looks for a session',
        (WidgetTester tester) async {
      await pumpLoginWith(tester, enabled: true);

      await tester.tap(find.text('Platform admin sign-in'));
      await tester.pumpAndSettle();

      expect(controllersMade, 1);
      expect(service.calls, <String>['restore']);
      expect(find.byType(PlatformAdminSignInScreen), findsOneWidget);
      expect(find.text('the seller\'s login screen'), findsNothing,
          reason: 'the shell is a route of its own, in front of the login screen');
    });

    testWidgets('leaving the shell with the back button returns to the login screen and lets the controller go',
        (WidgetTester tester) async {
      await pumpLoginWith(tester, enabled: true);
      await tester.tap(find.text('Platform admin sign-in'));
      await tester.pumpAndSettle();

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('the seller\'s login screen'), findsOneWidget);
      expect(find.byType(PlatformAdminSignInScreen), findsNothing);
    });

    testWidgets('opening the shell twice makes two controllers, so nothing of the first opening is shown in the second',
        (WidgetTester tester) async {
      await pumpLoginWith(tester, enabled: true);

      for (int opening = 0; opening < 2; opening++) {
        await tester.tap(find.text('Platform admin sign-in'));
        await tester.pumpAndSettle();
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
      }

      expect(controllersMade, 2);
    });
  });

  group('the build', () {
    test('has the flag the build was made with, and not one of its own', () {
      expect(const PlatformAdminEntryButton().enabled, PlatformAdminConfig.enabled);
    });
  });

  group('the seller\'s login screen', () {
    final String login = File('lib/features/auth/screens/login_screen.dart').readAsStringSync();

    test('shows the entry once, and only the entry: nothing else of the platform admin is in it', () {
      final List<String> lines = login
          .split('\n')
          .where((String line) => RegExp('platform_?admin', caseSensitive: false).hasMatch(line))
          .toList();

      expect(lines, hasLength(2), reason: lines.join('\n'));
      expect(lines.first, contains('platform_admin_entry_button.dart'));
      expect(lines.last.trim(), 'const PlatformAdminEntryButton(),');
    });

    test('is not given the flag, a controller or a session: whether the entry shows is the entry\'s own business', () {
      expect(login, isNot(contains('PlatformAdminConfig')));
      expect(login, isNot(contains('PlatformAdminController')));
      expect(login, isNot(contains('GetIt')));
    });
  });
}
