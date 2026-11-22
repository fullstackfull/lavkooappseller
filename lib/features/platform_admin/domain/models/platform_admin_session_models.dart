import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_capability_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';

/// Who is signed in and what they may see and do, exactly as the server says.
///
/// The app never decides this for itself. It reads it when the app starts and
/// when someone signs in, and everything it offers is limited to `markets` and to
/// the `capabilities` of the grant.
class PlatformAdminProfile {
  final int adminId;
  final String name;
  final int level;
  final PlatformScope scope;
  final List<String> markets;
  final DateTime? tokenExpiresAt;

  /// The parts of the API the grant includes. Every part for a server that does not list them.
  final Set<PlatformCapability> capabilities;

  /// When the grant ends, or null for a grant with no end.
  final DateTime? grantExpiresAt;

  /// What the server says of the second factor, or null when it says nothing.
  final PlatformAdminMfaStatus? mfa;

  const PlatformAdminProfile({
    required this.adminId,
    required this.name,
    required this.level,
    required this.scope,
    required this.markets,
    this.tokenExpiresAt,
    this.capabilities = PlatformCapability.every,
    this.grantExpiresAt,
    this.mfa,
  });

  factory PlatformAdminProfile.fromJson(Map<String, dynamic> json) => PlatformAdminProfile(
        adminId: PlatformJson.count(json['admin_id']),
        name: PlatformJson.string(json['name']) ?? '',
        level: PlatformJson.count(json['level']),
        scope: PlatformScope.parse(json['scope']),
        markets: PlatformJson.strings(json['markets']),
        tokenExpiresAt: PlatformJson.moment(json['token_expires_at']),
        capabilities: PlatformCapability.fromJson(json['capabilities']),
        grantExpiresAt: PlatformJson.moment(json['grant_expires_at']),
        mfa: PlatformAdminMfaStatus.fromJson(json['mfa']),
      );

  bool get isRestricted => scope == PlatformScope.restricted;

  /// Whether the grant includes this part of the API.
  bool can(PlatformCapability capability) => capabilities.contains(capability);

  /// `all` is never refused: it means all of the viewer's own.
  bool canSee(String market) => market == PlatformMarketCode.all || markets.contains(market);
}

/// The answer to a sign-in that opened a session: the token, shown once, and who it belongs to.
///
/// What this says of the admin is the six members the API has always given and nothing about what they
/// may do: that is read from `GET /me` right after.
class PlatformAdminSignIn {
  final String token;
  final DateTime? expiresAt;
  final PlatformAdminProfile profile;

  /// How many recovery codes the admin has left, which only the answer of the second step says.
  final int? recoveryCodesLeft;

  const PlatformAdminSignIn({required this.token, required this.profile, this.expiresAt, this.recoveryCodesLeft});

  factory PlatformAdminSignIn.fromJson(Map<String, dynamic> json) {
    final int? recoveryCodesLeft = PlatformJson.integer(PlatformJson.map(json['mfa'])['recovery_codes_left']);

    return PlatformAdminSignIn(
      token: PlatformJson.string(json['token']) ?? '',
      expiresAt: PlatformJson.moment(json['expires_at']),
      profile: PlatformAdminProfile.fromJson(PlatformJson.map(json['me'])),
      recoveryCodesLeft: recoveryCodesLeft != null && recoveryCodesLeft >= 0 ? recoveryCodesLeft : null,
    );
  }

  /// The token is a secret: nothing that prints this object may print it.
  @override
  String toString() => 'PlatformAdminSignIn(adminId: ${profile.adminId})';
}

/// What a good password leads to: a session, or the second step.
sealed class PlatformAdminSignInStep {
  const PlatformAdminSignInStep();

  /// The answer of `POST /auth/login`. It is told by `mfa_required`: where that is true there is no token, and
  /// anything else the answer carries is not looked at, so that no session can be opened without the second factor.
  /// Null when the answer is neither.
  static PlatformAdminSignInStep? fromJson(Map<String, dynamic> json) {
    if (PlatformJson.flag(json['mfa_required'])) {
      final PlatformAdminMfaChallenge? challenge = PlatformAdminMfaChallenge.fromJson(json);
      return challenge == null ? null : PlatformAdminSecondFactorWanted(challenge);
    }

    return PlatformAdminSessionOpened(PlatformAdminSignIn.fromJson(json));
  }
}

/// The server does not require a second factor: the sign-in is the one of level 1.
final class PlatformAdminSessionOpened extends PlatformAdminSignInStep {
  final PlatformAdminSignIn signIn;

  const PlatformAdminSessionOpened(this.signIn);
}

/// The password was accepted and no session exists yet: a code is wanted.
final class PlatformAdminSecondFactorWanted extends PlatformAdminSignInStep {
  final PlatformAdminMfaChallenge challenge;

  const PlatformAdminSecondFactorWanted(this.challenge);
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

  /// How the session passed the second factor, or null when it did not or the server does not say.
  final PlatformAdminMfaMethod? mfaMethod;

  const PlatformSessionModel({
    required this.id,
    required this.deviceName,
    required this.isCurrent,
    this.createdAt,
    this.lastUsedAt,
    this.expiresAt,
    this.mfaMethod,
  });

  factory PlatformSessionModel.fromJson(Map<String, dynamic> json) => PlatformSessionModel(
        id: PlatformJson.count(json['id']),
        deviceName: PlatformJson.string(json['device_name']) ?? '',
        createdAt: PlatformJson.moment(json['created_at']),
        lastUsedAt: PlatformJson.moment(json['last_used_at']),
        expiresAt: PlatformJson.moment(json['expires_at']),
        isCurrent: PlatformJson.flag(json['current']),
        mfaMethod: PlatformAdminMfaMethod.parse(json['mfa_method']),
      );
}
