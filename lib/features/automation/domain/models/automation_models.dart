/// The seller's rules, and the record of what they did.
///
/// Deliberately close to the API's own shape. A rule is a small thing with a
/// lot of state — when it last ran, when it last did anything, whether it has
/// been stopped and why — and reshaping it on the way in would mean the screen
/// and the server disagreeing about what "stopped" means.
class AutomationRuleModel {
  final int id;
  final String name;
  final String trigger;
  final String action;
  final Map<String, dynamic> triggerSettings;
  final Map<String, dynamic> actionSettings;

  /// Which part of the catalogue this rule may touch: brand, category and
  /// product id lists. Empty means the whole shop, which is what every rule
  /// written before scope existed meant.
  final Map<String, dynamic> scope;
  final String status;
  final int maxActionsPerRun;
  final int cooldownMinutes;
  final int runCount;
  final int appliedCount;
  final int consecutiveFailures;
  final String? lastRunAt;
  final String? lastFiredAt;
  final String? suspendedAt;
  final String? suspensionReason;
  final String? suspendedBy;

  const AutomationRuleModel({
    required this.id,
    required this.name,
    required this.trigger,
    required this.action,
    required this.triggerSettings,
    required this.actionSettings,
    required this.scope,
    required this.status,
    required this.maxActionsPerRun,
    required this.cooldownMinutes,
    required this.runCount,
    required this.appliedCount,
    required this.consecutiveFailures,
    this.lastRunAt,
    this.lastFiredAt,
    this.suspendedAt,
    this.suspensionReason,
    this.suspendedBy,
  });

  bool get isSuspended => status == 'suspended';
  bool get isActive => status == 'active';

  /// Stopped by the marketplace rather than by the breaker. The seller can read
  /// why and fix the rule, but restarting it is not theirs to do — offering the
  /// button would mean offering an action the server will refuse.
  bool get isStoppedByMarketplace => isSuspended && suspendedBy == 'marketplace';

  /// A rule that keeps running and never does anything is worth a second look.
  /// Not an error — a stock rule with nothing out of stock is working — but the
  /// screen says so rather than showing two numbers and leaving it to the eye.
  bool get hasNeverActed => runCount > 0 && appliedCount == 0;

  /// Pointed at part of the shop rather than all of it.
  bool get isNarrowed => scope.values.any((value) => value is List && value.isNotEmpty);

  static AutomationRuleModel fromJson(Map<String, dynamic> json) => AutomationRuleModel(
        id: _int(json['id']),
        name: json['name']?.toString() ?? '',
        trigger: json['trigger']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        triggerSettings: _map(json['trigger_settings']),
        actionSettings: _map(json['action_settings']),
        scope: _map(json['scope']),
        status: json['status']?.toString() ?? 'active',
        maxActionsPerRun: _int(json['max_actions_per_run']),
        cooldownMinutes: _int(json['cooldown_minutes']),
        runCount: _int(json['run_count']),
        appliedCount: _int(json['applied_count']),
        consecutiveFailures: _int(json['consecutive_failures']),
        lastRunAt: json['last_run_at']?.toString(),
        lastFiredAt: json['last_fired_at']?.toString(),
        suspendedAt: json['suspended_at']?.toString(),
        suspensionReason: json['suspension_reason']?.toString(),
        suspendedBy: json['suspended_by']?.toString(),
      );
}

/// One evaluation of one rule.
class AutomationRunModel {
  final int id;
  final String outcome;
  final int matchedCount;
  final int appliedCount;
  final int skippedCount;
  final int failedCount;
  final String? message;
  final String? finishedAt;

  const AutomationRunModel({
    required this.id,
    required this.outcome,
    required this.matchedCount,
    required this.appliedCount,
    required this.skippedCount,
    required this.failedCount,
    this.message,
    this.finishedAt,
  });

  static AutomationRunModel fromJson(Map<String, dynamic> json) => AutomationRunModel(
        id: _int(json['id']),
        outcome: json['outcome']?.toString() ?? '',
        matchedCount: _int(json['matched_count']),
        appliedCount: _int(json['applied_count']),
        skippedCount: _int(json['skipped_count']),
        failedCount: _int(json['failed_count']),
        message: json['message']?.toString(),
        finishedAt: json['finished_at']?.toString(),
      );
}

