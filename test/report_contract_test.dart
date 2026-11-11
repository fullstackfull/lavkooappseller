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
      expect(report.payments.cash, 200);
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
      expect(report.payments.hasAny, isFalse);
      expect(report.chart.hasBars, isFalse);
      expect(report.period.dateType, 'this_year');
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
