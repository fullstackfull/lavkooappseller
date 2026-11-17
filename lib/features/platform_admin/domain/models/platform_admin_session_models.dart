import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';

/// Who is signed in and what they may see, exactly as the server says.
///
/// The app never decides this for itself. It reads it when the app starts and
/// when someone signs in, and everything it offers is limited to `markets`.
class PlatformAdminProfile {
  final int adminId;
  final String name;
  final int level;
  final PlatformScope scope;
  final List<String> markets;
  final DateTime? tokenExpiresAt;

  const PlatformAdminProfile({
    required this.adminId,
    required this.name,
    required this.level,
    required this.scope,
    required this.markets,
    this.tokenExpiresAt,
  });

  factory PlatformAdminProfile.fromJson(Map<String, dynamic> json) => PlatformAdminProfile(
        adminId: PlatformJson.count(json['admin_id']),
        name: PlatformJson.string(json['name']) ?? '',
        level: PlatformJson.count(json['level']),
        scope: PlatformScope.parse(json['scope']),
        markets: PlatformJson.strings(json['markets']),
        tokenExpiresAt: PlatformJson.moment(json['token_expires_at']),
      );

  bool get isRestricted => scope == PlatformScope.restricted;

  /// `all` is never refused: it means all of the viewer's own.
  bool canSee(String market) => market == PlatformMarketCode.all || markets.contains(market);
}

/// The answer to a sign-in: the token, shown once, and who it belongs to.
class PlatformAdminSignIn {
  final String token;
  final DateTime? expiresAt;
  final PlatformAdminProfile profile;

  const PlatformAdminSignIn({required this.token, required this.profile, this.expiresAt});

  factory PlatformAdminSignIn.fromJson(Map<String, dynamic> json) => PlatformAdminSignIn(
        token: PlatformJson.string(json['token']) ?? '',
        expiresAt: PlatformJson.moment(json['expires_at']),
        profile: PlatformAdminProfile.fromJson(PlatformJson.map(json['me'])),
      );

  /// The token is a secret: nothing that prints this object may print it.
  @override
  String toString() => 'PlatformAdminSignIn(adminId: ${profile.adminId})';
}

/// One open session of the signed-in admin: a device that holds a token.
///
/// Never a token, a hash, an address or a user agent. `lastUsedAt` is null for a
/// session that has never been used, which is not the moment it was opened.
class PlatformSessionModel {
  final int id;
  final String deviceName;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;
  final bool isCurrent;

  const PlatformSessionModel({
    required this.id,
    required this.deviceName,
    required this.isCurrent,
    this.createdAt,
    this.lastUsedAt,
    this.expiresAt,
  });

  factory PlatformSessionModel.fromJson(Map<String, dynamic> json) => PlatformSessionModel(
        id: PlatformJson.count(json['id']),
        deviceName: PlatformJson.string(json['device_name']) ?? '',
        createdAt: PlatformJson.moment(json['created_at']),
        lastUsedAt: PlatformJson.moment(json['last_used_at']),
        expiresAt: PlatformJson.moment(json['expires_at']),
        isCurrent: PlatformJson.flag(json['current']),
      );
}