/// One thing a rule did, or declined to do, to one record.
class AutomationActivityModel {
  final int id;
  final int ruleId;
  final String action;
  final int subjectId;
  final String? subjectLabel;
  final String status;
  final String? reason;
  final Map<String, dynamic> before;
  final Map<String, dynamic> after;
  final bool revertible;
  final String? revertedAt;
  final String? createdAt;

  const AutomationActivityModel({
    required this.id,
    required this.ruleId,
    required this.action,
    required this.subjectId,
    required this.status,
    required this.before,
    required this.after,
    required this.revertible,
    this.subjectLabel,
    this.reason,
    this.revertedAt,
    this.createdAt,
  });

  static AutomationActivityModel fromJson(Map<String, dynamic> json) => AutomationActivityModel(
        id: _int(json['id']),
        ruleId: _int(json['rule_id']),
        action: json['action']?.toString() ?? '',
        subjectId: _int(json['subject_id']),
        subjectLabel: json['subject_label']?.toString(),
        status: json['status']?.toString() ?? '',
        reason: json['reason']?.toString(),
        before: _map(json['before']),
        after: _map(json['after']),
        revertible: json['revertible'] == true,
        revertedAt: json['reverted_at']?.toString(),
        createdAt: json['created_at']?.toString(),
      );
}

/// What this rule would do right now, without doing it.
class AutomationPreviewModel {
  final int matched;
  final bool capped;
  final List<AutomationPreviewSubject> subjects;

  const AutomationPreviewModel({required this.matched, required this.capped, required this.subjects});

  static AutomationPreviewModel fromJson(Map<String, dynamic> json) => AutomationPreviewModel(
        matched: _int(json['matched']),
        capped: json['capped'] == true,
        subjects: (json['subjects'] as List?)
                ?.whereType<Map>()
                .map((e) => AutomationPreviewSubject.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const <AutomationPreviewSubject>[],
      );
}

class AutomationPreviewSubject {
  final int subjectId;
  final String? label;
  final bool willApply;
  final String? reason;

  const AutomationPreviewSubject({
    required this.subjectId,
    required this.willApply,
    this.label,
    this.reason,
  });

  static AutomationPreviewSubject fromJson(Map<String, dynamic> json) => AutomationPreviewSubject(
        subjectId: _int(json['subject_id']),
        label: json['label']?.toString(),
        willApply: json['will_apply'] == true,
        reason: json['reason']?.toString(),
      );
}

/// What a rule can be built out of, as the server describes it.
///
/// Read from the server rather than hard-coded, so a trigger added on the
/// server appears in the form without shipping a new build.
class AutomationCatalogueModel {
  final List<AutomationTriggerOption> triggers;
  final List<AutomationActionOption> actions;

  /// The scope's own fields, described the same way a trigger's settings are,
  /// so the form renders them with the same code.
  final List<AutomationSettingField> scope;

  const AutomationCatalogueModel({
    required this.triggers,
    required this.actions,
    required this.scope,
  });

