import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';

/// How the platform admin API names a market: the code the platform configured
/// (SA, AE, KW, QA, BH, OM), or the one word that means all of the viewer's own.
abstract final class PlatformMarketCode {
  static const String all = 'all';

  static String normalize(String code) => code.trim().toUpperCase();
}

/// Whether the viewer is the platform owner or sees only some markets.
///
/// Only the exact word the server uses for the owner is the owner. A scope the
/// app has never heard of, or none at all, is restricted: it must never be able
/// to widen what the app shows.
enum PlatformScope {
  all,
  restricted;

  static PlatformScope parse(Object? value) => value == 'all' ? PlatformScope.all : PlatformScope.restricted;
}

/// One market the viewer may see, with what the platform says about it.
///
/// A market serves customers when it is active and the platform's storefront
/// switch is on, and it may sell only when its legal documents are approved.
/// Those are three separate facts and are kept apart. A fact the answer does
/// not carry is off, never on.
class PlatformMarketModel {
  final String code;
  final String? path;
  final String? currency;
  final bool active;
  final bool storefrontEnabled;
  final bool legalReady;
  final String? legalEntity;

  const PlatformMarketModel({
    required this.code,
    this.path,
    this.currency,
    this.active = false,
    this.storefrontEnabled = false,
    this.legalReady = false,
    this.legalEntity,
  });

  factory PlatformMarketModel.fromJson(Map<String, dynamic> json) => PlatformMarketModel(
        code: PlatformJson.string(json['code']) ?? '',
        path: PlatformJson.string(json['path']),
        currency: PlatformJson.string(json['currency']),
        active: PlatformJson.flag(json['active']),
        storefrontEnabled: PlatformJson.flag(json['storefront_enabled']),
        legalReady: PlatformJson.flag(json['legal_ready']),
        legalEntity: PlatformJson.string(json['legal_entity']),
      );
}

/// The markets the viewer may see, in the order the platform configured them.
class PlatformMarketDirectory {
  final PlatformScope scope;
  final DateTime? generatedAt;
  final List<PlatformMarketModel> markets;

  const PlatformMarketDirectory({
    required this.scope,
    required this.markets,
    this.generatedAt,
  });

  factory PlatformMarketDirectory.fromJson(Map<String, dynamic> json) => PlatformMarketDirectory(
        scope: PlatformScope.parse(json['scope']),
        generatedAt: PlatformJson.moment(json['generated_at']),
        markets: PlatformJson.maps(json['markets']).map(PlatformMarketModel.fromJson).toList(),
      );

  List<String> get codes => markets.map((PlatformMarketModel market) => market.code).toList();

  PlatformMarketModel? marketOf(String code) {
    for (final PlatformMarketModel market in markets) {
      if (market.code == code) return market;
    }
    return null;
  }
}
