import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/control_tower/domain/models/control_tower_models.dart';

/// Captured verbatim from a running backend
/// (`/api/v3/seller/seller-center/control-tower`) against a real database.
///
/// Two things the app must not undo. The server sends its sections in the order
/// they should be read — top to bottom by somebody deciding what to do next —
/// and an empty section is a real answer that must not be rendered as a heading
/// with nothing under it. And a day-over-day percentage against a day with
/// nothing in it comes back null on purpose; turning that into a number on the
/// client would undo the point of it being null.
void main() {
  const String liveTower = '''
  {"counts":{"critical":0,"high":2,"medium":2,"low":0,"total":4},
   "sections":{
     "critical_now":{"count":0,"affected":0,"issues":[]},
     "needs_action_today":{"count":0,"affected":0,"issues":[]},
     "sla_risk":{"count":1,"affected":1,"issues":[
       {"id":12,"type":"ORDER_STUCK","category":"orders","severity":"high","status":"open",
        "title":"insight_order_stuck","body":"#900001","entity_type":"order","entity_id":"900001",
        "affected_count":1,"impact":200,"impact_score":65,"due_at":null,"is_overdue":false,
        "escalation_level":0,"action_key":"open_order","action_params":{"order_id":900001},
        "dismissible":true,"first_detected_at":"2026-08-24T09:00:00.000000Z",
        "resolved_at":null,"resolution_type":null}]},
     "fulfillment_exceptions":{"count":0,"affected":0,"issues":[]},
     "returns_requiring_action":{"count":0,"affected":0,"issues":[]},
     "financial_exceptions":{"count":1,"affected":1,"issues":[]},
     "inventory_risk":{"count":1,"affected":37,"issues":[]},
     "catalog_and_pricing":{"count":1,"affected":1,"issues":[]},
     "recently_auto_resolved":{"count":0,"affected":0,"issues":[]}},
   "health":{"orders":{"state":"degraded","open":1,"affected":1},
     "inventory":{"state":"watch","open":1,"affected":37},
     "catalog":{"state":"watch","open":1,"affected":1},
     "pricing":{"state":"healthy","open":0,"affected":0},
     "returns":{"state":"healthy","open":0,"affected":0},
     "shipping":{"state":"healthy","open":0,"affected":0},
     "finance":{"state":"degraded","open":1,"affected":1},
     "integrations":{"state":"healthy","open":0,"affected":0}}}''';

  const String liveBriefing = '''
  {"date":"2026-08-24",
   "today":{"orders":0,"revenue":0,"cancelled":0,"returned":0},
   "previous_day":{"orders":0,"revenue":0,"cancelled":0,"returned":0},
   "change":{"orders":null,"revenue":null,"cancelled":null,"returned":null},
   "waiting":{"awaiting_shipment":1,"sla_at_risk":1,"returns_to_answer":0,"low_stock_products":1},
   "issues":{"critical":0,"due_today":0,"total":4,"affected":4},
   "balance":{"currency":"SYP","pending":0,"withdrawable":398}}''';

  group('control tower contract', () {
    test('parses the live payload', () {
      final ControlTowerModel tower = ControlTowerModel.fromJson(jsonDecode(liveTower));

      expect(tower.total, 4);
      expect(tower.critical, 0);
      expect(tower.sections, hasLength(9));
      expect(tower.health, hasLength(8));
    });

    test('empty sections are not rendered', () {
      final ControlTowerModel tower = ControlTowerModel.fromJson(jsonDecode(liveTower));

      // An empty heading is the screen taking up space to say nothing, and a seller
      // learns to scroll past headings.
      expect(tower.populated.map((section) => section.key).toList(),
          ['sla_risk', 'financial_exceptions', 'inventory_risk', 'catalog_and_pricing']);
    });

    test('the reading order the server chose survives parsing', () {
      final ControlTowerModel tower = ControlTowerModel.fromJson(jsonDecode(liveTower));

      // Critical first, then what is due today, then the domains. Re-sorting here —
      // alphabetically, say — would put "catalog_and_pricing" above "critical_now".
      expect(tower.sections.first.key, 'critical_now');
      expect(tower.sections[1].key, 'needs_action_today');
      expect(tower.sections.last.key, 'recently_auto_resolved');
    });

    test('a section carries what it is about, not only how many rows', () {
      final ControlTowerModel tower = ControlTowerModel.fromJson(jsonDecode(liveTower));
      final TowerSectionModel inventory =
          tower.sections.firstWhere((section) => section.key == 'inventory_risk');

      // "37 products require action" is the sentence. "1 issue" is not.
      expect(inventory.count, 1);
      expect(inventory.affected, 37);
    });

    test('an issue carries its deadline, its escalation and what it is about', () {
      final ControlTowerModel tower = ControlTowerModel.fromJson(jsonDecode(liveTower));
      final IssueModel issue =
          tower.sections.firstWhere((section) => section.key == 'sla_risk').issues.single;

      expect(issue.type, 'ORDER_STUCK');
      expect(issue.impactScore, 65);
      expect(issue.entityIdAsInt, 900001);
      expect(issue.isOverdue, isFalse);
      expect(issue.wasEscalated, isFalse);
      expect(issue.actionParams['order_id'], 900001);
    });

    test('an escalated issue says so', () {
      final IssueModel issue = IssueModel.fromJson(jsonDecode(
          '{"id":3,"type":"X","severity":"critical","status":"open","title":"t","escalation_level":2,"is_overdue":true}'));

      // A severity that changed on its own needs a reason attached, or a seller sees a
      // problem they remember as medium sitting under critical with no explanation.
      expect(issue.wasEscalated, isTrue);
      expect(issue.isOverdue, isTrue);
    });

    test('healthy means nothing detected, and is distinguishable from a domain with issues', () {
      final ControlTowerModel tower = ControlTowerModel.fromJson(jsonDecode(liveTower));
      final Map<String, DomainHealthModel> byDomain = {
        for (final domain in tower.health) domain.domain: domain,
      };

      expect(byDomain['returns']!.isHealthy, isTrue);
      expect(byDomain['finance']!.isHealthy, isFalse);
      expect(byDomain['inventory']!.affected, 37);
    });

    test('a comparison the server refused to make stays refused', () {
      final DailyBriefingModel briefing = DailyBriefingModel.fromJson(jsonDecode(liveBriefing));

      // Null is deliberate: both days had nothing, and a percentage there would be
      // invented. Defaulting it to zero on the client would read as "no change".
      expect(briefing.ordersChange, isNull);
      expect(briefing.revenueChange, isNull);
    });

    test('the briefing carries the queue and the balance', () {
      final DailyBriefingModel briefing = DailyBriefingModel.fromJson(jsonDecode(liveBriefing));

      expect(briefing.date, '2026-08-24');
      expect(briefing.awaitingShipment, 1);
      expect(briefing.slaAtRisk, 1);
      expect(briefing.withdrawable, 398);
      expect(briefing.currency, 'SYP');
    });

    test('survives a payload with the sections missing', () {
      expect(ControlTowerModel.fromJson(<String, dynamic>{}).sections, isEmpty);
      expect(ControlTowerModel.fromJson(<String, dynamic>{}).total, 0);
      expect(DailyBriefingModel.fromJson(<String, dynamic>{}).orders, 0);
    });
  });
}
