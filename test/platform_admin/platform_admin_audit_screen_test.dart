import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_audit_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_audit_tile.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

/// The audit log, as the platform owner and a country manager meet it.
void main() {
  late FakePlatformAdminService service;
  late PlatformAdminController controller;

  setUp(() {
    service = FakePlatformAdminService();
    controller = PlatformAdminController(platformAdminServiceInterface: service);
  });

  Future<void> signIn({PlatformAdminProfile? as}) async {
    service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(as ?? ownerProfile());
    await controller.restoreSession();
  }

  /// The audit screen, with what it asks for already answered.
  Future<void> pumpAudit(
    WidgetTester tester, {
    Locale locale = PlatformAdminHarness.english,
    double textScale = 1.0,
    Size size = PlatformAdminHarness.tallPhone,
    bool loaded = true,
  }) async {
    if (loaded) await controller.loadAuditLog();
    service.calls.clear();
    PlatformAdminHarness.useScreen(tester, size);
    await tester.pumpWidget(await PlatformAdminHarness.app(
      tester,
      home: const Scaffold(body: PlatformAdminAuditScreen()),
      controller: controller,
      locale: locale,
      textScale: textScale,
    ));
    await tester.pump();
  }

  Finder line(int id) => find.byWidgetPredicate((Widget widget) => widget is PlatformAuditTile && widget.line.id == id);

  Finder inLine(int id, Finder what) => find.descendant(of: line(id), matching: what);

  List<int> shownIds(WidgetTester tester) => tester
      .widgetList<PlatformAuditTile>(find.byType(PlatformAuditTile))
      .map((PlatformAuditTile t) => t.line.id)
      .toList();

  /// The moment every line of the fixtures was written, as the phone writes it.
  final String when = PlatformAdminTexts.moment(DateTime.utc(2026, 11, 17, 6));

  /// Answers every request with the same page of lines.
  void answerWith(List<Map<String, dynamic>> rows, {bool hasMore = false, String scope = 'all'}) {
    service.onAuditLogs = (int page) async => PlatformAdminResult<PlatformAuditPage>.success(PlatformAuditPage.fromJson(
        rows, <String, dynamic>{'scope': scope, 'page': page, 'per_page': 25, 'has_more': hasMore}));
  }

  group('the platform owner', () {
    setUp(signIn);

    testWidgets('sees the lines newest first, in the order the server gave them', (WidgetTester tester) async {
      await pumpAudit(tester);

      expect(shownIds(tester), <int>[33, 32, 31, 30, 29]);
    });

    testWidgets('reads each as what was done, in words, when, and by whom', (WidgetTester tester) async {
      await pumpAudit(tester);

      expect(inLine(33, find.text('Viewed audit log')), findsOneWidget);
      expect(inLine(33, find.text('$when · You')), findsOneWidget, reason: 'admin 4 is the one signed in');
      expect(inLine(32, find.text('Access removed')), findsOneWidget);
      expect(inLine(32, find.text('$when · Admin 7')), findsOneWidget);
      expect(inLine(31, find.text('All sessions ended by an operator')), findsOneWidget);
      expect(inLine(30, find.text('Access granted')), findsOneWidget);
      expect(inLine(29, find.text('Ended a session')), findsOneWidget);
    });

    testWidgets('says what a request was answered with, and where it came from and what asked, where the line has them',
        (WidgetTester tester) async {
      await pumpAudit(tester);

      expect(inLine(33, find.text('Status 200')), findsOneWidget);
      expect(inLine(33, find.text('127.0.0.1 \u00b7 Symfony')), findsOneWidget);
      expect(inLine(29, find.text('Status 404')), findsOneWidget);
      expect(inLine(32, find.textContaining('Status')), findsNothing, reason: 'a line written at the console has none');
      expect(inLine(32, find.textContaining('127.0.0.1')), findsNothing);
      expect(inLine(32, find.textContaining('Symfony')), findsNothing);
    });

    testWidgets('a line that has only an address, or only a program, shows that alone', (WidgetTester tester) async {
      final Map<String, dynamic> row = fixtureRows('audit_logs_owner')[3];
      answerWith(<Map<String, dynamic>>[
        <String, dynamic>{...row, 'id': 91, 'ip': '10.0.0.7', 'user_agent': null},
        <String, dynamic>{...row, 'id': 92, 'ip': null, 'user_agent': 'okhttp/4.12.0'},
      ]);

      await pumpAudit(tester);

      expect(inLine(91, find.text('10.0.0.7')), findsOneWidget);
      expect(inLine(92, find.text('okhttp/4.12.0')), findsOneWidget);
    });

    testWidgets('tells a refusal from an answer by its colour, and the number is beside it',
        (WidgetTester tester) async {
      await pumpAudit(tester);

      Color? colourOf(int id, String text) => tester.widget<Text>(inLine(id, find.text(text))).style?.color;

      final Color refusal = Theme.of(tester.element(line(29))).colorScheme.error;
      expect(colourOf(29, 'Status 404'), refusal);
      expect(colourOf(33, 'Status 200'), isNot(refusal));
    });

    testWidgets('a line the operator wrote at the console has no admin, and says so', (WidgetTester tester) async {
      answerWith(<Map<String, dynamic>>[
        <String, dynamic>{...fixtureRows('audit_logs_owner')[0], 'id': 99, 'admin_id': null},
      ]);

      await pumpAudit(tester);

      expect(inLine(99, find.text('$when · Operator')), findsOneWidget);
    });

    testWidgets('names the market a line is about, and says nothing of one when it is about none',
        (WidgetTester tester) async {
      answerWith(<Map<String, dynamic>>[
        <String, dynamic>{...fixtureRows('audit_logs_owner')[0], 'id': 98, 'market': 'SA'},
        <String, dynamic>{...fixtureRows('audit_logs_owner')[0], 'id': 97, 'market': null},
      ]);

      await pumpAudit(tester);

      expect(inLine(98, find.text('Saudi Arabia')), findsOneWidget);
      expect(inLine(97, find.text('Saudi Arabia')), findsNothing);
    });

    testWidgets('an action the app has never heard of is written out from its own name', (WidgetTester tester) async {
      answerWith(<Map<String, dynamic>>[
        <String, dynamic>{...fixtureRows('audit_logs_owner')[0], 'id': 96, 'action': 'grant.frozen'},
      ]);

      await pumpAudit(tester);

      expect(inLine(96, find.text('Grant Frozen')), findsOneWidget);
    });

    testWidgets('every action the API writes today has words of its own', (WidgetTester tester) async {
      const List<String> actions = <String>[
        'auth.login',
        'auth.login_failed',
        'auth.logout',
        'me.view',
        'sessions.list',
        'session.revoke',
        'markets.view',
        'overview.view',
        'alerts.view',
        'audit_logs.view',
        'grant.created',
        'grant.updated',
        'grant.reactivated',
        'grant.revoked',
        'tokens.revoked',
      ];
      answerWith(<Map<String, dynamic>>[
        for (final (int index, String action) in actions.indexed)
          <String, dynamic>{...fixtureRows('audit_logs_owner')[0], 'id': 200 + index, 'action': action},
      ]);

      await pumpAudit(tester);

      final List<String> titles = <String>[
        for (int index = 0; index < actions.length; index++)
          tester.widget<Text>(find.descendant(of: line(200 + index), matching: find.byType(Text)).first).data!,
      ];
      expect(titles.toSet(), hasLength(actions.length), reason: 'no two actions are told the same way');
      for (final String title in titles) {
        expect(title, isNot(contains('.')), reason: 'not an action name written out: $title');
        expect(title, isNot(contains('_')), reason: title);
      }
    });

    testWidgets('drawing the log asks for nothing: the home asks', (WidgetTester tester) async {
      await pumpAudit(tester);

      expect(service.calls, isEmpty);
    });
  });

  group('more of it', () {
    setUp(signIn);

    testWidgets('is offered when the server says there is more, added under the first page, and then not offered',
        (WidgetTester tester) async {
      await pumpAudit(tester);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, <String>['auditLogs p2']);
      expect(find.byType(PlatformAuditTile), findsNWidgets(30));
      expect(shownIds(tester).take(5), <int>[33, 32, 31, 30, 29], reason: 'the first page stays where it was');
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('is not offered when there is none', (WidgetTester tester) async {
      answerWith(fixtureRows('audit_logs_owner').take(3).toList());

      await pumpAudit(tester);

      expect(find.byType(PlatformAuditTile), findsNWidgets(3));
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('shows that it is on the way, in the place of the button', (WidgetTester tester) async {
      await pumpAudit(tester);
      final Gate<PlatformAdminResult<PlatformAuditPage>> gate = Gate<PlatformAdminResult<PlatformAuditPage>>();
      service.onAuditLogs = (int page) => gate.future;

      await tester.tap(find.text('Load more'));
      await tester.pump();

      expect(find.text('Load more'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PlatformAuditTile), findsNWidgets(5));
      gate.open(PlatformAdminResult<PlatformAuditPage>.success(FakePlatformAdminService.auditOf(2)));
      await tester.pump();
      expect(find.byType(PlatformAuditTile), findsNWidgets(30));
    });

    testWidgets('a page that cannot be had says so above the log, keeps the lines, and can be asked for again',
        (WidgetTester tester) async {
      await pumpAudit(tester);
      service.onAuditLogs = (int page) async => unreachable<PlatformAuditPage>();

      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.byType(PlatformAuditTile), findsNWidgets(5));
      expect(find.text('Load more'), findsOneWidget);
    });
  });

  group('when it cannot be had', () {
    setUp(signIn);

    testWidgets('no connection says so the way the app does elsewhere, and asking again works',
        (WidgetTester tester) async {
      service.onAuditLogs = (int page) async => unreachable<PlatformAuditPage>();
      await pumpAudit(tester);

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.byType(PlatformAuditTile), findsNothing);

      service.onAuditLogs =
          (int page) async => PlatformAdminResult<PlatformAuditPage>.success(FakePlatformAdminService.auditOf(page));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PlatformAuditTile), findsNWidgets(5));
    });

    testWidgets('a failure on top of lines that are already there says so above them, and leaves them',
        (WidgetTester tester) async {
      await pumpAudit(tester);
      service.onAuditLogs = (int page) async => unreachable<PlatformAuditPage>();

      await controller.loadAuditLog(force: true);
      await tester.pump();

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(find.byType(PlatformAuditTile), findsNWidgets(5));
    });

    testWidgets('shows that it is asking, and nothing of a line until it has the answer', (WidgetTester tester) async {
      final Gate<PlatformAdminResult<PlatformAuditPage>> gate = Gate<PlatformAdminResult<PlatformAuditPage>>();
      service.onAuditLogs = (int page) => gate.future;
      final Future<void> loading = controller.loadAuditLog();

      await pumpAudit(tester, loaded: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PlatformAuditTile), findsNothing);
      expect(find.text('No audit lines yet.'), findsNothing, reason: 'not yet known to be none');
      gate.open(PlatformAdminResult<PlatformAuditPage>.success(FakePlatformAdminService.auditOf(1)));
      await loading;
      await tester.pump();
      expect(find.byType(PlatformAuditTile), findsNWidgets(5));
    });

    testWidgets('a log with nothing in it says so', (WidgetTester tester) async {
      answerWith(<Map<String, dynamic>>[]);

      await pumpAudit(tester);

      expect(find.text('No audit lines yet.'), findsOneWidget);
      expect(find.byType(PlatformAuditTile), findsNothing);
    });

    testWidgets('a session the server has ended puts nothing of the log on the screen', (WidgetTester tester) async {
      await pumpAudit(tester);
      service.onAuditLogs = (int page) async => refused<PlatformAuditPage>('error_unauthenticated');

      await controller.loadAuditLog(force: true);
      await tester.pump();

      expect(controller.stage, PlatformAdminStage.signedOut);
      expect(controller.sessionEnded, isTrue);
      expect(find.byType(PlatformAuditTile), findsNothing);
    });

    testWidgets('pulling down asks for the first page again', (WidgetTester tester) async {
      await pumpAudit(tester, size: PlatformAdminHarness.phone);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(service.calls, <String>['auditLogs p1']);
    });
  });

  group('a country manager', () {
    setUp(() => signIn(as: restrictedProfile()));

    setUp(() => answerWith(fixtureRows('audit_logs_restricted'), scope: 'restricted'));

    testWidgets('sees their own lines, and every one of them is theirs', (WidgetTester tester) async {
      await pumpAudit(tester);

      expect(find.byType(PlatformAuditTile), findsNWidgets(7));
      expect(find.textContaining('· You'), findsNWidgets(7));
      expect(find.textContaining('Admin '), findsNothing);
    });

    testWidgets('sees the name of the device that signed in, and a refusal marked as one', (WidgetTester tester) async {
      await pumpAudit(tester);

      expect(inLine(2, find.text('Signed in')), findsOneWidget);
      expect(inLine(2, find.text('Device: Country manager phone')), findsOneWidget);
      expect(inLine(25, find.text('Status 403')), findsOneWidget);
      expect(inLine(25, find.text('Saudi Arabia')), findsOneWidget, reason: 'the market that was refused');
    });
  });

  group('in Arabic', () {
    setUp(signIn);

    testWidgets('reads from the right, in Arabic, and no key shows through', (WidgetTester tester) async {
      await pumpAudit(tester, locale: PlatformAdminHarness.arabic);

      expect(Directionality.of(tester.element(find.byType(PlatformAdminAuditScreen))), TextDirection.rtl);
      expect(inLine(33, find.text('عرض سجل التدقيق')), findsOneWidget);
      expect(inLine(33, find.textContaining('أنت')), findsOneWidget);
      expect(inLine(33, find.text('الحالة 200')), findsOneWidget);
      expect(inLine(32, find.text('سحب صلاحية')), findsOneWidget);
      expect(inLine(32, find.textContaining('مدير 7')), findsOneWidget);
      expect(find.text('عرض المزيد'), findsOneWidget);
      expect(PlatformAdminHarness.texts(tester).where((String text) => text.startsWith('platform_admin_')), isEmpty);
    });

    testWidgets('the lines start at the right edge', (WidgetTester tester) async {
      await pumpAudit(tester, locale: PlatformAdminHarness.arabic);

      final double screenRight = tester.getTopRight(find.byType(PlatformAdminAuditScreen)).dx;
      expect(tester.getTopRight(line(33)).dx, greaterThan(screenRight - 40));
      expect(tester.getTopRight(inLine(33, find.text('عرض سجل التدقيق'))).dx, greaterThan(screenRight - 60));
    });
  });

  group('on a small phone with large text', () {
    setUp(signIn);

    testWidgets('fits at the narrowest width with the text at twice its size, in either language, all the way down',
        (WidgetTester tester) async {
      for (final Locale locale in <Locale>[PlatformAdminHarness.english, PlatformAdminHarness.arabic]) {
        await pumpAudit(tester, locale: locale, textScale: 2.0, size: PlatformAdminHarness.narrowPhone);

        expect(tester.takeException(), isNull, reason: locale.languageCode);
        for (int step = 0; step < 6; step++) {
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${locale.languageCode} after scrolling $step times');
        }
      }
    });

    testWidgets('and with a line that has every detail, a long device name and a failure above the log',
        (WidgetTester tester) async {
      answerWith(<Map<String, dynamic>>[
        <String, dynamic>{
          ...fixtureRows('audit_logs_restricted').last,
          'market': 'QA',
          'ip': '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
          'context': <String, dynamic>{
            'status': 429,
            'device_name': 'The country manager of the Gulf markets, their second phone, the blue one',
          },
        },
      ], hasMore: true);
      await pumpAudit(tester, textScale: 2.0, size: const Size(320, 3000));
      service.onAuditLogs = (int page) async => unreachable<PlatformAuditPage>();
      await controller.loadMoreAuditLog();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Could not reach the server'), findsOneWidget);
    });
  });
}
