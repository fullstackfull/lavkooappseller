// Who works in a shop, what they may do, and what has been done in it.

class SellerRoleModel {
  final int id;
  final String name;
  final List<String> permissions;
  final String status;
  final int staffCount;

  const SellerRoleModel({
    required this.id,
    required this.name,
    required this.permissions,
    required this.status,
    required this.staffCount,
  });

  bool get isActive => status == 'active';

  static SellerRoleModel fromJson(Map<String, dynamic> json) => SellerRoleModel(
        id: _int(json['id']),
        name: json['name']?.toString() ?? '',
        permissions: _strings(json['permissions']),
        status: json['status']?.toString() ?? 'active',
        staffCount: _int(json['staff_count']),
      );
}

class SellerStaffModel {
  final int id;
  final String name;
  final String email;
  final int? roleId;
  final String? role;
  final String status;

  /// Whether they hold a live token right now. Never the token — its value is
  /// the shop itself, and the server does not return it.
  final bool signedIn;
  final String? lastLoginAt;

  const SellerStaffModel({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.signedIn,
    this.roleId,
    this.role,
    this.lastLoginAt,
  });

  bool get isActive => status == 'active';

  static SellerStaffModel fromJson(Map<String, dynamic> json) => SellerStaffModel(
        id: _int(json['id']),
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        roleId: json['seller_role_id'] == null ? null : _int(json['seller_role_id']),
        role: json['role']?.toString(),
        status: json['status']?.toString() ?? 'active',
        signedIn: json['signed_in'] == true,
        lastLoginAt: json['last_login_at']?.toString(),
      );
}

class AccessHolderModel {
  final String type;
  final int id;
  final String? name;
  final String? role;
  final String status;
  final bool signedIn;
  final String? lastLoginAt;

  const AccessHolderModel({
    required this.type,
    required this.id,
    required this.status,
    required this.signedIn,
    this.name,
    this.role,
    this.lastLoginAt,
  });

  bool get isOwner => type == 'owner';

  static AccessHolderModel fromJson(Map<String, dynamic> json) => AccessHolderModel(
        type: json['type']?.toString() ?? 'staff',
        id: _int(json['id']),
        name: json['name']?.toString(),
        role: json['role']?.toString(),
        status: json['status']?.toString() ?? 'active',
        signedIn: json['signed_in'] == true,
        lastLoginAt: json['last_login_at']?.toString(),
      );
}

class AuditEntryModel {
  final int id;
  final String action;
  final String? actorName;
  final String? actorType;
  final String? subjectType;
  final String? subjectId;
  final String? ipAddress;
  final String? createdAt;

  const AuditEntryModel({
    required this.id,
    required this.action,
    this.actorName,
    this.actorType,
    this.subjectType,
    this.subjectId,
    this.ipAddress,
    this.createdAt,
  });

  static AuditEntryModel fromJson(Map<String, dynamic> json) => AuditEntryModel(
        id: _int(json['id']),
        action: json['action']?.toString() ?? '',
        actorName: json['actor_name']?.toString(),
        actorType: json['actor_type']?.toString(),
        subjectType: json['subject_type']?.toString(),
        subjectId: json['subject_id']?.toString(),
        ipAddress: json['ip_address']?.toString(),
        createdAt: json['created_at']?.toString(),
      );
}

class ApiKeyModel {
  final int id;
  final String name;

  /// The visible half. Enough to tell two keys apart, useless on its own.
  final String prefix;
  final List<String> scopes;
  final String? lastUsedAt;
  final String? lastUsedIp;
  final String? expiresAt;
  final String? revokedAt;
  final bool usable;

  const ApiKeyModel({
    required this.id,
    required this.name,
    required this.prefix,
    required this.scopes,
    required this.usable,
    this.lastUsedAt,
    this.lastUsedIp,
    this.expiresAt,
    this.revokedAt,
  });

  bool get neverUsed => lastUsedAt == null;

  static ApiKeyModel fromJson(Map<String, dynamic> json) => ApiKeyModel(
        id: _int(json['id']),
        name: json['name']?.toString() ?? '',
        prefix: json['prefix']?.toString() ?? '',
        scopes: _strings(json['scopes']),
        usable: json['usable'] == true,
        lastUsedAt: json['last_used_at']?.toString(),
        lastUsedIp: json['last_used_ip']?.toString(),
        expiresAt: json['expires_at']?.toString(),
        revokedAt: json['revoked_at']?.toString(),
      );
}

class WebhookModel {
  final int id;
  final String name;
  final String url;
  final List<String> events;
  final String status;
  final int consecutiveFailures;
  final String? lastSuccessAt;
  final String? lastFailureAt;
  final String? disabledReason;

  /// An endpoint nothing has been sent to has not earned a green tick.
  final bool neverCalled;

  const WebhookModel({
    required this.id,
    required this.name,
    required this.url,
    required this.events,
    required this.status,
    required this.consecutiveFailures,
    required this.neverCalled,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.disabledReason,
  });

  bool get isDisabled => status == 'disabled';
  bool get isActive => status == 'active';

  static WebhookModel fromJson(Map<String, dynamic> json) => WebhookModel(
        id: _int(json['id']),
        name: json['name']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        events: _strings(json['events']),
        status: json['status']?.toString() ?? 'active',
        consecutiveFailures: _int(json['consecutive_failures']),
        neverCalled: json['never_called'] == true,
        lastSuccessAt: json['last_success_at']?.toString(),
        lastFailureAt: json['last_failure_at']?.toString(),
        disabledReason: json['disabled_reason']?.toString(),
      );
}

class WebhookDeliveryModel {
  final int id;
  final int webhookId;
  final String event;
  final String status;
  final int attempts;
  final int? responseCode;
  final String? responseBody;
  final String? error;
  final String? nextAttemptAt;
  final String? createdAt;

  const WebhookDeliveryModel({
    required this.id,
    required this.webhookId,
    required this.event,
    required this.status,
    required this.attempts,
    this.responseCode,
    this.responseBody,
    this.error,
    this.nextAttemptAt,
    this.createdAt,
  });

  bool get delivered => status == 'delivered';

  static WebhookDeliveryModel fromJson(Map<String, dynamic> json) => WebhookDeliveryModel(
        id: _int(json['id']),
        webhookId: _int(json['webhook_id']),
        event: json['event']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        attempts: _int(json['attempts']),
        responseCode: json['response_code'] == null ? null : _int(json['response_code']),
        responseBody: json['response_body']?.toString(),
        error: json['error']?.toString(),
        nextAttemptAt: json['next_attempt_at']?.toString(),
        createdAt: json['created_at']?.toString(),
      );
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _strings(dynamic value) =>
    value is List ? value.map((e) => e.toString()).toList() : const <String>[];
