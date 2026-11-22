import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';

/// One line of what the platform admin API did and who asked.
///
/// Only the parts of `context` the app can show without guessing are kept: the
/// status a request was answered with, and the name of the device that signed
/// in. The server never puts a secret in a line, and the app does not keep the
/// rest.
class PlatformAuditLine {
  final int id;

  /// Null for a line the operator wrote at the console.
  final int? adminId;
  final String action;
  final String? market;
  final String? ip;
  final String? userAgent;
  final int? statusCode;
  final String? deviceName;
  final DateTime? createdAt;

  const PlatformAuditLine({
    required this.id,
    required this.action,
    this.adminId,
    this.market,
    this.ip,
    this.userAgent,
    this.statusCode,
    this.deviceName,
    this.createdAt,
  });

  factory PlatformAuditLine.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> context = PlatformJson.map(json['context']);

    return PlatformAuditLine(
      id: PlatformJson.count(json['id']),
      adminId: PlatformJson.integer(json['admin_id']),
      action: PlatformJson.string(json['action']) ?? '',
      market: PlatformJson.string(json['market']),
      ip: PlatformJson.string(json['ip']),
      userAgent: PlatformJson.string(json['user_agent']),
      statusCode: PlatformJson.integer(context['status']),
      deviceName: PlatformJson.string(context['device_name']),
      createdAt: PlatformJson.moment(json['created_at']),
    );
  }
}

/// A page of the audit trail, newest first.
class PlatformAuditPage {
  final List<PlatformAuditLine> lines;

  /// The platform owner reads every line; a restricted viewer only their own.
  final PlatformScope scope;
  final int page;
  final int perPage;
  final bool hasMore;

  const PlatformAuditPage({
    required this.lines,
    required this.scope,
    required this.page,
    required this.perPage,
    required this.hasMore,
  });

  factory PlatformAuditPage.fromJson(List<Map<String, dynamic>> rows, Map<String, dynamic> meta) => PlatformAuditPage(
        lines: rows.map(PlatformAuditLine.fromJson).toList(),
        scope: PlatformScope.parse(meta['scope']),
        page: PlatformJson.integer(meta['page']) ?? 1,
        perPage: PlatformJson.count(meta['per_page']),
        hasMore: PlatformJson.flag(meta['has_more']),
      );
}
