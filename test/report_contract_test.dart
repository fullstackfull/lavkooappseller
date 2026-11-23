import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/reports/domain/models/report_models.dart';

/// The reports, parsed from payloads captured verbatim from the running
/// backend.
///
/// These figures also appear on the vendor panel, computed by the same service.
/// A model that quietly reshapes one of them is a seller seeing one number on
/// their phone and another on the web — and trusting neither.
void main() {
  group('order report contract', () {
    const String liveOrders = '''
    {"period":{"date_type":"this_month","date_types":["today","this_week","this_month","this_year","custom_date"],
               "from":"2026-08-01","to":"2026-08-31","bucket":"day"},
     "counts":{"ongoing":0,"canceled":0,"delivered":1,"total":1},
     "amounts":{"due":0,"settled":200},
     "payments":{"cash":200,"wallet":0,"digital":0,"offline":0,"returned":0,"total":200},
     "chart":{"labels":["1 Aug","2 Aug","3 Aug"],"values":[0,0,200]},
     "orders":{"total_size":1,"limit":10,"offset":1,"orders":[
        {"id":900001,"order_status":"delivered","payment_status":"paid","payment_method":"cash_on_delivery",
         "order_amount":200,"discount_amount":0,"product_discount":10,"tax":5,"shipping_cost":0,
         "commission":0,"created_at":"2026-08-03T00:00:00.000000Z"}]}}''';

    test('parses the live order payload', () {
      final OrderReportModel report = OrderReportModel.fromJson(jsonDecode(liveOrders));

      expect(report.period.dateType, 'this_month');
      expect(report.period.bucket, 'day');
      expect(report.total, 1);
      expect(report.delivered, 1);
      expect(report.settled, 200);
      expect(report.payments!.cash, 200);
      expect(report.orders, hasLength(1));
      expect(report.orders.first.id, 900001);
      expect(report.orders.first.productDiscount, 10);
      expect(report.totalOrderCount, 1);
    });

    test('turnover is what is owed plus what has settled', () {
      final OrderReportModel report = OrderReportModel.fromJson(jsonDecode(
        '{"amounts":{"due":75.5,"settled":200}}'));

      expect(report.turnover, 275.5);
    });

    test('the payment total is the server\'s, never a sum of the parts', () {
      // An order edit adds to a bucket and a return comes back out, so the
      // total is not cash + wallet + digital + offline. Recomputing it on the
      // client would quietly overstate what the seller was paid.
      final ReportPaymentsModel payments = ReportPaymentsModel.fromJson(<String, dynamic>{
        'cash': 100, 'wallet': 0, 'digital': 60, 'offline': 0, 'returned': 25, 'total': 135,
      });

      expect(payments.total, 135);
      expect(payments.cash + payments.digital, 160, reason: 'the parts really do add to more');
      expect(payments.hasAny, isTrue);
    });

    test('a payload with nothing in it is still a report', () {
      final OrderReportModel report = OrderReportModel.fromJson(<String, dynamic>{});

      expect(report.total, 0);
      expect(report.orders, isEmpty);
      // Null, not an all-zero breakdown. "No payments section" and "paid
      // nothing" are different facts and the screen draws them differently.
      expect(report.payments, isNull);
      expect(report.chart.hasBars, isFalse);
      expect(report.period.dateType, 'this_year');
      expect(report.totalsRefused, isFalse, reason: 'an empty payload refused nothing');
    });

    // The answer a seller gets when the period holds orders in more than one
    // currency. Captured verbatim from `GET seller-center/reports/orders` on a
    // database with riyal, dirham and dinar orders in the window — and with
    // market scopes switched off and no grant table at all, because the server
    // refuses the single figure on the currencies an installation has and not
    // on a switch.
    const String refusedOrders = '''
    {"period":{"date_type":"this_month","date_types":["today"],"from":"2026-11-01","to":"2026-11-30","bucket":"day"},
     "counts":{"ongoing":5,"canceled":0,"delivered":0,"total":5},
     "amounts":null,
     "payments":null,
     "chart":{"labels":["1 Nov","2 Nov"],"values":null},
     "amounts_by_currency":[
        {"currency_code":"AED","due":202,"settled":0,"cash":0,"wallet":0,"digital":0,"offline":0,"returned":0,"total":0},
        {"currency_code":"KWD","due":203,"settled":0,"cash":0,"wallet":0,"digital":0,"offline":0,"returned":0,"total":0},
        {"currency_code":"SAR","due":610,"settled":0,"cash":0,"wallet":0,"digital":0,"offline":0,"returned":0,"total":0}],
     "chart_by_currency":[{"currency_code":"SAR","values":[0,610]},{"currency_code":"AED","values":[0,202]}],
     "totals_refused_because":"totals_of_different_currencies_are_not_added",
     "orders":{"total_size":0,"limit":10,"offset":1,"orders":[]}}''';

    test('a refused total is null and never zero', () {
      final OrderReportModel report = OrderReportModel.fromJson(jsonDecode(refusedOrders));

      // The whole point. `due: 0` reads on screen as "you are owed nothing" to
      // a seller owed 1015 across three currencies, and a seller acts on a
      // zero. Null is the model saying there is no one figure.
      expect(report.due, isNull);
      expect(report.settled, isNull);
      expect(report.payments, isNull);
      expect(report.turnover, isNull);
      expect(report.totalsRefused, isTrue);
      expect(report.totalsRefusedBecause, 'totals_of_different_currencies_are_not_added');
      expect(report.chart.hasBars, isFalse, reason: 'a null series is not a flat line');
      expect(report.total, 5, reason: 'the counts survive: a count is not money');
    });

    test('each currency keeps its own real figures', () {
      final OrderReportModel report = OrderReportModel.fromJson(jsonDecode(refusedOrders));

      expect(report.amountsByCurrency.map((g) => g.currencyCode).toList(), ['AED', 'KWD', 'SAR']);
      expect(report.amountsByCurrency[2]['due'], 610);
      expect(report.amountsByCurrency[0]['due'], 202);
      expect(report.amountsByCurrency[1]['due'], 203);
      // The three real figures do add to 1015, which is exactly why no one of
      // them may be shown as it.
      expect(report.amountsByCurrency.fold<double>(0, (a, g) => a + (g['due'] ?? 0)), 1015);
    });

    test('a refused chart is one series per currency over shared labels', () {
      final OrderReportModel report = OrderReportModel.fromJson(jsonDecode(refusedOrders));

      expect(report.chartByCurrency, hasLength(2));
      expect(report.chartByCurrency.first.currencyCode, 'SAR');
      expect(report.chartByCurrency.first.values, [0, 610]);
      expect(report.chart.labels, ['1 Nov', '2 Nov']);
    });

    test('the product report refuses its money and keeps its quantity', () {
      final ProductReportModel report = ProductReportModel.fromJson(jsonDecode(
        '{"counts":{"active":2,"pending":0,"rejected":0},'
        '"totals":{"sold_quantity":2,"sold_amount":null,"discount_given":null},'
        '"totals_by_currency":['
        '{"currency_code":"AED","sold_quantity":1,"sold_amount":200,"discount_given":3},'
        '{"currency_code":"SAR","sold_quantity":1,"sold_amount":1000,"discount_given":7}],'
        '"totals_refused_because":"totals_of_different_currencies_are_not_added"}'));

      expect(report.soldAmount, isNull, reason: '1000 riyals and 200 dirhams are not 1200');
      expect(report.discountGiven, isNull, reason: 'nor are 7 and 3 ten');
      expect(report.soldQuantity, 2, reason: 'but two units sold are two units sold');
      expect(report.totalsRefused, isTrue);
      expect(report.totalsByCurrency[1]['sold_amount'], 1000);
      expect(report.totalsByCurrency[0]['sold_amount'], 200);
    });
  });

  group('chart contract', () {
    test('a period with no sales is a flat line, not an absent chart', () {
      // The server builds the series from the calendar, so every bucket is
      // present at zero. That difference is the difference between "nothing
      // sold" and "no data", and the screen draws them differently.
      final ReportChartModel chart = ReportChartModel.fromJson(<String, dynamic>{
        'labels': ['Jan', 'Feb', 'Mar'],
        'values': [0, 0, 0],
      });

      expect(chart.hasBars, isTrue);
      expect(chart.peak, 0);
      expect(chart.length, 3);
    });

    test('labels and values are only read as far as both go', () {
      // A truncated payload must not index past the shorter of the two.
      final ReportChartModel chart = ReportChartModel.fromJson(<String, dynamic>{
        'labels': ['Jan', 'Feb', 'Mar'],
        'values': [5],
      });

      expect(chart.length, 1);
      expect(chart.peak, 5);
    });

    test('no chart at all is not bars of height zero', () {
      expect(ReportChartModel.fromJson(null).hasBars, isFalse);
      expect(ReportChartModel.fromJson(<String, dynamic>{}).hasBars, isFalse);
    });
  });

  group('product report contract', () {
    const String liveProducts = '''
    {"period":{"date_type":"this_year","date_types":["today","this_week","this_month","this_year","custom_date"],
               "from":"2026-01-01","to":"2026-12-31","bucket":"month"},
     "counts":{"active":2,"pending":0,"rejected":0},
     "totals":{"sold_quantity":3,"sold_amount":150,"discount_given":10},
     "chart":{"labels":["Jan","Feb"],"values":[0,2]},
     "top_products":[{"product_id":3,"name":"MEDEE hydra 50 ml","thumbnail":"a.webp",
                      "total_amount":150,"total_quantity":3}],
     "products":{"total_size":2,"limit":10,"offset":1,"products":[
        {"id":4,"name":"MEDEE Serum Vitzmin C","thumbnail":"b.webp","unit_price":5000,
         "current_stock":100,"request_status":1,"sold_quantity":0,"sold_amount":0}]}}''';

    test('parses the live product payload', () {
      final ProductReportModel report = ProductReportModel.fromJson(jsonDecode(liveProducts));

      expect(report.active, 2);
      expect(report.listedTotal, 2);
      expect(report.soldQuantity, 3);
      expect(report.soldAmount, 150);
      expect(report.discountGiven, 10);
      expect(report.topProducts, hasLength(1));
      expect(report.topProducts.first.name, 'MEDEE hydra 50 ml');
      expect(report.products, hasLength(1));
      expect(report.totalProductCount, 2);
    });

    test('a product deleted since the report was built keeps its row', () {
      final ProductReportModel report = ProductReportModel.fromJson(jsonDecode(
        '{"top_products":[{"product_id":9,"name":null,"total_amount":10,"total_quantity":1}]}'));

      expect(report.topProducts.first.name, isNull);
      expect(report.topProducts.first.productId, 9);
    });
  });

  group('stock report contract', () {
    const String liveStock = '''
    {"stock_limit":10,
     "categories":[{"id":3,"name":"Body Lotion"},{"id":7,"name":"skin care"}],
     "total_size":2,"limit":10,"offset":1,
     "products":[{"id":4,"name":"MEDEE Serum Vitzmin C","thumbnail":"b.webp","unit_price":5000,
                  "current_stock":100,"is_low_stock":false},
                 {"id":3,"name":"MEDEE hydra 50 ml","thumbnail":"a.webp","unit_price":5000,
                  "current_stock":2,"is_low_stock":true}]}''';

    test('parses the live stock payload', () {
      final StockReportModel report = StockReportModel.fromJson(jsonDecode(liveStock));

      expect(report.stockLimit, 10);
      expect(report.categories, hasLength(2));
      expect(report.products, hasLength(2));
      expect(report.totalSize, 2);
    });

    test('low stock is the server\'s verdict, not a threshold the client applies', () {
      // The threshold is the seller's own setting, or the platform default when
      // they have not set one. A client comparing against `stock_limit` itself
      // would disagree with the panel for every seller who changed it.
      final StockReportModel report = StockReportModel.fromJson(jsonDecode(liveStock));

      expect(report.lowStockCount, 1);
      expect(report.products.firstWhere((p) => p.id == 3).isLowStock, isTrue);
      expect(report.products.firstWhere((p) => p.id == 4).isLowStock, isFalse);
    });

    test('a missing flag is not low stock', () {
      final StockProductModel product = StockProductModel.fromJson(<String, dynamic>{
        'id': 1, 'current_stock': 0,
      });

      expect(product.isLowStock, isFalse);
    });
  });

  group('period contract', () {
    test('a custom range is recognised so its dates can be shown', () {
      final ReportPeriodModel period = ReportPeriodModel.fromJson(<String, dynamic>{
        'date_type': 'custom_date', 'from': '2026-01-20', 'to': '2026-02-20', 'bucket': 'day',
      });

      expect(period.isCustom, isTrue);
      expect(period.from, '2026-01-20');
      expect(period.to, '2026-02-20');
    });

    test('an absent period falls back to what the panel opens on', () {
      expect(ReportPeriodModel.fromJson(null).dateType, 'this_year');
      expect(ReportPeriodModel.fromJson(null).isCustom, isFalse);
    });
  });
}
