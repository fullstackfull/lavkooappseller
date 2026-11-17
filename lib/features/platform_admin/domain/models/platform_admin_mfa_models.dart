import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';

/// The two ways the API takes a second factor.
enum PlatformAdminMfaMethod {
  /// The six-digit code an authenticator app shows.
  totp('totp'),

  /// One of the one-time codes the admin was given when the factor was set up.
  recoveryCode('recovery_code');

  const PlatformAdminMfaMethod(this.wireName);

  /// What the API calls it.
  final String wireName;

  static PlatformAdminMfaMethod? parse(Object? value) {
    for (final PlatformAdminMfaMethod method in PlatformAdminMfaMethod.values) {
      if (method.wireName == value) return method;
    }
    return null;
  }
}

/// What the API gives instead of a session when the password alone is not enough:
/// the right to try a code, for a few minutes.
///
/// [value] is a secret that is good for nothing but the second step. It is held in
/// memory by the one controller that asked for it, is never written anywhere, and
/// nothing that prints this object prints it.
class PlatformAdminMfaChallenge {
  /// How many wrong codes the app lets one challenge take before it starts again from the password. It is the
  /// server's own default, which the server does not tell the app.
  static const int maxTries = 5;

  final String value;
  final DateTime? expiresAt;

  /// What the API takes for this challenge. A server that does not say takes both.
  final Set<PlatformAdminMfaMethod> methods;

  const PlatformAdminMfaChallenge({required this.value, required this.methods, this.expiresAt});

  /// Null when the answer carries nothing to use as a challenge.
  static PlatformAdminMfaChallenge? fromJson(Map<String, dynamic> json) {
    final String? value = PlatformJson.string(json['challenge']);
    if (value == null || value.isEmpty) return null;

    final Set<PlatformAdminMfaMethod> listed = PlatformJson.list(json['methods'])
        .map(PlatformAdminMfaMethod.parse)
        .whereType<PlatformAdminMfaMethod>()
        .toSet();

    return PlatformAdminMfaChallenge(
      value: value,
      expiresAt: PlatformJson.moment(json['challenge_expires_at']),
      methods: listed.isEmpty ? PlatformAdminMfaMethod.values.toSet() : listed,
    );
  }

  /// Whether the server would refuse it for its age. A challenge that does not say when it ends is not known to be over.
  bool isOver(DateTime now) {
    final DateTime? end = expiresAt;
    return end != null && !end.isAfter(now);
  }

  @override
  String toString() => 'PlatformAdminMfaChallenge(methods: ${methods.map((method) => method.name).join(',')})';
}

/// Why the second step was left without a session, said once on the password step.
enum PlatformAdminSecondFactorEnd {
  /// The challenge ran out of time.
  expired,

  /// Every try the challenge allows was used.
  triesUsed,
}

/// What `GET /me` says about the second factor of the admin and of this session.
class PlatformAdminMfaStatus {
  /// Whether the admin has a confirmed factor.
  final bool enrolled;

  /// Whether this session passed the second factor.
  final bool verified;

  /// How it did, or null when it did not.
  final PlatformAdminMfaMethod? method;

  const PlatformAdminMfaStatus({required this.enrolled, required this.verified, this.method});

  /// Null when the answer has no such member: an older server, which has not said.
  static PlatformAdminMfaStatus? fromJson(Object? value) {
    if (value is! Map) return null;

    final Map<String, dynamic> json = PlatformJson.map(value);
    return PlatformAdminMfaStatus(
      enrolled: PlatformJson.flag(json['enrolled']),
      verified: PlatformJson.flag(json['verified']),
      method: PlatformAdminMfaMethod.parse(json['method']),
    );
  }
}

/// What an admin types for the second step, in the shape the API takes.
///
/// A malformed attempt is refused like a wrong code and uses up one of the few tries
/// a challenge has, so nothing that cannot be right is sent.
abstract final class PlatformSecondFactorInput {
  static const int codeLength = 6;

  /// The six digits of a code, with the spaces and hyphens between them dropped and the digits of an Arabic or Persian keyboard read as the digits they
  /// are. Null when what was typed is anything else.
  static String? code(String typed) {
    final String compact = asciiDigits(typed).replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^[0-9]{6}$').hasMatch(compact) ? compact : null;
  }

  /// The ten letters and digits of a recovery code, in the form `xxxxx-xxxxx`, whatever the case and the spaces and the hyphen it was typed
  /// with. Only the shape is checked, not which letters a code may have: that is the server's to say. Null when the shape is not that.
  static String? recoveryCode(String typed) {
    final String compact = typed.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
    if (!RegExp(r'^[a-z0-9]{10}$').hasMatch(compact)) return null;

    return '${compact.substring(0, 5)}-${compact.substring(5)}';
  }

  /// Arabic-Indic and Extended Arabic-Indic digits as the digits 0 to 9, and everything else as it was.
  static String asciiDigits(String text) => String.fromCharCodes(text.runes.map((int rune) {
        if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
        if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
        return rune;
      }));
}
