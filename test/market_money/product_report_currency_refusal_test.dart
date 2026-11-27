import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/reports/domain/models/report_models.dart';

/// What the product report does with the money figures the server refused to produce (K-04.2).
///
/// `GET /api/v3/seller/reports/products` used to answer `sold_amount` 1200 for a thousand riyals plus two hundred dirhams.
/// It does not any more: where the period holds more than one currency `SellerReportService::productMoneyByCurrency` answers
/// the two money figures as **null**, each currency's own figures under `totals_by_currency`, and
/// `totals_refused_because` saying why. The **quantity** is never refused -- a unit sold in Riyadh and a unit sold in Dubai
/// are two units -- so it survives as a real combined figure.
///
/// The app parsed all of that and then drew none of it: the screen handed the nulls straight to
/// `PriceConverter.convertPrice`, which dereferences the figure it is given (`price!`), so the screen a seller opens to read
/// what their products earned threw instead of drawing. The fix nobody should make is the obvious one of reading the refusal
/// as zero: a zero is a figure a seller acts on, and this one says their products earned nothing.
void main() {
  /// A seller of one currency, which is every seller while markets are off: the one `totals` key, with the three figures it
  /// has always carried and no refusal anywhere in the answer.
  const String oneCurrency = '''
  {"period":{"date_type":"this_year"},
   "counts":{"active":12,"pending":1,"rejected":0},
   "totals":{"sold_quantity":31,"sold_amount":1000.5,"discount_given":7.25},
   "chart":{"labels":["Jan","Feb"],"values":[0,1000.5]},
   "top_products":[],"products":{"products":[],"total_size":0}}''';

  /// The same shop once the period holds riyals and dirhams: no combined money, the quantity still added, each currency's own
  /// figures, and the reason.
  const String twoCurrencies = '''
  {"period":{"date_type":"this_year"},
   "counts":{"active":12,"pending":1,"rejected":0},
   "totals":{"sold_quantity":31,"sold_amount":null,"discount_given":null},
   "totals_by_currency":[
     {"currency_code":"AED","sold_quantity":5,"sold_amount":202,"discount_given":3},
     {"currency_code":"SAR","sold_quantity":26,"sold_amount":1000.5,"discount_given":7.25}],
   "totals_refused_because":"totals_of_different_currencies_are_not_added",
   "chart":{"labels":["Jan","Feb"],"values":[0,31]},
   "top_products":[],"products":{"products":[],"total_size":0}}''';

  Map<String, dynamic> bodyOf(String body) =>
      jsonDecode(body) as Map<String, dynamic>;

  ProductReportModel reportOf(String body) =>
      ProductReportModel.fromJson(bodyOf(body));

  group('the answer the app is reading', () {
    test(
        'a one-currency answer carries no refusal KEY AT ALL, not a refusal key holding null',
        () {
      final Map<String, dynamic> body = bodyOf(oneCurrency);

      // A key that is present and null and a key that was never there are different answers, and a reader of
      // `json['x']?.toString()` cannot tell them apart afterwards -- so the dormant shape is pinned here, where it can.
      expect(body.containsKey('totals_refused_because'), isFalse);
      expect(body.containsKey('totals_by_currency'), isFalse);
      expect(
          (body['totals'] as Map<String, dynamic>).keys,
          containsAll(
              <String>['sold_quantity', 'sold_amount', 'discount_given']));
    });

    test(
        'a two-currency answer carries the three money keys present-and-null, which is the whole point',
        () {
      final Map<String, dynamic> body = bodyOf(twoCurrencies);
      final Map<String, dynamic> totals =
          body['totals'] as Map<String, dynamic>;

      expect(totals.containsKey('sold_amount'), isTrue,
          reason: 'present, so a client cannot read the old figure');
      expect(totals['sold_amount'], isNull,
          reason: 'and null, so it cannot read a sum that was never money');
      expect(totals.containsKey('discount_given'), isTrue);
      expect(totals['discount_given'], isNull);
      expect(totals['sold_quantity'], 31,
          reason: 'a count is a count: nothing to refuse');
    });
  });

  group('the model', () {
    test('one currency keeps every figure and every shape it had', () {
      final ProductReportModel report = reportOf(oneCurrency);

      expect(report.totalsRefused, isFalse);
      expect(report.totalsRefusedBecause, isNull);
      expect(report.soldAmount, 1000.5);
      expect(report.discountGiven, 7.25);
      expect(report.soldQuantity, 31);
      expect(report.totalsByCurrency, isEmpty);
      expect(report.listedTotal, 13);
    });

    test(
        'two currencies read NO combined money, and no figure is not a figure of zero',
        () {
      final ProductReportModel report = reportOf(twoCurrencies);

      expect(report.soldAmount, isNull);
      expect(report.discountGiven, isNull);
      expect(report.soldAmount, isNot(0),
          reason: 'the zero the obvious fix would have drawn');
      expect(report.soldQuantity, 31,
          reason: 'the quantity is real and combined, and must still be drawn');
      expect(report.totalsRefused, isTrue);
      expect(report.totalsRefusedBecause,
          'totals_of_different_currencies_are_not_added');
    });

    test(
        'each currency keeps its own real figures, in the order the server listed them',
        () {
      final ProductReportModel report = reportOf(twoCurrencies);

      expect(report.totalsByCurrency.map((group) => group.currencyCode),
          <String>['AED', 'SAR']);
      expect(report.totalsByCurrency.first['sold_amount'], 202);
      expect(report.totalsByCurrency.first['discount_given'], 3);
      expect(report.totalsByCurrency.last['sold_amount'], 1000.5);
      expect(report.totalsByCurrency.last['sold_quantity'], 26);
      // 202 + 1000.5 is the figure the server refuses to give, so it must not be anywhere in what the app holds either.
      expect(
          report.totalsByCurrency.map((group) => group['sold_amount']).toList(),
          isNot(contains(1202.5)));
    });

    test(
        'a report with no totals block at all reads no money, and refuses nothing',
        () {
      final ProductReportModel report =
          ProductReportModel.fromJson(<String, dynamic>{});

      expect(report.soldAmount, isNull);
      expect(report.discountGiven, isNull);
      expect(report.totalsRefused, isFalse);
      expect(report.totalsByCurrency, isEmpty);
      expect(report.soldQuantity, 0);
    });
  });

  group('by reading the source', () {
    /// The screen with its comments stripped and every run of whitespace flattened to one space.
    ///
    /// Flattened on purpose: `dart format` wraps at 80 columns and the style it picks depends on the package's language
    /// version, so an assertion written against one line break goes red the day the other style is used -- which says nothing
    /// about whether the screen still refuses to draw a refusal as money.
    String codeOf(String path) => File(path)
        .readAsStringSync()
        .replaceAll(RegExp(r'//[^\n]*'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    final String screen =
        codeOf('lib/features/reports/screens/product_report_screen.dart');

    test('the two money rows are only drawn where there is money to draw', () {
      expect(screen, contains('if (!report.totalsRefused) ...['));
      expect(screen, contains('if (report.totalsRefused) ...['));
      // What it used to do: hand the server's null to a converter that dereferences it.
      expect(
          screen, isNot(contains('convertPrice( context, report.soldAmount)')),
          reason: 'the call that threw on a refused period');
      expect(screen,
          isNot(contains('convertPrice( context, report.discountGiven)')));
      expect(
          screen, isNot(contains('convertPrice(context, report.soldAmount)')));
      expect(screen,
          isNot(contains('convertPrice(context, report.discountGiven)')));
    });

    test(
        'the quantity row sits OUTSIDE the refusal, because a count is never refused',
        () {
      final int quantityRow =
          screen.indexOf("ReportRowWidget( label: 'quantity_sold',");
      final int moneyGate = screen.indexOf('if (!report.totalsRefused) ...[');

      expect(quantityRow, greaterThan(0));
      expect(moneyGate, greaterThan(0));
      expect(quantityRow, lessThan(moneyGate),
          reason:
              'a unit sold in Riyadh and a unit sold in Dubai are two units');
    });

    test(
        'the reason the server gave is drawn where the figures would have been',
        () {
      expect(
          screen,
          contains(
              'getTranslated(report.totalsRefusedBecause!, context) ?? report.totalsRefusedBecause!'));
      expect(screen, contains('report.totalsByCurrency.map('));
      expect(
          screen,
          contains(
              "label: 'sales_value', value: _amount(group['sold_amount'])"));
      expect(screen, contains("value: _amount(group['discount_given'])"));
    });

    test(
        'a per-currency figure is written as it came, never converted to the display currency',
        () {
      expect(
          screen,
          contains(
              "String _amount(double? figure) => figure == null ? '\\u2014' : figure.toStringAsFixed(2);"));
      expect(
          screen, isNot(contains('_amount(double? figure) => PriceConverter')));
    });
  });
}
