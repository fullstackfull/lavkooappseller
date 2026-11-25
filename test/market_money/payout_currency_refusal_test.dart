import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/control_tower/domain/models/control_tower_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/payout_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/seller_center_models.dart';

/// What the three money surfaces of this app do with a figure the server refused to produce (K-04.2, K-09, K-10).
///
/// The server will not add two currencies: a sum of riyals and dirhams is not money, so where a ledger holds more than one it
/// answers `null` for the combined figures, each currency's own figures, and a reason
/// (`SellerMarketTotals::money` → `totals_of_different_currencies_are_not_added`). The app read those nulls as
/// `value ?? 0`, so a seller holding money in two currencies was shown **withdrawable 0.00** — in the largest type on the
/// screen they ask for money from, and again on the dashboard tile and in the daily briefing, with nothing anywhere to say why.
///
/// A zero looks authoritative in a way a blank does not, and it is the ceiling the payout request is checked against, so the
/// zero was worse than the wrong sum the server refuses to give.
void main() {
  /// A seller of one currency, which is every seller while markets are off: the combined figures are the answer.
  const String oneCurrency = '''
  {"balances":{"available":700,"pending":0,"reserved":-100,"paid":-200,"balance":400},
   "withdrawable":400,"payout_currencies":["SAR"],"in_cooling_period":false,"payout_eligible":true,
   "total_size":0,"limit":10,"offset":1,"requests":[]}''';

  /// The same shop once it holds riyals and dirhams: no combined figure, each currency's own, and the reason.
  const String twoCurrencies = '''
  {"balances":null,"withdrawable":null,
   "balances_by_currency":[
     {"currency_code":"SAR","available":700,"pending":0,"reserved":-100,"paid":-200,"balance":400,"withdrawable":400},
     {"currency_code":"AED","available":120,"pending":30,"reserved":0,"paid":0,"balance":150,"withdrawable":150}],
   "totals_refused_because":"totals_of_different_currencies_are_not_added",
   "payout_currencies":["SAR","AED"],"in_cooling_period":false,"payout_eligible":true,
   "total_size":0,"limit":10,"offset":1,"requests":[]}''';

  PayoutOverviewModel payoutsOf(String body) =>
      PayoutOverviewModel.fromJson(jsonDecode(body) as Map<String, dynamic>);

  group('the payouts screen, which is where a seller asks for money', () {
    test('one currency keeps every figure and every shape it had', () {
      final PayoutOverviewModel payouts = payoutsOf(oneCurrency);

      expect(payouts.totalsRefused, isFalse);
      expect(payouts.withdrawable, 400);
      expect(payouts.available, 700);
      expect(payouts.reserved, -100);
      expect(payouts.hasWithdrawableFigure, isTrue);
      expect(payouts.balancesByCurrency, isEmpty);
    });

    test('two currencies have NO combined figure, and no figure is not a figure of zero', () {
      final PayoutOverviewModel payouts = payoutsOf(twoCurrencies);

      expect(payouts.withdrawable, isNull);
      expect(payouts.available, isNull);
      expect(payouts.pending, isNull);
      expect(payouts.reserved, isNull);
      expect(payouts.paid, isNull);
      expect(payouts.balance, isNull);
      expect(payouts.withdrawable, isNot(0), reason: 'the zero this screen used to print');
    });

    test('and the reason, and each currency\'s own real figures, are what there is to show', () {
      final PayoutOverviewModel payouts = payoutsOf(twoCurrencies);

      expect(payouts.totalsRefused, isTrue);
      expect(payouts.totalsRefusedBecause, 'totals_of_different_currencies_are_not_added');
      expect(payouts.balancesByCurrency.map((group) => group.currencyCode), <String>['SAR', 'AED']);
      expect(payouts.balancesByCurrency.first['withdrawable'], 400);
      expect(payouts.balancesByCurrency.last['withdrawable'], 150);
      expect(payouts.balancesByCurrency.last['balance'], 150);
      expect(payouts.balancesByCurrency.first['currency_code'], isNull, reason: 'the code is the group, not a figure of it');
    });

    test('no payout can be asked for while there is no ceiling to ask against', () {
      expect(payoutsOf(twoCurrencies).hasWithdrawableFigure, isFalse);
      expect(payoutsOf(oneCurrency).hasWithdrawableFigure, isTrue);
    });

    test('the combined figures of the two currencies are nowhere in the model: not as a sum, not as a zero', () {
      final PayoutOverviewModel payouts = payoutsOf(twoCurrencies);

      // 400 + 150 = 550 and 700 + 120 = 820: the sums the server refuses to give. Neither may appear as a combined figure.
      expect(<double?>[payouts.withdrawable, payouts.balance, payouts.available], everyElement(isNull));
    });
  });

  group('the dashboard tile', () {
    SellerFinanceModel financeOf(String body) =>
        SellerFinanceModel.fromJson(jsonDecode(body) as Map<String, dynamic>);

    test('one currency reads the figure it always read', () {
      final SellerFinanceModel finance = financeOf('{"available":700,"pending":0,"balance":400,"withdrawable":400}');

      expect(finance.withdrawable, 400);
      expect(finance.totalsRefused, isFalse);
    });

    test('two currencies read no figure, with the reason and the breakdown beside it', () {
      final SellerFinanceModel finance = financeOf('''
      {"available":null,"pending":null,"balance":null,"withdrawable":null,
       "balances_by_currency":[{"currency_code":"SAR","withdrawable":400},{"currency_code":"AED","withdrawable":150}],
       "totals_refused_because":"totals_of_different_currencies_are_not_added"}''');

      expect(finance.withdrawable, isNull);
      expect(finance.available, isNull);
      expect(finance.totalsRefused, isTrue);
      expect(finance.balancesByCurrency.map((group) => group.currencyCode), <String>['SAR', 'AED']);
    });
  });

  group('the daily briefing', () {
    DailyBriefingModel briefingOf(String balance) => DailyBriefingModel.fromJson(
        jsonDecode('{"date":"2026-11-25","balance":$balance}') as Map<String, dynamic>);

    test('one currency reads the figure it always read', () {
      final DailyBriefingModel briefing = briefingOf('{"currency":"SAR","pending":0,"withdrawable":398}');

      expect(briefing.withdrawable, 398);
      expect(briefing.pending, 0);
      expect(briefing.currency, 'SAR');
      expect(briefing.totalsRefused, isFalse);
    });

    test('two currencies read no figure, and the briefing answers the breakdown under its OWN singular key', () {
      final DailyBriefingModel briefing = briefingOf('''
      {"currency":null,"pending":null,"withdrawable":null,
       "balance_by_currency":[{"currency_code":"SAR","withdrawable":398},{"currency_code":"AED","withdrawable":150}],
       "totals_refused_because":"totals_of_different_currencies_are_not_added"}''');

      expect(briefing.withdrawable, isNull);
      expect(briefing.pending, isNull);
      expect(briefing.currency, isNull, reason: 'there is no one currency to label a figure with either');
      expect(briefing.totalsRefused, isTrue);
      expect(briefing.balanceByCurrency.map((group) => group.currencyCode), <String>['SAR', 'AED']);
    });

    test('a briefing with no balance block at all reads no figure, and refuses nothing', () {
      final DailyBriefingModel briefing = DailyBriefingModel.fromJson(<String, dynamic>{'date': '2026-11-25'});

      expect(briefing.withdrawable, isNull);
      expect(briefing.totalsRefused, isFalse);
      expect(briefing.balanceByCurrency, isEmpty);
      expect(briefing.orders, 0, reason: 'a count is a count: no currency, nothing to refuse');
    });
  });

  group('by reading the source', () {
    String codeOf(String path) => File(path).readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');

    test('the payouts screen draws the reason where the figure would have been, and never the refusal as money', () {
      final String screen = codeOf('lib/features/seller_center/screens/payouts_screen.dart');

      expect(screen, contains('if (payouts.totalsRefused)'));
      expect(screen, contains('getTranslated(payouts.totalsRefusedBecause!, context) ?? payouts.totalsRefusedBecause!'));
      expect(screen, isNot(contains('convertPriceForWithdraw(context, payouts.withdrawable)')),
          reason: 'the figure is only drawn where there is one');
    });

    test('a payout is asked for against a figure that exists, not against a refusal', () {
      final String screen = codeOf('lib/features/seller_center/screens/payouts_screen.dart');

      expect(screen, contains('final bool canRequest = payouts.hasWithdrawableFigure'));
      expect(screen, isNot(contains('canRequest = payouts.withdrawable > 0')));
    });

    test('the tile and the briefing draw a dash rather than a zero', () {
      final String tile = codeOf('lib/features/seller_center/widgets/seller_center_card_widget.dart');
      final String briefing = codeOf('lib/features/control_tower/widgets/control_tower_widgets.dart');

      expect(tile, contains('overview.finance?.withdrawable == null'));
      expect(tile, contains("'—'"));
      expect(tile, isNot(contains('overview.finance?.withdrawable ?? 0')), reason: 'the zero it used to draw');
      expect(briefing, contains("briefing.withdrawable == null ? '—'"));
      expect(briefing, contains('briefing.totalsRefused'), reason: 'and the reason under the card');
    });

    test('no money model of these three features turns an absent figure into a zero', () {
      for (final String path in <String>[
        'lib/features/seller_center/domain/models/payout_models.dart',
        'lib/features/seller_center/domain/models/seller_center_models.dart',
      ]) {
        expect(codeOf(path), isNot(contains("_toDouble(json['withdrawable'])")), reason: path);
      }
      expect(codeOf('lib/features/control_tower/domain/models/control_tower_models.dart'),
          isNot(contains("_double(balance['withdrawable']) ?? 0")));
    });
  });
}
