import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';

/// How serious an alert is, in the words the API uses.
abstract final class PlatformSeverity {
  static const String critical = 'critical';
  static const String warning = 'warning';
  static const String info = 'info';

  /// Worst first, which is the order a filter lists them in.
  static const List<String> all = <String>[critical, warning, info];

  /// A severity the app has never heard of ranks below the lowest it knows, so
  /// that it can never be drawn as more serious than what the API calls critical.
  static int rank(String severity) => switch (severity) {
        critical => 3,
        warning => 2,
        info => 1,
        _ => 0,
      };
}

/// Where an alert asks the app to go.
///
/// At level 1 every alert links to a market (`markets/XX`). Anything else is
/// not routable, and a tile made from it is not tappable.
class PlatformDeepLink {
  final String market;

  const PlatformDeepLink._(this.market);

  static final RegExp _marketLink = RegExp(r'^markets/([A-Za-z]{2})$');

  static PlatformDeepLink? parse(String? link) {
    final RegExpMatch? match = link == null ? null : _marketLink.firstMatch(link);
    return match == null ? null : PlatformDeepLink._(PlatformMarketCode.normalize(match.group(1)!));
  }
}

/// One thing the platform noticed, worked out when it was asked for.
///
/// `code` is what the app localises by. `message` is plain English for a person
/// reading a log: it is never translated and may change, so it is shown as
/// detail and never parsed.
class PlatformAlertModel {
  final String id;
  final String severity;
  final String market;
  final String code;
  final String message;
  final String? deepLink;
  final DateTime? generatedAt;

  const PlatformAlertModel({
    required this.id,
    required this.severity,
    required this.market,
    required this.code,
    required this.message,
    this.deepLink,
    this.generatedAt,
  });

  factory PlatformAlertModel.fromJson(Map<String, dynamic> json) => PlatformAlertModel(
        id: PlatformJson.string(json['id']) ?? '',
        severity: PlatformJson.string(json['severity']) ?? '',
        market: PlatformJson.string(json['market']) ?? '',
        code: PlatformJson.string(json['code']) ?? '',
        message: PlatformJson.string(json['message']) ?? '',
        deepLink: PlatformJson.string(json['deep_link']),
        generatedAt: PlatformJson.moment(json['generated_at']),
      );

  PlatformDeepLink? get link => PlatformDeepLink.parse(deepLink);
}

/// A page of alerts, with how it was asked for and how many there are.
class PlatformAlertPage {
  final List<PlatformAlertModel> alerts;
  final PlatformScope scope;
  final String market;
  final String? severity;
  final DateTime? generatedAt;
  final int page;
  final int perPage;
  final int total;
  final bool hasMore;

  const PlatformAlertPage({
    required this.alerts,
    required this.scope,
    required this.market,
    required this.page,
    required this.perPage,
    required this.total,
    required this.hasMore,
    this.severity,
    this.generatedAt,
  });

  factory PlatformAlertPage.fromJson(List<Map<String, dynamic>> rows, Map<String, dynamic> meta) => PlatformAlertPage(
        alerts: rows.map(PlatformAlertModel.fromJson).toList(),
        scope: PlatformScope.parse(meta['scope']),
        market: PlatformJson.string(meta['market']) ?? PlatformMarketCode.all,
        severity: PlatformJson.string(meta['severity']),
        generatedAt: PlatformJson.moment(meta['generated_at']),
        page: PlatformJson.integer(meta['page']) ?? 1,
        perPage: PlatformJson.count(meta['per_page']),
        total: PlatformJson.count(meta['total']),
        hasMore: PlatformJson.flag(meta['has_more']),
      );
}
