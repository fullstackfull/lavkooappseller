/// One operational issue, as the control tower describes it.
///
/// `affectedCount` is the number a seller acts on. "37 products require action"
/// is a sentence; "1 issue" is not, and the difference is the whole point of
/// grouping a finding that is true of many rows into one issue.
class IssueModel {
  final int id;
  final String type;
  final String? category;
  final String severity;
  final String status;

  /// A translation key, not a sentence.
  final String title;
  final String? body;

  final String? entityType;
  final String? entityId;
  final int affectedCount;
  final double? impact;
  final int impactScore;
  final String? dueAt;
  final bool isOverdue;
  final int escalationLevel;
  final String? actionKey;
  final Map<String, dynamic> actionParams;

  /// Critical standing cannot be hidden: a seller may decline to act, not to be
  /// told.
  final bool dismissible;

  final String? firstDetectedAt;
  final String? resolvedAt;
  final String? resolutionType;

  const IssueModel({
    required this.id,
    this.type = '',
    this.category,
    this.severity = 'medium',
    this.status = 'open',
    this.title = '',
    this.body,
    this.entityType,
    this.entityId,
    this.affectedCount = 1,
    this.impact,
    this.impactScore = 0,
    this.dueAt,
    this.isOverdue = false,
    this.escalationLevel = 0,
    this.actionKey,
    this.actionParams = const <String, dynamic>{},
    this.dismissible = true,
    this.firstDetectedAt,
    this.resolvedAt,
    this.resolutionType,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) => IssueModel(
        id: _int(json['id']) ?? 0,
        type: json['type']?.toString() ?? '',
        category: json['category']?.toString(),
        severity: json['severity']?.toString() ?? 'medium',
        status: json['status']?.toString() ?? 'open',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString(),
        entityType: json['entity_type']?.toString(),
        entityId: json['entity_id']?.toString(),
        affectedCount: _int(json['affected_count']) ?? 1,
        impact: _double(json['impact']),
        impactScore: _int(json['impact_score']) ?? 0,
        dueAt: json['due_at']?.toString(),
        isOverdue: json['is_overdue'] == true,
        escalationLevel: _int(json['escalation_level']) ?? 0,
        actionKey: json['action_key']?.toString(),
        actionParams: json['action_params'] is Map
            ? Map<String, dynamic>.from(json['action_params'] as Map)
            : const <String, dynamic>{},
        dismissible: json['dismissible'] != false,
        firstDetectedAt: json['first_detected_at']?.toString(),
        resolvedAt: json['resolved_at']?.toString(),
        resolutionType: json['resolution_type']?.toString(),
      );

  int? get entityIdAsInt => int.tryParse(entityId ?? '');

  /// Promoted by the platform because nobody answered it. Worth showing: a
  /// severity that changed on its own needs to say so.
  bool get wasEscalated => escalationLevel > 0;

  static int? _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  static double? _double(dynamic value) =>
      value == null ? null : (value is num ? value.toDouble() : double.tryParse(value.toString()));
}

/// One heading in the tower: how many, what they are about, and the first few.
class TowerSectionModel {
  final String key;
  final int count;
  final int affected;
  final List<IssueModel> issues;

  const TowerSectionModel({
    required this.key,
    this.count = 0,
    this.affected = 0,
    this.issues = const <IssueModel>[],
  });

  factory TowerSectionModel.fromJson(String key, Map<String, dynamic> json) => TowerSectionModel(
        key: key,
        count: IssueModel._int(json['count']) ?? 0,
        affected: IssueModel._int(json['affected']) ?? 0,
        issues: json['issues'] is List
            ? (json['issues'] as List)
                .whereType<Map>()
                .map((row) => IssueModel.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const <IssueModel>[],
      );

  bool get isEmpty => count == 0;
}

/// How one domain is doing, from the issues standing in it.
class DomainHealthModel {
  final String domain;

  /// `healthy` means nothing was detected — a narrower claim than "fine".
  final String state;
  final int open;
  final int affected;

  const DomainHealthModel({required this.domain, this.state = 'healthy', this.open = 0, this.affected = 0});

  factory DomainHealthModel.fromJson(String domain, Map<String, dynamic> json) => DomainHealthModel(
        domain: domain,
        state: json['state']?.toString() ?? 'healthy',
        open: IssueModel._int(json['open']) ?? 0,
        affected: IssueModel._int(json['affected']) ?? 0,
      );

  bool get isHealthy => state == 'healthy';
}

class ControlTowerModel {
  final Map<String, int> counts;
  final List<TowerSectionModel> sections;
  final List<DomainHealthModel> health;

