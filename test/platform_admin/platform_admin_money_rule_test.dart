import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_overview_screen.dart';

import 'support/fake_service.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

/// The platform admin API reports no money, because an order stores no currency
/// and its amounts are in the platform's base currency whatever market it was
/// sold in. The app must therefore never display, compute or sum money, and where
/// sales would be it says why there is no figure.
///
/// Three ways to break that are closed here: a helper that formats money cannot be
/// used, a model has no place to keep an amount, and a screen shows no amount even
/// if the server one day sends one, and adds no figure of one market to another's.
void main() {
  final List<File> sources = Directory('lib/features/platform_admin')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList();

  String codeOf(File file) =>
      file.readAsLinesSync().where((String line) => !line.trimLeft().startsWith('//')).join('\n');

  group('in the source', () {
    test('no helper that turns a number into money is used', () {
      final RegExp money = RegExp(
          r'PriceConverter|price_converter|NumberFormat\.(currency|simpleCurrency|compactCurrency|compactSimpleCurrency)|convertPrice|currencySymbol|toStringAsFixed|\.symbol\b|exchangeRate|SplashController');

      expect(sources.where((File file) => money.hasMatch(codeOf(file))).map((File file) => file.path), isEmpty);
    });

    test(
        'the models have nowhere to keep a fraction, which is what an amount is, and the controller and screens work in whole counts',
        () {
      final RegExp fraction = RegExp(r'\bdouble\b|\bDecimal\b|\bBigInt\b');

      expect(
        sources
            .where((File file) => file.path.contains('/domain/') || file.path.contains('/controllers/'))
            .where((File file) => fraction.hasMatch(codeOf(file)))
            .map((File file) => file.path),
        isEmpty,
      );
    });

    test('a number is read from the answer only as a whole one', () {
      final String json = codeOf(File('lib/features/platform_admin/domain/models/platform_admin_json.dart'));

      expect(json, isNot(contains('double.')));
      expect(json, contains('int.tryParse'));
      expect(json, isNot(contains('toDouble')));
    });

    test('the sales of a market keep a reason and nothing else of the sales section', () {
      final String overview =
          codeOf(File('lib/features/platform_admin/domain/models/platform_admin_overview_models.dart'));
      final int start = overview.indexOf('class PlatformSalesFigure');
      final String sales = overview.substring(start, overview.indexOf('\n}\n', start));

      expect(sales, isNot(contains('by_currency')));
      expect(RegExp(r'final\s+\S+\s+\w+;').allMatches(sales).map((RegExpMatch match) => match.group(0)),
          <String?>['final String? reason;']);
    });
  });

  group('on the screen', () {
    late FakePlatformAdminService service;
    late PlatformAdminController controller;

    setUp(() async {
      service = FakePlatformAdminService();
      controller = PlatformAdminController(platformAdminServiceInterface: service);
      service.onRestore = () async => PlatformAdminResult<PlatformAdminProfile?>.success(ownerProfile());
      await controller.restoreSession();
    });

    Future<List<String>> textsOfOverview(WidgetTester tester, Map<String, dynamic> body) async {
      service.onOverview = (String market, int? windowDays) async =>
          PlatformAdminResult<PlatformOverviewModel>.success(PlatformOverviewModel.fromJson(body));
      await controller.loadOverview();
      PlatformAdminHarness.useScreen(tester, PlatformAdminHarness.tallPhone);
      await tester.pumpWidget(await PlatformAdminHarness.app(tester,
          home: const Scaffold(body: PlatformAdminOverviewScreen()), controller: controller));
      await tester.pump();
      return PlatformAdminHarness.texts(tester);
    }

    /// An answer of a server that has begun to report sales, with amounts in it everywhere.
    Map<String, dynamic> answerWithAmounts() {
      final Map<String, dynamic> body = fixtureData('overview_owner_all');
      Map<String, dynamic> sales(String market, String currency) => <String, dynamic>{
            'by_currency': <Object?>[
              <String, dynamic>{
                'market': market,
                'currency': currency,
                'total': 1234567.89,
                'paid': 7654321.5,
                'orders': 5
              },
            ],
            'reason': null,
          };
      for (final Map<String, dynamic> market in (body['markets'] as List).cast<Map<String, dynamic>>()) {
        market['sales'] = sales(market['market'] as String, market['storefront_currency'] as String);
        market['revenue'] = 4242424.24;
      }
      (body['unattributed'] as Map<String, dynamic>)['sales'] = sales('none', 'SAR');
      return body;
    }

    testWidgets('no amount is shown even when the server sends one, in any form', (WidgetTester tester) async {
      final List<String> texts = await textsOfOverview(tester, answerWithAmounts());
      final String everything = texts.join(' | ');

      for (final String amount in <String>['1234567', '1,234,567', '7654321', '4242424']) {
        expect(everything, isNot(contains(amount)), reason: amount);
      }
      expect(texts.where((String text) => RegExp(r'\d+[.,]\d+').hasMatch(text)), isEmpty,
          reason: 'no figure with a fraction or a thousands separator');
      expect(texts.where((String text) => RegExp(r'(?<![\d:])\d{5,}').hasMatch(text)), isEmpty,
          reason: 'no figure of five digits or more');
      expect(
          texts.where(
              (String text) => RegExp(r'\d\s*(SAR|AED|KWD|QAR|BHD|OMR)|(SAR|AED|KWD|QAR|BHD|OMR)\s*\d').hasMatch(text)),
          isEmpty,
          reason: 'no number next to a currency');
    });

    testWidgets('it says that sales are not shown, once for each card and for the orders without a market',
        (WidgetTester tester) async {
      final List<String> texts = await textsOfOverview(tester, answerWithAmounts());

      expect(texts.where((String text) => text == 'Sales are not shown in this version of the app.'), hasLength(7));
    });

    testWidgets('the currency of a market is shown as a label of the market, never beside a figure',
        (WidgetTester tester) async {
      final List<String> texts = await textsOfOverview(tester, fixtureData('overview_owner_all'));

      expect(texts.where((String text) => <String>{'SAR', 'AED', 'KWD', 'QAR', 'BHD', 'OMR'}.contains(text)),
          hasLength(6));
      expect(
          texts
              .where((String text) => RegExp(r'\d').hasMatch(text) && RegExp('SAR|AED|KWD|QAR|BHD|OMR').hasMatch(text)),
          isEmpty);
    });

    testWidgets('no figure of one market is added to another\'s: not the orders and not the backlog',
        (WidgetTester tester) async {
      final Map<String, dynamic> body = fixtureData('overview_owner_all');
      final PlatformOverviewModel overview = PlatformOverviewModel.fromJson(body);
      final Iterable<int> orders = overview.markets.map((PlatformMarketOverview market) => market.figures.orders.total);
      final int ofMarkets = orders.reduce((int left, int right) => left + right);
      final int withBucket = ofMarkets + overview.unattributed!.figures.orders.total;
      final int backlog = overview.markets
          .map((PlatformMarketOverview market) => market.figures.pendingFulfilment)
          .reduce((int left, int right) => left + right);

      final List<String> texts = await textsOfOverview(tester, body);

      for (final int sum in <int>{ofMarkets, withBucket, backlog}) {
        expect(texts.where((String text) => text == '$sum'), isEmpty,
            reason: 'a text that is only $sum would be a total across markets');
      }
      expect(<int>{ofMarkets, withBucket, backlog}, <int>{9, 13, 6},
          reason: 'the sums the test looks for are the ones of this answer');
    });
  });
}
