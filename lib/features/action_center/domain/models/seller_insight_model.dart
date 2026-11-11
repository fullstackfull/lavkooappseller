/// One thing waiting for the seller.
///
/// An insight is produced from a real record — a product missing images, an
/// order approaching its deadline — and carries the thing it is about, so the
/// list can open it. "Three products have problems" is not something a seller
/// can act on; "three listings are missing images, open them" is.
class SellerInsightModel {
  final int id;
  final String type;
  final String severity;

  /// A translation key. The server sends the key rather than a sentence so the
  /// seller reads it in their own language, chosen on the phone rather than at
  /// the moment the insight was written.
  final String title;

  /// Data, not a key — usually the name of the product or order concerned.
  final String? body;

  final String? entityType;
  final String? entityId;
  final double? metric;
  final double? impact;
  final String? actionKey;
  final Map<String, dynamic> actionParams;

  /// Critical standing cannot be hidden. A seller may choose not to act on a
  /// suggestion, but not to hide that their account is at risk.
  final bool dismissible;

  final String? createdAt;

  const SellerInsightModel({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    this.body,
    this.entityType,
    this.entityId,
    this.metric,
    this.impact,
    this.actionKey,
    this.actionParams = const <String, dynamic>{},
    this.dismissible = true,
    this.createdAt,
  });

  factory SellerInsightModel.fromJson(Map<String, dynamic> json) => SellerInsightModel(
        id: _int(json['id']),
        type: json['type']?.toString() ?? '',
        severity: json['severity']?.toString() ?? 'low',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString(),
        entityType: json['entity_type']?.toString(),
        entityId: json['entity_id']?.toString(),
        metric: _double(json['metric']),
        impact: _double(json['impact']),
        actionKey: json['action_key']?.toString(),
        actionParams: json['action_params'] is Map
            ? Map<String, dynamic>.from(json['action_params'] as Map)
            : const <String, dynamic>{},
        dismissible: json['dismissible'] != false,
        createdAt: json['created_at']?.toString(),
      );

  int? get entityIdAsInt => int.tryParse(entityId ?? '');

  static int _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static double? _double(dynamic value) =>
      value == null ? null : (value is num ? value.toDouble() : double.tryParse(value.toString()));
}

/// The whole list, plus how many of each severity are open.
///
/// The counts come from the server rather than from the length of this list,
/// because the list is capped and filtered and the badge must not be.
class ActionCenterModel {
  final Map<String, int> counts;
  final List<String> severities;
  final List<SellerInsightModel> insights;

  const ActionCenterModel({
    required this.counts,
    required this.severities,
    required this.insights,
  });

  factory ActionCenterModel.fromJson(Map<String, dynamic> json) => ActionCenterModel(
        counts: json['counts'] is Map
            ? Map<String, dynamic>.from(json['counts'] as Map)
                .map((key, value) => MapEntry(key, SellerInsightModel._int(value)))
            : const <String, int>{},
        severities: json['severities'] is List
            ? List<String>.from((json['severities'] as List).map((value) => value.toString()))
            : const <String>['critical', 'high', 'medium', 'low'],
        insights: json['insights'] is List
            ? (json['insights'] as List)
                .whereType<Map>()
                .map((row) => SellerInsightModel.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const <SellerInsightModel>[],
      );

  int get total => counts['total'] ?? 0;

  /// What the badge should say. Nothing at all when nothing is waiting — an
  /// empty Action Center is a good day, not an empty state to decorate.
  int get urgentCount => (counts['critical'] ?? 0) + (counts['high'] ?? 0);
}
