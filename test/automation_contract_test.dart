import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/automation/domain/models/automation_models.dart';

/// Captured verbatim from a running backend
/// (`/api/v3/seller/seller-center/automation/...`) against a real database.
///
/// The payloads here carry three things the app must not quietly undo. An empty
/// settings bag arrives as `[]` from PHP and as `{}` once it holds anything, and
/// both mean "no settings" — a client that only handled one of them would crash
/// on a rule with no action settings, which is most of them. A capped run
/// reports what it *would* have touched with nothing applied, and reading that
/// as a successful run of that size would be exactly backwards. And the
/// catalogue says which actions each trigger accepts; the form is built from
/// that rather than from a list in the app.
void main() {
  const String liveCatalogue = '''
  {"triggers":[
    {"key":"out_of_stock","subject_type":"product","settings":["threshold"],
     "required_settings":[],"actions":["hide_listing","publish_listing","set_discount"]},
    {"key":"low_stock","subject_type":"product","settings":["threshold"],
     "required_settings":["threshold"],"actions":["hide_listing","publish_listing","set_discount"]},
    {"key":"restocked_after_automation_hid_it","subject_type":"product","settings":["threshold"],
     "required_settings":[],"actions":["hide_listing","publish_listing","set_discount"]},
    {"key":"stale_stock","subject_type":"product","settings":["days"],
     "required_settings":["days"],"actions":["hide_listing","publish_listing","set_discount"]}],
   "actions":[
    {"key":"hide_listing","permission":"products.manage","subject_types":["product"],
     "settings":[],"required_settings":[]},
    {"key":"publish_listing","permission":"products.manage","subject_types":["product"],
     "settings":[],"required_settings":[]},
    {"key":"set_discount","permission":"products.manage","subject_types":["product"],
     "settings":["discount_type","discount_value","min_price_after_discount"],
     "required_settings":["discount_type","discount_value","min_price_after_discount"]}]}''';

  const String liveRule = '''
  {"id":1,"name":"Hide sold-out lines","trigger":"out_of_stock","action":"hide_listing",
   "trigger_settings":{"threshold":0},"action_settings":[],"status":"active",
   "max_actions_per_run":5,"cooldown_minutes":15,"run_count":1,"applied_count":0,
   "consecutive_failures":0,"last_run_at":"2026-08-24T04:10:59.000000Z","last_fired_at":null,
   "suspended_at":null,"suspension_reason":null,"created_at":"2026-08-24T04:10:47.000000Z"}''';

  const String liveSuspendedRule = '''
  {"id":3,"name":"Breaker check","trigger":"low_stock","action":"hide_listing",
   "trigger_settings":{"threshold":1000},"action_settings":[],"status":"suspended",
   "max_actions_per_run":1,"cooldown_minutes":15,"run_count":1,"applied_count":0,
   "consecutive_failures":0,"last_run_at":"2026-08-24T04:14:02.000000Z","last_fired_at":null,
   "suspended_at":"2026-08-24T04:14:02.000000Z",
   "suspension_reason":"automation_suspended_too_many_matches","suspended_by":"platform",
   "created_at":"2026-08-24T04:14:01.000000Z"}''';

  const String liveMarketplaceStoppedRule = '''
  {"id":4,"name":"Stopped from the panel","trigger":"low_stock","action":"hide_listing",
   "trigger_settings":{"threshold":5},"action_settings":[],"status":"suspended",
   "max_actions_per_run":5,"cooldown_minutes":15,"run_count":2,"applied_count":1,
   "consecutive_failures":0,"last_run_at":"2026-08-24T04:14:02.000000Z","last_fired_at":null,
   "suspended_at":"2026-08-24T05:02:11.000000Z",
   "suspension_reason":"automation_suspended_by_marketplace","suspended_by":"marketplace",
   "created_at":"2026-08-24T04:14:01.000000Z"}''';

  const String livePreview = '''
  {"matched":2,"capped":false,"subjects":[
    {"subject_id":4,"label":"ميدي سيروم فيتامين سي 30 مل","will_apply":true,"reason":null,
     "before":{"status":1},"after":{"status":0}},
    {"subject_id":3,"label":"ميدي هيدرا مرطب 50 مل","will_apply":true,"reason":null,
     "before":{"status":1},"after":{"status":0}}]}''';

  const String liveCappedRun = '''
  {"id":3,"outcome":"capped","matched_count":2,"applied_count":0,"skipped_count":0,
   "failed_count":0,"message":"automation_stopped_more_matches_than_allowed",
   "started_at":"2026-08-24T04:14:02.000000Z","finished_at":"2026-08-24T04:14:02.000000Z"}''';

  const String liveActivity = '''
  {"id":7,"rule_id":1,"action":"hide_listing","subject_type":"product","subject_id":4,
   "subject_label":"ميدي سيروم فيتامين سي 30 مل","status":"applied","reason":null,
   "before":{"status":1},"after":{"status":0},"revertible":true,"reverted_at":null,
   "created_at":"2026-08-24T04:20:11.000000Z"}''';

  group('automation catalogue', () {
    final AutomationCatalogueModel catalogue =
        AutomationCatalogueModel.fromJson(jsonDecode(liveCatalogue) as Map<String, dynamic>);

    test('the form is built from what the server offers, not from a list in the app', () {
      expect(catalogue.triggers.length, 4);
      expect(catalogue.actions.length, 3);
      expect(catalogue.trigger('stale_stock')!.requiredSettings, ['days']);
      expect(catalogue.action('set_discount')!.settings.length, 3);
    });

    test('a trigger names which actions it accepts', () {
      // The dropdown offers only these. Anything else the server refuses, and
      // offering it would be an invitation to be refused.
      expect(catalogue.trigger('out_of_stock')!.actions, contains('hide_listing'));
      expect(catalogue.trigger('out_of_stock')!.subjectType, 'product');
    });

    test('an unknown key is null rather than an exception', () {
      expect(catalogue.trigger('invented_by_a_typo'), isNull);
      expect(catalogue.action('invented_by_a_typo'), isNull);
    });
  });

  group('a rule', () {
    test('an empty settings bag arrives as a list and still reads as no settings', () {
      final AutomationRuleModel rule =
          AutomationRuleModel.fromJson(jsonDecode(liveRule) as Map<String, dynamic>);

      expect(rule.actionSettings, isEmpty);
      expect(rule.triggerSettings['threshold'], 0);
      expect(rule.isActive, isTrue);
      expect(rule.isSuspended, isFalse);
    });

    test('a rule that has run and never acted says so', () {
      final AutomationRuleModel rule =
          AutomationRuleModel.fromJson(jsonDecode(liveRule) as Map<String, dynamic>);

      // Not an error — a stock rule with nothing out of stock is working — but
      // the seller should not have to compare two numbers to notice.
      expect(rule.runCount, 1);
      expect(rule.appliedCount, 0);
      expect(rule.hasNeverActed, isTrue);
    });

    test('a stopped rule carries the reason it was stopped', () {
      final AutomationRuleModel rule =
          AutomationRuleModel.fromJson(jsonDecode(liveSuspendedRule) as Map<String, dynamic>);

      expect(rule.isSuspended, isTrue);
      expect(rule.isActive, isFalse);
      expect(rule.suspensionReason, 'automation_suspended_too_many_matches');
      // The breaker stopped it, so the seller may still start it again.
      expect(rule.isStoppedByMarketplace, isFalse);
    });

    test('says when it was the marketplace that stopped it, not the breaker', () {
      final AutomationRuleModel rule = AutomationRuleModel.fromJson(
          jsonDecode(liveMarketplaceStoppedRule) as Map<String, dynamic>);

      // The card hides the restart button on this, because the server refuses it.
      expect(rule.isSuspended, isTrue);
      expect(rule.isStoppedByMarketplace, isTrue);
    });
  });

  group('a preview', () {
    test('lists what would change, with the value before and after', () {
      final AutomationPreviewModel preview =
          AutomationPreviewModel.fromJson(jsonDecode(livePreview) as Map<String, dynamic>);

      expect(preview.matched, 2);
      expect(preview.capped, isFalse);
      expect(preview.subjects.first.willApply, isTrue);
      expect(preview.subjects.first.label, 'ميدي سيروم فيتامين سي 30 مل');
      expect(preview.subjects.first.reason, isNull);
    });

    test('an empty preview is a real answer', () {
      final AutomationPreviewModel preview = AutomationPreviewModel.fromJson(
          jsonDecode('{"matched":0,"capped":false,"subjects":[]}') as Map<String, dynamic>);

      expect(preview.matched, 0);
      expect(preview.subjects, isEmpty);
    });
  });

  test('a capped run applied nothing, whatever it matched', () {
    final AutomationRunModel run =
        AutomationRunModel.fromJson(jsonDecode(liveCappedRun) as Map<String, dynamic>);

    expect(run.outcome, 'capped');
    expect(run.matchedCount, 2);
    // The number that matters. Reading `matched` as "done" would report a run
    // that deliberately did nothing as a run that changed two listings.
    expect(run.appliedCount, 0);
    expect(run.message, 'automation_stopped_more_matches_than_allowed');
  });

  test('an applied change carries what it replaced and can be undone', () {
    final AutomationActivityModel activity =
        AutomationActivityModel.fromJson(jsonDecode(liveActivity) as Map<String, dynamic>);

    expect(activity.status, 'applied');
    expect(activity.before['status'], 1);
    expect(activity.after['status'], 0);
    expect(activity.revertible, isTrue);
    expect(activity.revertedAt, isNull);
  });

  test('a skipped change carries the reason and is not offered as undoable', () {
    final AutomationActivityModel activity = AutomationActivityModel.fromJson(jsonDecode('''
      {"id":8,"rule_id":2,"action":"publish_listing","subject_type":"product","subject_id":5,
       "subject_label":"A product","status":"skipped","reason":"automation_reason_not_approved",
       "before":null,"after":null,"revertible":false,"reverted_at":null,
       "created_at":"2026-08-24T04:20:11.000000Z"}''') as Map<String, dynamic>);

    expect(activity.status, 'skipped');
    expect(activity.reason, 'automation_reason_not_approved');
    expect(activity.revertible, isFalse);
    // Null before/after read as empty rather than crashing the trail.
    expect(activity.before, isEmpty);
    expect(activity.after, isEmpty);
  });
}
