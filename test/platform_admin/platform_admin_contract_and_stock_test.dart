import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_api_client.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/platform_admin_config.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_overview_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_market_card.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';
import 'support/scripted_adapter.dart';

const String _platformToken = 'lkpa_PLATFORMTOKEN0123456789PLATFORMTOKEN0123456789PLATFORMTOKEN01234';

/// Two things the shell gained together, because both are about reading an answer
/// the server may or may not be able to give it.
///
/// **The contract level (L-17).** The shell says which level it can read, and the
/// server may refuse a build that is older than the oldest it answers. The level
/// is NOT this binary's version and has nothing to do with the seller app's
/// force-update gate: the shell can stop being able to read the platform's
/// answers without the seller app needing a release.
///
/// **The stock a market is holding (L-07).** What went past zero, what is promised
/// to orders, and how a pooled stock is divided. All whole counts of products and
/// units -- never money, which this shell has nowhere to keep.
void main() {
  group('the contract level this build speaks', () {
    PlatformAdminApiClient clientWith(ScriptedAdapter adapter) {
      final PlatformAdminApiClient client =
          PlatformAdminApiClient(baseUrl: AppConstants.baseUrl, languageCode: () => 'en');
      client.dio.httpClientAdapter = adapter;
      return client;
    }

    test('is sent on a read', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWith('me_owner');

      await clientWith(adapter).get('/me', bearerToken: _platformToken);

      expect(adapter.requests.single.header(PlatformAdminApiClient.contractHeader),
          '${PlatformAdminConfig.contractLevel}',
          reason: 'the header carries the level the build declares, not a number typed twice');
      expect(PlatformAdminConfig.contractLevel, 1, reason: 'and that level is 1 on this build');
    });

    test('is sent on the sign-in too, where there is no session yet', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWith('login_success');

      await clientWith(adapter).post(
        '/auth/login',
        body: <String, Object?>{'email': 'owner@example.test', 'password': 'a-password', 'device_name': 'Pixel 9'},
      );

      expect(adapter.requests.single.header(PlatformAdminApiClient.contractHeader), '1',
          reason: 'a build too old to read the answers must be refused before it is given a session');
    });

    test('is sent on every call, not only the first', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWith('me_owner');
      final PlatformAdminApiClient client = clientWith(adapter);

      await client.get('/me', bearerToken: _platformToken);
      await client.delete('/sessions/7', bearerToken: _platformToken);

      expect(
        adapter.requests.map((RecordedRequest request) => request.header(PlatformAdminApiClient.contractHeader)),
        <String>['1', '1'],
      );
    });

    test('carries nothing of the seller app: not its version, not its storefront, not its language choice', () async {
      final ScriptedAdapter adapter = ScriptedAdapter.replyingWith('me_owner');

      await clientWith(adapter).get('/me', bearerToken: _platformToken);

      expect(PlatformAdminApiClient.contractHeader.toLowerCase(), isNot(contains('version')),
          reason: 'the name itself says it is a contract level and not a build number');
      for (final String seller in <String>['x-app-version', 'x-storefront', 'x-localization', 'lang', 'cookie']) {
        expect(adapter.requests.single.headers.keys, isNot(contains(seller)), reason: seller);
      }
    });
  });

  group('a build the server will not answer', () {
    test('is told so, and it is not an authentication failure or something that went wrong', () {
      final PlatformAdminFailure failure = PlatformAdminFailure.fromResponse(
        statusCode: 426,
        body: <String, Object?>{
          'errors': <Object?>[
            <String, Object?>{
              'code': 'contract_too_old',
              'message': 'This build is too old for this server.',
              'contract': <String, Object?>{'claimed': 0, 'version': 1, 'min_supported': 1},
            },
          ],
        },
      );

      expect(failure.kind, PlatformAdminFailureKind.appTooOld);
      expect(failure.code, 'contract_too_old');
      expect(failure.statusCode, 426);
    });

    test('is still told so when the server names no code, because the status is the fact', () {
      expect(PlatformAdminFailure.fromResponse(statusCode: 426).kind, PlatformAdminFailureKind.appTooOld);
    });

    test('is not confused with any other refusal', () {
      for (final int status in <int>[401, 403, 404, 422, 425, 427, 429, 500, 503]) {
        expect(PlatformAdminFailure.fromResponse(statusCode: status).kind, isNot(PlatformAdminFailureKind.appTooOld),
            reason: '$status');
      }
    });

    test('keeps nothing the server said about it, as no other refusal does', () {
      final PlatformAdminFailure failure = PlatformAdminFailure.fromResponse(
        statusCode: 426,
        body: <String, Object?>{
          'errors': <Object?>[
            <String, Object?>{'code': 'contract_too_old', 'message': 'owner@example.test is on build 0'},
          ],
        },
      );

      expect(failure.toString(), isNot(contains('@')));
      expect(failure.retryAt, isNull, reason: 'there is nothing to retry: the app has to be updated');
    });
  });

  group('the stock a market is holding', () {
    PlatformFigures figuresOf(Map<String, dynamic> stock) => PlatformFigures.fromJson(<String, dynamic>{
          'orders': <String, dynamic>{'total': 0, 'by_status': <String, dynamic>{}},
          'sales': <String, dynamic>{'by_currency': null, 'reason': 'order_currency_not_recorded'},
          'pending_fulfilment': <String, dynamic>{'count': 0},
          'returns': <String, dynamic>{'refund_requests': 0, 'pending': 0},
          'stock': stock,
        });

    test('reads what went past zero, and by how many units', () {
      final PlatformFigures figures = figuresOf(<String, dynamic>{
        'zero': 3,
        'low': 1,
        'oversold': 2,
        'oversold_units': 7,
        'reserved': null,
        'allocation': null,
      });

      expect(<int>[figures.stockZero, figures.stockLow, figures.stockOversold, figures.stockOversoldUnits],
          <int>[3, 1, 2, 7]);
    });

    test('reads the holds and the pools when the platform records them', () {
      final PlatformFigures figures = figuresOf(<String, dynamic>{
        'zero': 0,
        'low': 0,
        'oversold': 0,
        'oversold_units': 0,
        'reserved': <String, dynamic>{'holds': 4, 'units': 11},
        'allocation': <String, dynamic>{'pools': 3, 'short': 1, 'short_units': 5},
      });

      expect(<int?>[figures.reserved?.holds, figures.reserved?.units], <int>[4, 11]);
      expect(<int?>[figures.allocation?.pools, figures.allocation?.short, figures.allocation?.shortUnits],
          <int>[3, 1, 5]);
    });

    test('has NO figure, rather than a zero, where the platform records neither', () {
      final PlatformFigures figures = figuresOf(<String, dynamic>{'zero': 1, 'low': 0});

      expect(figures.reserved, isNull, reason: 'a zero would say nothing is held when nothing is recorded');
      expect(figures.allocation, isNull);
      expect(<int>[figures.stockOversold, figures.stockOversoldUnits], <int>[0, 0],
          reason: 'the oversell is not dormant: an answer without it is an answer of none');
    });

    test('is read as a whole count whatever the answer puts there', () {
      final PlatformFigures figures = figuresOf(<String, dynamic>{
        'zero': '2',
        'low': null,
        'oversold': '1',
        'oversold_units': 'many',
        'reserved': <String, dynamic>{'holds': '3', 'units': null},
        'allocation': <String, dynamic>{'pools': 1, 'short': 'some', 'short_units': 2},
      });

      expect(<int>[figures.stockZero, figures.stockLow, figures.stockOversold, figures.stockOversoldUnits],
          <int>[2, 0, 1, 0]);
      expect(<int?>[figures.reserved?.holds, figures.reserved?.units], <int>[3, 0]);
      expect(<int?>[figures.allocation?.pools, figures.allocation?.short], <int>[1, 0]);
    });
  });

  group('on the market card', () {
    late FakePlatformAdminService service;
    late PlatformAdminController controller;

    setUp(() async {
      service = FakePlatformAdminService();
      controller = PlatformAdminController(platformAdminServiceInterface: service);
      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await controller.restoreSession();
    });

    /// The overview the server answered, with the stock of Saudi Arabia replaced.
    Future<void> pumpWithSaudiStock(WidgetTester tester, Map<String, dynamic> stock) async {
      final Map<String, dynamic> body = fixtureData('overview_owner_all');
      for (final Map<String, dynamic> market in (body['markets'] as List).cast<Map<String, dynamic>>()) {
        if (market['market'] == 'SA') market['stock'] = stock;
      }
      service.onOverview = (String market, int? windowDays) async =>
          PlatformAdminResult<PlatformOverviewModel>.success(PlatformOverviewModel.fromJson(body));
      await controller.loadOverview();
      PlatformAdminHarness.useScreen(tester, PlatformAdminHarness.tallPhone);
      await tester.pumpWidget(await PlatformAdminHarness.app(tester,
          home: const Scaffold(body: PlatformAdminOverviewScreen()), controller: controller));
      await tester.pump();
    }

    Finder card(String code) =>
        find.byWidgetPredicate((Widget widget) => widget is PlatformMarketCard && widget.overview.market == code);

    String figureOf(WidgetTester tester, String code, String label) {
      final Finder row = find.descendant(
          of: card(code),
          matching: find.byWidgetPredicate((Widget widget) => widget is PlatformFigureRow && widget.label == label));
      return tester.widget<PlatformFigureRow>(row).value;
    }

    testWidgets('what went past zero is drawn, with its units once there are any', (WidgetTester tester) async {
      await pumpWithSaudiStock(tester, <String, dynamic>{
        'zero': 3,
        'low': 1,
        'oversold': 2,
        'oversold_units': 7,
        'reserved': <String, dynamic>{'holds': 0, 'units': 0},
        'allocation': <String, dynamic>{'pools': 0, 'short': 0, 'short_units': 0},
      });

      expect(figureOf(tester, 'SA', 'Products out of stock'), '3');
      expect(figureOf(tester, 'SA', 'Products sold below zero'), '2');
      expect(figureOf(tester, 'SA', 'Units sold and not in stock'), '7');
    });

    testWidgets('a market with nothing past zero still says so, and keeps the units line off the card',
        (WidgetTester tester) async {
      await pumpWithSaudiStock(tester, <String, dynamic>{
        'zero': 1,
        'low': 3,
        'oversold': 0,
        'oversold_units': 0,
        'reserved': <String, dynamic>{'holds': 1, 'units': 2},
        'allocation': <String, dynamic>{'pools': 1, 'short': 0, 'short_units': 0},
      });

      expect(figureOf(tester, 'SA', 'Products sold below zero'), '0');
      expect(find.descendant(of: card('SA'), matching: find.text('Units sold and not in stock')), findsNothing);
      expect(find.descendant(of: card('SA'), matching: find.text('Pools that could not give every channel its share')),
          findsNothing,
          reason: 'a pool that is short of nothing is not a line worth reading');
    });

    testWidgets('the holds and the short pools are drawn with their units', (WidgetTester tester) async {
      await pumpWithSaudiStock(tester, <String, dynamic>{
        'zero': 0,
        'low': 0,
        'oversold': 0,
        'oversold_units': 0,
        'reserved': <String, dynamic>{'holds': 4, 'units': 11},
        'allocation': <String, dynamic>{'pools': 3, 'short': 1, 'short_units': 5},
      });

      expect(figureOf(tester, 'SA', 'Stock holds for orders'), '4');
      expect(figureOf(tester, 'SA', 'Units held for orders'), '11');
      expect(figureOf(tester, 'SA', 'Shared stock pools'), '3');
      expect(figureOf(tester, 'SA', 'Pools that could not give every channel its share'), '1');
      expect(figureOf(tester, 'SA', 'Units short across those pools'), '5');
    });

    testWidgets('a platform that records neither says so instead of drawing zeros', (WidgetTester tester) async {
      await pumpWithSaudiStock(tester, <String, dynamic>{'zero': 1, 'low': 3, 'oversold': 0, 'oversold_units': 0});

      for (final String label in <String>['Stock holds for orders', 'Shared stock pools']) {
        expect(find.descendant(of: card('SA'), matching: find.text(label)), findsNothing, reason: label);
      }
      expect(
          find.descendant(
              of: card('SA'),
              matching: find.text('Stock holds and shared pools are not fully recorded on this platform.')),
          findsOneWidget);
    });

    testWidgets('a platform that records one of the two draws it and still says the other is missing',
        (WidgetTester tester) async {
      await pumpWithSaudiStock(tester, <String, dynamic>{
        'zero': 0,
        'low': 0,
        'oversold': 0,
        'oversold_units': 0,
        'reserved': <String, dynamic>{'holds': 2, 'units': 9},
      });

      expect(figureOf(tester, 'SA', 'Stock holds for orders'), '2');
      expect(find.descendant(of: card('SA'), matching: find.text('Shared stock pools')), findsNothing);
      expect(
          find.descendant(
              of: card('SA'),
              matching: find.text('Stock holds and shared pools are not fully recorded on this platform.')),
          findsOneWidget);
    });

    testWidgets('none of these units is ever drawn as money', (WidgetTester tester) async {
      await pumpWithSaudiStock(tester, <String, dynamic>{
        'zero': 1,
        'low': 2,
        'oversold': 3,
        'oversold_units': 4,
        'reserved': <String, dynamic>{'holds': 5, 'units': 6},
        'allocation': <String, dynamic>{'pools': 7, 'short': 8, 'short_units': 9},
      });
      final List<String> texts = PlatformAdminHarness.texts(tester);

      expect(texts.where((String text) => RegExp(r'\d+[.,]\d+').hasMatch(text)), isEmpty,
          reason: 'a unit is a whole thing: no fraction and no thousands separator');
      expect(
          texts.where(
              (String text) => RegExp(r'\d\s*(SAR|AED|KWD|QAR|BHD|OMR)|(SAR|AED|KWD|QAR|BHD|OMR)\s*\d').hasMatch(text)),
          isEmpty,
          reason: 'no number next to a currency');
    });
  });
}
