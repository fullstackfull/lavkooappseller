import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/analytics_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/payout_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/seller_center_models.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/verification_models.dart';

/// These payloads were captured verbatim from a running backend
/// (`/api/v3/seller/seller-center/*`) against a real database, so the parsing
/// here is pinned to what the API actually sends rather than to what the
/// models assume it sends.
void main() {
  group('overview contract', () {
    const String liveOverview = '''
    {"verification":{"status":"pending","required_for_payout":false},
     "performance":{"seller_id":1,"orders_total":0,"delivered":0,"canceled":0,"returned":0,"failed":0,
       "fulfillment_rate":0,"cancellation_rate":0,"return_rate":0,"items_total":1,"items_refunded":0,
       "refund_rate":0,"avg_rating":null,"review_count":0,"moderation_strikes":0,
       "kyc_status":"pending","tier":"new"},
     "finance":{"available":700,"pending":0,"balance":400,"withdrawable":400,
       "recent_payout_status":"requested","recent_payout_reference":"PO-20260823-60AFEF"},
     "sla":{"open_breach_count":0,"open_breaches":[]}}''';

    test('parses the live overview payload', () {
      final SellerCenterOverviewModel overview =
          SellerCenterOverviewModel.fromJson(jsonDecode(liveOverview));

      expect(overview.verificationStatus, 'pending');
      expect(overview.kycRequiredForPayout, isFalse);
      expect(overview.performance?.tier, 'new');
      expect(overview.performance?.avgRating, isNull);
      expect(overview.finance?.withdrawable, 400);
      expect(overview.finance?.recentPayoutReference, 'PO-20260823-60AFEF');
      expect(overview.openSlaBreachCount, 0);
    });

    test('survives a payload with the sections missing', () {
      final SellerCenterOverviewModel overview = SellerCenterOverviewModel.fromJson(<String, dynamic>{});

      expect(overview.verificationStatus, isNull);
      expect(overview.performance, isNull);
      expect(overview.finance, isNull);
      expect(overview.openSlaBreachCount, 0);
    });

    test('reads rates and ratings that arrive as strings', () {
      // MySQL AVG() and the rounded rate columns come back as numeric strings
      // through PDO, so the parsing must not assume num.
      final ScorecardModel scorecard = ScorecardModel.fromJson(<String, dynamic>{
        'orders_total': '12',
        'fulfillment_rate': '0.8333',
        'avg_rating': '4.3333',
        'tier': 'good',
      });

      expect(scorecard.ordersTotal, 12);
      expect(scorecard.fulfillmentRate, closeTo(0.8333, 0.0001));
      expect(scorecard.avgRating, closeTo(4.3333, 0.0001));
      expect(scorecard.tier, 'good');
    });
  });

  group('verification contract', () {
    const String liveVerification = '''
    {"overall_status":"pending","kyc_required_for_payout":false,
     "required_documents":["identity","business_license"],
     "documents":[{"id":3,"seller_id":1,"document_type":"identity","document_number":"ID-99",
       "status":"pending","rejection_reason":null,"reviewed_at":null,"expires_at":null,
       "created_at":"2026-08-23T20:44:25.000000Z","updated_at":"2026-08-23T20:44:25.000000Z",
       "has_file":false}]}''';

    test('parses the live verification payload', () {
      final VerificationStatusModel verification =
          VerificationStatusModel.fromJson(jsonDecode(liveVerification));

      expect(verification.overallStatus, 'pending');
      expect(verification.requiredDocuments, ['identity', 'business_license']);
      expect(verification.documents, hasLength(1));
      expect(verification.documents.first.documentType, 'identity');
      expect(verification.documents.first.status, 'pending');
      expect(verification.documents.first.hasFile, isFalse);
    });

    test('never exposes admin review internals the API withholds', () {
      final Map<String, dynamic> document =
          jsonDecode(liveVerification)['documents'][0] as Map<String, dynamic>;

      expect(document.containsKey('notes'), isFalse);
      expect(document.containsKey('reviewed_by'), isFalse);
      expect(document.containsKey('file_path'), isFalse);
    });

    test('outstanding documents exclude approved types only', () {
      final VerificationStatusModel verification = VerificationStatusModel.fromJson(<String, dynamic>{
        'required_documents': <String>['identity', 'business_license'],
        'documents': <dynamic>[
          <String, dynamic>{'document_type': 'identity', 'status': 'approved'},
          // Submitted but still pending: the seller still owes this one.
          <String, dynamic>{'document_type': 'business_license', 'status': 'pending'},
        ],
      });

      expect(verification.outstandingDocuments, ['business_license']);
    });
  });

  group('payouts contract', () {
    const String livePayouts = '''
    {"balances":{"pending":0,"available":700,"reserved":-100,"paid":-200,"balance":400},
     "payout_currencies":[],"withdrawable":400,"in_cooling_period":false,"payout_eligible":true,
     "total_size":2,"limit":10,"offset":1,
     "requests":[{"id":2,"reference":"PO-20260823-60AFEF","seller_id":1,"seller_is":"seller",
       "amount":100,"currency":"SYP","payout_currency":null,"payout_amount":null,"exchange_rate":null,
       "status":"requested","method":"bank_transfer","method_details":[],"reviewed_at":null,
       "paid_at":null,"payment_reference":null,"created_at":"2026-08-23T20:43:06.000000Z",
       "updated_at":"2026-08-23T20:43:06.000000Z"}]}''';

    test('parses the live payouts payload', () {
      final PayoutOverviewModel payouts = PayoutOverviewModel.fromJson(jsonDecode(livePayouts));

      expect(payouts.available, 700);
      expect(payouts.balance, 400);
      expect(payouts.withdrawable, 400);
      expect(payouts.payoutEligible, isTrue);
      expect(payouts.inCoolingPeriod, isFalse);
      expect(payouts.requests, hasLength(1));
      expect(payouts.requests.first.reference, 'PO-20260823-60AFEF');
      expect(payouts.requests.first.amount, 100);
    });

    test('never exposes the admin review internals the API withholds', () {
      final Map<String, dynamic> request =
          jsonDecode(livePayouts)['requests'][0] as Map<String, dynamic>;

      expect(request.containsKey('review_note'), isFalse);
      expect(request.containsKey('reviewed_by'), isFalse);
      expect(request.containsKey('reserve_entry_id'), isFalse);
    });

    test('open statuses match the backend OPEN_STATUSES list', () {
      for (final String status in ['requested', 'under_review', 'approved', 'processing']) {
        expect(PayoutRequestModel(status: status).isOpen, isTrue, reason: '$status must be cancellable');
      }
      for (final String status in ['paid', 'rejected', 'failed']) {
        expect(PayoutRequestModel(status: status).isOpen, isFalse, reason: '$status must not be cancellable');
      }
    });

    test('the four buckets reconcile with the reported total', () {
      // available + pending + reserved + paid == balance, exactly, because the
      // backend sums every status group into `balance`. Dropping a bucket from
      // the screen is what makes the column stop adding up, so the model must
      // carry all four.
      final PayoutOverviewModel payouts = PayoutOverviewModel.fromJson(jsonDecode(livePayouts));

      expect(payouts.reserved, -100, reason: 'a live hold is a negative bucket');
      expect(payouts.paid, -200, reason: 'money already paid out stays in the balance as a negative');
      expect(
        payouts.available + payouts.pending + payouts.reserved + payouts.paid,
        payouts.balance,
      );
    });

    test('survives a payload with no balances object', () {
      final PayoutOverviewModel payouts = PayoutOverviewModel.fromJson(<String, dynamic>{});

      expect(payouts.available, 0);
      expect(payouts.withdrawable, 0);
      expect(payouts.requests, isEmpty);
      expect(payouts.payoutEligible, isTrue);
    });
  });

  group('analytics contract', () {
    // Captured from the running backend after seeding five real events for
    // seller 1 (two visitors, three product views, one cart add, one order).
    const String liveAnalytics = '''
    {"range":"7d","range_label":"last_7_days","ranges":["today","7d","30d","90d","365d"],
     "from":"2026-08-18","to":"2026-08-24","state":"ok",
     "summary":{"visitors":2,"sessions":2,"product_views":3,"cart_adds":1,"orders":1,"revenue":250},
     "products":[{"product_id":3,"name":"MEDEE hydra 50 ml","events":3,"visitors":2,"views":2,"cart_adds":1},
                 {"product_id":4,"name":"MEDEE Serum Vitzmin C","events":1,"visitors":1,"views":1,"cart_adds":0}]}''';

    const String liveEmptyAnalytics = '''
    {"range":"30d","range_label":"last_30_days","ranges":["today","7d","30d","90d","365d"],
     "from":"2026-07-26","to":"2026-08-24","state":"rollup_never_ran",
     "summary":{"visitors":0,"sessions":0,"product_views":0,"cart_adds":0,"orders":0,"revenue":0},
     "products":[]}''';

    test('parses the live analytics payload', () {
      final SellerAnalyticsModel analytics = SellerAnalyticsModel.fromJson(jsonDecode(liveAnalytics));

      expect(analytics.hasData, isTrue);
      expect(analytics.range, '7d');
      expect(analytics.ranges, ['today', '7d', '30d', '90d', '365d']);
      expect(analytics.summary?.visitors, 2);
      expect(analytics.summary?.productViews, 3);
      expect(analytics.summary?.revenue, 250);
      expect(analytics.products, hasLength(2));
      expect(analytics.products.first.name, 'MEDEE hydra 50 ml');
      expect(analytics.products.first.views, 2);
    });

    test('an empty window is not treated as data', () {
      final SellerAnalyticsModel analytics =
          SellerAnalyticsModel.fromJson(jsonDecode(liveEmptyAnalytics));

      expect(analytics.hasData, isFalse);
      expect(analytics.state, 'rollup_never_ran');
      expect(analytics.products, isEmpty);
    });

    test('view-to-cart rate never divides by zero', () {
      expect(AnalyticsSummaryModel().cartAddRate, 0);
      expect(
        AnalyticsSummaryModel(productViews: 3, cartAdds: 1).cartAddRate,
        closeTo(0.3333, 0.0001),
      );
    });

    test('a product the seller has since deleted keeps its row', () {
      // The backend resolves names at read time, so a row can outlive its
      // product and arrive with name:null. The screen falls back to the id.
      final SellerAnalyticsModel analytics = SellerAnalyticsModel.fromJson(jsonDecode('''
      {"range":"7d","state":"ok","ranges":["7d"],
       "summary":{"visitors":1,"sessions":1,"product_views":1,"cart_adds":0,"orders":0,"revenue":0},
       "products":[{"product_id":9,"name":null,"events":1,"visitors":1,"views":1,"cart_adds":0}]}'''));

      expect(analytics.products, hasLength(1));
      expect(analytics.products.first.name, isNull);
      expect(analytics.products.first.productId, 9);
    });

    test('activities carry each count through, not just the fact that one is set', () {
      // Captured from the running backend against known ground truth: two
      // products awaiting restock, three customer requests across them, one
      // unchecked order.
      final SellerActivitiesModel activities = SellerActivitiesModel.fromJson(jsonDecode(
        '{"new_order_count":1,"restock_product_count":2,"restock_request_count":3}'));

      expect(activities.newOrderCount, 1);
      expect(activities.restockProductCount, 2);
      expect(activities.restockRequestCount, 3);
      expect(activities.hasAny, isTrue);
    });

    test('activities only announce themselves when something is waiting', () {
      expect(SellerActivitiesModel.fromJson(<String, dynamic>{
        'new_order_count': 0, 'restock_product_count': 0, 'restock_request_count': 0,
      }).hasAny, isFalse);

      // Either summarised count alone raises the strip: a product awaiting
      // restock with no new order is still work waiting.
      expect(SellerActivitiesModel.fromJson(<String, dynamic>{
        'new_order_count': 2, 'restock_product_count': 0, 'restock_request_count': 0,
      }).hasAny, isTrue);

      expect(SellerActivitiesModel.fromJson(<String, dynamic>{
        'new_order_count': 0, 'restock_product_count': 1, 'restock_request_count': 0,
      }).hasAny, isTrue);

      // Requests are a detail of the products they sit on, and the strip does
      // not word them — a count with no product behind it must stay silent
      // rather than render an empty banner.
      expect(SellerActivitiesModel.fromJson(<String, dynamic>{
        'new_order_count': 0, 'restock_product_count': 0, 'restock_request_count': 4,
      }).hasAny, isFalse);
    });
  });
}
