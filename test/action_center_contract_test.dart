import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/models/seller_insight_model.dart';

/// Captured verbatim from a running backend
/// (`/api/v3/seller/seller-center/action-center`) against a real database, so
/// the parsing is pinned to what the API actually sends.
///
/// Two details in that payload are easy to get wrong and both matter: `title` is
/// a translation key rather than a sentence, and `entity_id` arrives as a string
/// even though it names a numeric record. A model that assumed either the other
/// way round would render a raw key at the seller or fail to open the product
/// the insight is about.
void main() {
  const String liveActionCenter = '''
  {"counts":{"critical":0,"high":0,"medium":1,"low":0,"total":1},
   "severities":["critical","high","medium","low"],
   "insights":[{"id":2,"type":"LISTING_QUALITY","severity":"medium",
     "title":"insight_listing_incomplete","body":"MEDEE Serum Vitzmin C",
     "entity_type":"product","entity_id":"4","metric":48,"impact":null,
     "action_key":"open_product",
     "action_params":{"product_id":4,"missing":["description","details","brand","meta"],"score":48},
     "dismissible":true,"created_at":"2026-08-24T01:02:14.000000Z"}]}''';

  group('action centre contract', () {
    test('parses the live payload', () {
      final ActionCenterModel actions = ActionCenterModel.fromJson(jsonDecode(liveActionCenter));

      expect(actions.total, 1);
      expect(actions.counts['medium'], 1);
      expect(actions.severities, ['critical', 'high', 'medium', 'low']);
      expect(actions.insights, hasLength(1));

      final SellerInsightModel insight = actions.insights.first;
      expect(insight.id, 2);
      expect(insight.type, 'LISTING_QUALITY');
      // A key, not a sentence — the seller reads it in the language their phone
      // is set to, not the one the insight happened to be written in.
      expect(insight.title, 'insight_listing_incomplete');
      expect(insight.body, 'MEDEE Serum Vitzmin C');
      expect(insight.metric, 48);
      expect(insight.impact, isNull);
      expect(insight.actionKey, 'open_product');
      expect(insight.actionParams['product_id'], 4);
      expect(insight.dismissible, isTrue);
    });

    test('a numeric record sent as a string still opens', () {
      final ActionCenterModel actions = ActionCenterModel.fromJson(jsonDecode(liveActionCenter));

      // `entity_id` comes back quoted. Read as a string it would never match a
      // product id, and the insight's whole purpose is to be openable.
      expect(actions.insights.first.entityId, '4');
      expect(actions.insights.first.entityIdAsInt, 4);
    });

    test('the badge counts what is urgent, not what is listed', () {
      final ActionCenterModel actions = ActionCenterModel.fromJson(jsonDecode('''
      {"counts":{"critical":2,"high":3,"medium":9,"low":4,"total":18},"severities":[],"insights":[]}'''));

      // The list is capped and filtered; the badge must not be. Critical and high
      // together are what deserve a number on the home screen.
      expect(actions.urgentCount, 5);
      expect(actions.total, 18);
    });

    test('nothing waiting is a real answer, not a broken payload', () {
      final ActionCenterModel actions = ActionCenterModel.fromJson(jsonDecode('''
      {"counts":{"critical":0,"high":0,"medium":0,"low":0,"total":0},
       "severities":["critical","high","medium","low"],"insights":[]}'''));

      expect(actions.insights, isEmpty);
      expect(actions.total, 0);
      expect(actions.urgentCount, 0);
    });

    test('a critical insight cannot be hidden', () {
      final ActionCenterModel actions = ActionCenterModel.fromJson(jsonDecode('''
      {"counts":{"total":1},"severities":[],
       "insights":[{"id":9,"type":"LISTING_QUALITY","severity":"critical",
         "title":"insight_product_rejected","body":"A product",
         "entity_type":"product","entity_id":"7","action_key":"open_product",
         "action_params":{"product_id":7,"reason_codes":["missing_image"],"note":"Blurred"},
         "dismissible":false}]}'''));

      final SellerInsightModel insight = actions.insights.first;
      // A seller may choose not to act on a suggestion, but not to hide that
      // their account is at risk.
      expect(insight.dismissible, isFalse);
      expect(insight.actionParams['reason_codes'], ['missing_image']);
      expect(insight.actionParams['note'], 'Blurred');
    });

    test('survives a payload with the sections missing', () {
      final ActionCenterModel actions = ActionCenterModel.fromJson(<String, dynamic>{});

      expect(actions.insights, isEmpty);
      expect(actions.total, 0);
      // Falls back to the four levels the filter row draws, so an incomplete
      // response leaves the chips in place rather than blanking them.
      expect(actions.severities, ['critical', 'high', 'medium', 'low']);
    });
  });
}
