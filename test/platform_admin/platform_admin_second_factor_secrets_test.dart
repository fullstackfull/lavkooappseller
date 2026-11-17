import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_api_client.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_repository.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_token_store.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/services/platform_admin_service.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_home_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_shell_screen.dart';

import 'support/fixtures.dart';
import 'support/harness.dart';
import 'support/scripted_adapter.dart';

const String _email = 'owner@example.test';
const String _password = 'the-admins-own-password';
const String _wrongCode = '865931';
const String _recoveryCodeAsTyped = 'ABCDE FGHJ2';
const String _recoveryCodeAsSent = 'abcde-fghj2';

/// A recording of everything that reaches a logger.
class _Log {
  final List<String> lines = <String>[];

  String get everything => lines.join('\n');
}

/// Remembers every route the app opens and what it was given.
class _RouteWatcher extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);
}

/// The whole of the second step, with the real client, repository, service and controller and nothing but the network scripted:
/// a wrong code, then a recovery code, then the shell, then the way out.
///
/// What the password, the challenge, the codes and the token must never reach: a logger, a route, the storage of
/// the app, a header or an address, a screen, and anything the objects of the shell say about themselves.
void main() {
  late Map<String, String> secure;
  late SharedPreferences preferences;
  late ScriptedAdapter adapter;
  late PlatformAdminApiClient client;
  late PlatformAdminController controller;
  late _Log log;
  late _RouteWatcher routes;
  late DateTime now;
  int mfaAttempts = 0;

  setUp(() async {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 11, 17, 10);
    mfaAttempts = 0;
    log = _Log();
    routes = _RouteWatcher();

    adapter = ScriptedAdapter((RequestOptions options, RecordedRequest request) async {
      final String route = '${request.method} ${request.uri.path.replaceFirst('/api/platform-admin/v1', '')}';
      switch (route) {
        case 'POST /auth/login':
          return ScriptedAdapter.reply('login_mfa_required');
        case 'POST /auth/mfa':
          mfaAttempts++;
          return ScriptedAdapter.reply(mfaAttempts == 1 ? 'mfa_failed' : 'mfa_success_recovery_code');
        case 'GET /me':
          return ScriptedAdapter.reply('me_with_capabilities');
        case 'GET /markets':
          return ScriptedAdapter.reply('markets_owner');
        case 'GET /overview':
          return ScriptedAdapter.reply('overview_owner_all');
        case 'POST /auth/logout':
          return ScriptedAdapter.reply('logout');
        default:
          return ScriptedAdapter.reply('error_api_switched_off');
      }
    });
    client = PlatformAdminApiClient(baseUrl: 'https://lavkoo.com', languageCode: () => 'en');
    client.dio.httpClientAdapter = adapter;
    controller = PlatformAdminController(
      platformAdminServiceInterface: PlatformAdminService(
        platformAdminRepoInterface: PlatformAdminRepository(
          apiClient: client,
          tokenStore: SecurePlatformAdminTokenStore(),
          now: () => now,
        ),
        now: () => now,
      ),
      now: () => now,
    );
  });

  Finder codeField() => find.descendant(of: find.byType(CustomTextFieldWidget), matching: find.byType(TextField));

  /// Walks the admin through the whole thing, in the shell, as a route of its own over a screen that stands for the seller's login.
  Future<void> walkTheFlow(WidgetTester tester) async {
    PlatformAdminHarness.useScreen(tester, PlatformAdminHarness.phone);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      controller: controller,
      navigatorObservers: <NavigatorObserver>[routes],
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
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), _email);
    await tester.enterText(find.byType(TextField).at(1), _password);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.enterText(codeField(), _wrongCode);
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a recovery code instead'));
    await tester.pump();
    await tester.enterText(codeField(), _recoveryCodeAsTyped);
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
  }

  Future<void> walkThrough(WidgetTester tester) async {
    // The test binding wants debugPrint as it found it before it lets the test end, so it is put back here and not in a tear-down.
    final DebugPrintCallback original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => log.lines.add(message ?? '');
    try {
      await walkTheFlow(tester);
    } finally {
      debugPrint = original;
    }
  }

  /// Every secret the flow handles, and what it looks like when it is sent.
  List<String> secrets() =>
      <String>[_password, fixtureChallenge, _wrongCode, _recoveryCodeAsTyped, _recoveryCodeAsSent, fixtureToken];

  testWidgets('the flow works, so that what follows is about a flow that happened', (WidgetTester tester) async {
    await walkThrough(tester);

    expect(find.byType(PlatformAdminHomeScreen), findsOneWidget);
    expect(controller.stage, PlatformAdminStage.signedIn);
    expect(mfaAttempts, 2);
    expect((await SecurePlatformAdminTokenStore().read())!.token, fixtureToken);
  });

  testWidgets('no logger, not print and not debugPrint, ever hears a password, a challenge, a code or the token',
      (WidgetTester tester) async {
    final List<String> printed = <String>[];
    await runZoned(
      () => walkThrough(tester),
      zoneSpecification:
          ZoneSpecification(print: (Zone self, ZoneDelegate parent, Zone zone, String line) => printed.add(line)),
    );

    for (final String secret in <String>[...secrets(), _email]) {
      expect(printed.join('\n'), isNot(contains(secret)), reason: 'print: $secret');
      expect(log.everything, isNot(contains(secret)), reason: 'debugPrint: $secret');
    }
  });

  testWidgets(
      'the client has nothing that logs: no interceptor of the seller\'s, and none at all but the one that Dio itself has',
      (WidgetTester tester) async {
    expect(client.dio.interceptors.whereType<LogInterceptor>(), isEmpty);
    expect(client.dio.interceptors.map((Interceptor interceptor) => interceptor.runtimeType.toString()).toSet(),
        <String>{'ImplyContentTypeInterceptor'});
  });

  testWidgets('no route is opened with an argument, and no name or title of one holds a secret',
      (WidgetTester tester) async {
    await walkThrough(tester);

    expect(routes.pushed, isNotEmpty);
    for (final Route<dynamic> route in routes.pushed) {
      expect(route.settings.arguments, isNull, reason: '${route.settings}');
      for (final String secret in secrets()) {
        expect('${route.settings}', isNot(contains(secret)));
      }
    }
  });

  testWidgets('the storage of the app holds the session and what it needs, and nothing else of the flow',
      (WidgetTester tester) async {
    await walkThrough(tester);

    expect(secure.keys, <String>[SecurePlatformAdminTokenStore.sessionKey]);
    expect(jsonDecode(secure.values.single),
        <String, dynamic>{'token': fixtureToken, 'expires_at': '2026-11-17T18:00:00.000Z'});
    for (final String secret in <String>[
      _password,
      fixtureChallenge,
      _wrongCode,
      _recoveryCodeAsTyped,
      _recoveryCodeAsSent,
      _email
    ]) {
      expect(secure.values.join(), isNot(contains(secret)), reason: secret);
    }
    expect(preferences.getKeys(), isEmpty);
  });

  testWidgets(
      'what is sent carries the challenge and the code in the body of the second step and in no address, no header and no other request',
      (WidgetTester tester) async {
    await walkThrough(tester);

    final List<RecordedRequest> steps =
        adapter.requests.where((RecordedRequest request) => request.uri.path.endsWith('/auth/mfa')).toList();
    expect(steps, hasLength(2));
    expect(steps.first.data, <String, Object?>{'challenge': fixtureChallenge, 'code': _wrongCode});
    expect(steps.last.data, <String, Object?>{'challenge': fixtureChallenge, 'recovery_code': _recoveryCodeAsSent});

    for (final RecordedRequest request in adapter.requests) {
      expect(request.uri.toString(), isNot(contains(fixtureChallenge)));
      expect(request.uri.query, isEmpty.or(isNot(contains('lkpc_'))));
      expect(jsonEncode(request.headers), isNot(contains(fixtureChallenge)));
      expect(jsonEncode(request.headers), isNot(contains(_wrongCode)));
      expect(jsonEncode(request.headers), isNot(contains(_recoveryCodeAsSent)));
      if (!request.uri.path.endsWith('/auth/mfa')) {
        expect(request.everything, isNot(contains(fixtureChallenge)), reason: request.uri.path);
        expect(request.everything, isNot(contains(_recoveryCodeAsSent)), reason: request.uri.path);
        expect(request.everything, isNot(contains(_wrongCode)), reason: request.uri.path);
      }
      if (!request.uri.path.endsWith('/auth/login')) {
        expect(request.everything, isNot(contains(_password)), reason: request.uri.path);
      }
    }
    expect(
        adapter.requests
            .where((RecordedRequest request) => request.header('Authorization') != null)
            .map((RecordedRequest request) => request.header('Authorization'))
            .toSet(),
        <String>{'Bearer $fixtureToken'});
  });

  testWidgets('no screen says a secret in words', (WidgetTester tester) async {
    await walkThrough(tester);

    final String everything = PlatformAdminHarness.texts(tester).join('\n');
    for (final String secret in secrets()) {
      expect(everything, isNot(contains(secret)));
    }
  });

  testWidgets('nothing the objects of the shell say about themselves holds a secret', (WidgetTester tester) async {
    await walkThrough(tester);

    final String said = <Object?>[
      controller,
      controller.profile,
      controller.secondFactorFailure,
      controller.signInFailure,
      controller.restoreFailure
    ].map((Object? object) => '$object').join('\n');
    for (final String secret in secrets()) {
      expect(said, isNot(contains(secret)));
    }
  });

  testWidgets('and what was typed is gone from the fields when the second step is', (WidgetTester tester) async {
    await walkThrough(tester);

    expect(find.byType(CustomTextFieldWidget), findsNothing);
    final String everything = PlatformAdminHarness.texts(tester).join('\n');
    expect(everything, isNot(contains(_recoveryCodeAsTyped)));
    expect(controller.secondFactorMethods, isEmpty);
  });
}

extension on Matcher {
  /// Either this or the other.
  Matcher or(Matcher other) => anyOf(this, other);
}
