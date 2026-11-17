import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_capability_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_json.dart';

/// Every way a call to the platform admin API can come to nothing.
enum PlatformAdminFailureKind {
  /// Any failure to authenticate, which the API answers with one 401 and no hint. At the second step of the sign-in it
  /// is also what a wrong code, a used code and a challenge that is over answer.
  unauthenticated,

  /// 403: the market is not in the viewer's grant.
  marketNotAllowed,

  /// 403: the part of the API the call belongs to is not in the viewer's grant. The token is good.
  capabilityNotAllowed,

  /// 404 from the sessions route: not one of the viewer's own open sessions.
  sessionNotFound,

  /// Any other 404: the API is switched off, or the router has no such route.
  notAvailable,

  /// 422: the API could not read what it was asked.
  invalidRequest,

  /// 429: too many attempts or requests.
  throttled,

  /// 503: the API is on but its tables are not there yet.
  notReady,

  /// Any other status.
  server,

  /// No answer: no connection, a timeout, a certificate refused.
  network,

  /// An answer that is not what the contract says.
  malformed,
}

/// What went wrong, and nothing the server said about it.
///
/// A message, a body or a header could carry a secret into a log or a report, and
/// the app localises by [code] and [kind] anyway, so neither is kept.
class PlatformAdminFailure {
  final PlatformAdminFailureKind kind;
  final int? statusCode;

  /// The `code` of the first error of the body, when it has one.
  final String? code;

  /// When the API says to try again, for a throttled call.
  final DateTime? retryAt;

  /// The part of the API a grant lacks, for a call it refused for that. Null when the API does not name one this app knows.
  final PlatformCapability? capability;

  const PlatformAdminFailure._(this.kind, {this.statusCode, this.code, this.retryAt, this.capability});

  const PlatformAdminFailure.network() : this._(PlatformAdminFailureKind.network);

  /// The session is over without the API having been asked: its token has run out.
  const PlatformAdminFailure.unauthenticated() : this._(PlatformAdminFailureKind.unauthenticated);

  const PlatformAdminFailure.malformed() : this._(PlatformAdminFailureKind.malformed);

  /// The longest wait a `Retry-After` is allowed to name, so that the moment it
  /// names can always be written down.
  static const Duration _longestWait = Duration(days: 1);

  factory PlatformAdminFailure.fromResponse({
    required int statusCode,
    Object? body,
    String? retryAfter,
    DateTime? now,
  }) {
    final String? code = _firstErrorCode(body);

    return switch (statusCode) {
      401 => PlatformAdminFailure._(PlatformAdminFailureKind.unauthenticated, statusCode: statusCode, code: code),
      403 => switch (code) {
          'market_not_allowed' =>
            PlatformAdminFailure._(PlatformAdminFailureKind.marketNotAllowed, statusCode: statusCode, code: code),
          'capability_not_allowed' => PlatformAdminFailure._(PlatformAdminFailureKind.capabilityNotAllowed,
              statusCode: statusCode, code: code, capability: _firstErrorCapability(body)),
          _ => PlatformAdminFailure._(PlatformAdminFailureKind.server, statusCode: statusCode, code: code),
        },
      404 => PlatformAdminFailure._(
          code == 'session_not_found'
              ? PlatformAdminFailureKind.sessionNotFound
              : PlatformAdminFailureKind.notAvailable,
          statusCode: statusCode,
          code: code,
        ),
      422 => PlatformAdminFailure._(PlatformAdminFailureKind.invalidRequest, statusCode: statusCode, code: code),
      429 => PlatformAdminFailure._(
          PlatformAdminFailureKind.throttled,
          statusCode: statusCode,
          code: code,
          retryAt: _retryAt(retryAfter, now ?? DateTime.now()),
        ),
      503 => PlatformAdminFailure._(PlatformAdminFailureKind.notReady, statusCode: statusCode, code: code),
      _ => PlatformAdminFailure._(PlatformAdminFailureKind.server, statusCode: statusCode, code: code),
    };
  }

  static String? _firstErrorCode(Object? body) {
    final List<Object?> errors = PlatformJson.list(PlatformJson.map(body)['errors']);
    return errors.isEmpty ? null : PlatformJson.string(PlatformJson.map(errors.first)['code']);
  }

  static PlatformCapability? _firstErrorCapability(Object? body) {
    final List<Object?> errors = PlatformJson.list(PlatformJson.map(body)['errors']);
    return errors.isEmpty ? null : PlatformCapability.parse(PlatformJson.map(errors.first)['capability']);
  }

  /// `Retry-After` as a number of seconds. A date, a fraction, zero or text is no
  /// time at all: a wrong time is worse than none.
  static DateTime? _retryAt(String? header, DateTime now) {
    final int? seconds = int.tryParse(header?.trim() ?? '');
    if (seconds == null || seconds <= 0) return null;

    final Duration wait = Duration(seconds: seconds);
    return now.add(wait > _longestWait ? _longestWait : wait);
  }

  @override
  String toString() =>
      'PlatformAdminFailure(${kind.name}, status: $statusCode, code: $code${capability == null ? '' : ', capability: ${capability!.name}'})';
}

/// The value of a call, or the reason there is none.
class PlatformAdminResult<T> {
  final T? value;
  final PlatformAdminFailure? failure;

  const PlatformAdminResult.success(T this.value) : failure = null;

  const PlatformAdminResult.failure(PlatformAdminFailure this.failure) : value = null;

  bool get isSuccess => failure == null;
}