  const ControlTowerModel({
    this.counts = const <String, int>{},
    this.sections = const <TowerSectionModel>[],
    this.health = const <DomainHealthModel>[],
  });

  factory ControlTowerModel.fromJson(Map<String, dynamic> json) => ControlTowerModel(
        counts: json['counts'] is Map
            ? Map<String, dynamic>.from(json['counts'] as Map)
                .map((key, value) => MapEntry(key, IssueModel._int(value) ?? 0))
            : const <String, int>{},
        // Order is preserved from the server, which sends them in the order they
        // should be read — top to bottom by somebody deciding what to do next.
        sections: json['sections'] is Map
            ? Map<String, dynamic>.from(json['sections'] as Map)
                .entries
                .where((entry) => entry.value is Map)
                .map((entry) => TowerSectionModel.fromJson(entry.key, Map<String, dynamic>.from(entry.value as Map)))
                .toList()
            : const <TowerSectionModel>[],
        health: json['health'] is Map
            ? Map<String, dynamic>.from(json['health'] as Map)
                .entries
                .where((entry) => entry.value is Map)
                .map((entry) => DomainHealthModel.fromJson(entry.key, Map<String, dynamic>.from(entry.value as Map)))
                .toList()
            : const <DomainHealthModel>[],
      );

  int get total => counts['total'] ?? 0;
  int get critical => counts['critical'] ?? 0;

  /// Sections with nothing in them are not rendered. An empty heading is the
  /// platform taking up space to say nothing.
  List<TowerSectionModel> get populated => sections.where((section) => !section.isEmpty).toList();
}

/// The seller's day, counted rather than estimated.
class DailyBriefingModel {
  final String? date;
  final int orders;
  final double revenue;
  final int cancelled;
  final int returned;

  final int previousOrders;
  final double previousRevenue;

  /// Null where the previous day had nothing to compare against. Reporting a
  /// percentage there would be inventing one.
  final double? ordersChange;
  final double? revenueChange;

  final int awaitingShipment;
  final int slaAtRisk;
  final int returnsToAnswer;
  final int lowStockProducts;

  final int criticalIssues;
  final int dueToday;

  final String? currency;
  final double pending;
  final double withdrawable;

  const DailyBriefingModel({
    this.date,
    this.orders = 0,
    this.revenue = 0,
    this.cancelled = 0,
    this.returned = 0,
    this.previousOrders = 0,
    this.previousRevenue = 0,
    this.ordersChange,
    this.revenueChange,
    this.awaitingShipment = 0,
    this.slaAtRisk = 0,
    this.returnsToAnswer = 0,
    this.lowStockProducts = 0,
    this.criticalIssues = 0,
    this.dueToday = 0,
    this.currency,
    this.pending = 0,
    this.withdrawable = 0,
  });

  factory DailyBriefingModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) =>
        json[key] is Map ? Map<String, dynamic>.from(json[key] as Map) : <String, dynamic>{};

    final today = section('today');
    final previous = section('previous_day');
    final change = section('change');
    final waiting = section('waiting');
    final issues = section('issues');
    final balance = section('balance');

    return DailyBriefingModel(
      date: json['date']?.toString(),
      orders: IssueModel._int(today['orders']) ?? 0,
      revenue: IssueModel._double(today['revenue']) ?? 0,
      cancelled: IssueModel._int(today['cancelled']) ?? 0,
      returned: IssueModel._int(today['returned']) ?? 0,
      previousOrders: IssueModel._int(previous['orders']) ?? 0,
      previousRevenue: IssueModel._double(previous['revenue']) ?? 0,
      ordersChange: IssueModel._double(change['orders']),
      revenueChange: IssueModel._double(change['revenue']),
      awaitingShipment: IssueModel._int(waiting['awaiting_shipment']) ?? 0,
      slaAtRisk: IssueModel._int(waiting['sla_at_risk']) ?? 0,
      returnsToAnswer: IssueModel._int(waiting['returns_to_answer']) ?? 0,
      lowStockProducts: IssueModel._int(waiting['low_stock_products']) ?? 0,
      criticalIssues: IssueModel._int(issues['critical']) ?? 0,
      dueToday: IssueModel._int(issues['due_today']) ?? 0,
      currency: balance['currency']?.toString(),
      pending: IssueModel._double(balance['pending']) ?? 0,
      withdrawable: IssueModel._double(balance['withdrawable']) ?? 0,
    );
  }
}