  static AutomationCatalogueModel fromJson(Map<String, dynamic> json) => AutomationCatalogueModel(
        triggers: (json['triggers'] as List?)
                ?.whereType<Map>()
                .map((e) => AutomationTriggerOption.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const <AutomationTriggerOption>[],
        actions: (json['actions'] as List?)
                ?.whereType<Map>()
                .map((e) => AutomationActionOption.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const <AutomationActionOption>[],
        scope: AutomationSettingField.listFrom(json['scope']),
      );

  AutomationTriggerOption? trigger(String key) {
    for (final AutomationTriggerOption option in triggers) {
      if (option.key == key) return option;
    }
    return null;
  }

  AutomationActionOption? action(String key) {
    for (final AutomationActionOption option in actions) {
      if (option.key == key) return option;
    }
    return null;
  }
}

class AutomationTriggerOption {
  final String key;
  final String subjectType;
  final List<String> settings;
  final List<String> requiredSettings;
  final List<AutomationSettingField> fields;
  final List<String> actions;

  const AutomationTriggerOption({
    required this.key,
    required this.subjectType,
    required this.settings,
    required this.requiredSettings,
    required this.fields,
    required this.actions,
  });

  static AutomationTriggerOption fromJson(Map<String, dynamic> json) => AutomationTriggerOption(
        key: json['key']?.toString() ?? '',
        subjectType: json['subject_type']?.toString() ?? '',
        settings: _strings(json['settings']),
        requiredSettings: _strings(json['required_settings']),
        fields: AutomationSettingField.listFrom(json['fields'], json['settings']),
        actions: _strings(json['actions']),
      );
}

class AutomationActionOption {
  final String key;
  final String permission;
  final List<String> settings;
  final List<String> requiredSettings;
  final List<AutomationSettingField> fields;
  final AutomationClassification classification;

  const AutomationActionOption({
    required this.key,
    required this.permission,
    required this.settings,
    required this.requiredSettings,
    required this.fields,
    required this.classification,
  });

  static AutomationActionOption fromJson(Map<String, dynamic> json) => AutomationActionOption(
        key: json['key']?.toString() ?? '',
        permission: json['permission']?.toString() ?? '',
        settings: _strings(json['settings']),
        requiredSettings: _strings(json['required_settings']),
        fields: AutomationSettingField.listFrom(json['fields'], json['settings']),
        classification: AutomationClassification.fromJson(json['classification']),
      );
}

/// How much thought an action needs before it runs unattended.
///
/// The server's answer, decided from what the server knows: an action this
/// person may not perform, or one whose changes cannot be put back, is not
/// offered for automation and says why. The app never works this out itself —
/// a badge the client invents is a badge the server has not agreed to.
class AutomationClassification {
  final String type;
  final String? reason;

  const AutomationClassification({required this.type, this.reason});

  bool get isSafe => type == 'safe';

  static AutomationClassification fromJson(dynamic json) {
    if (json is! Map) {
      // An older server does not send one. Treated as safe, because that is how
      // every action behaved before the classification existed.
      return const AutomationClassification(type: 'safe');
    }

    return AutomationClassification(
      type: json['class']?.toString() ?? 'safe',
      reason: json['reason']?.toString(),
    );
  }
}

/// The form control one setting needs, as the server describes it.
///
/// The description is derived server-side from the very validation rule that
/// will judge the value, so a control cannot offer what the server would
/// refuse — and the app stops needing to know that `discount_type` happens to
/// be the one setting that is not a number.
class AutomationSettingField {
  final String key;
  final String type;
  final bool required;
  final double? min;
  final double? max;
  final List<String> options;

  const AutomationSettingField({
    required this.key,
    required this.type,
    required this.required,
    required this.options,
    this.min,
    this.max,
  });

  bool get isChoice => type == 'choice';

  bool get isIdList => type == 'id_list';

  bool get isNumeric => type == 'integer' || type == 'decimal';

  bool get allowsDecimals => type == 'decimal';

  /// The keys the older server sends are bare strings with no description. They
  /// still have to render something, so they fall back to a free-text field
  /// rather than disappearing from the form.
  static List<AutomationSettingField> listFrom(dynamic fields, [dynamic fallbackKeys]) {
    if (fields is List) {
      return fields
          .whereType<Map>()
          .map((e) => AutomationSettingField.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return _strings(fallbackKeys)
        .map((key) => AutomationSettingField(
              key: key,
              type: 'text',
              required: false,
              options: const <String>[],
            ))
        .toList();
  }

  static AutomationSettingField fromJson(Map<String, dynamic> json) => AutomationSettingField(
        key: json['key']?.toString() ?? '',
        type: json['type']?.toString() ?? 'text',
        required: json['required'] == true,
        min: _decimal(json['min']),
        max: _decimal(json['max']),
        options: _strings(json['options']),
      );
}

double? _decimal(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// An empty settings bag arrives as `[]` from PHP and `{}` once it holds
/// anything. Both mean the same thing here.
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<String> _strings(dynamic value) =>
    value is List ? value.map((e) => e.toString()).toList() : const <String>[];
