import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';

/// The words of the platform admin shell, chosen by the codes the API speaks in.
///
/// The API's own messages are plain English for a person reading a log and are
/// never shown. Every key is written out where it is used, so that the
/// translation check can see it.
abstract final class PlatformAdminTexts {
  /// A moment, in the zone of the phone, as the rest of the app writes one.
  static String moment(DateTime moment) => DateConverter.formatDateWithCommaAnd24Hour(moment);

  static String failureTitle(BuildContext context, PlatformAdminFailure failure) => switch (failure.kind) {
        PlatformAdminFailureKind.network => getTranslated('connection_failed_title', context)!,
        PlatformAdminFailureKind.marketNotAllowed => getTranslated('platform_admin_market_not_allowed', context)!,
        PlatformAdminFailureKind.notAvailable => getTranslated('platform_admin_not_available', context)!,
        PlatformAdminFailureKind.notReady => getTranslated('platform_admin_not_ready', context)!,
        PlatformAdminFailureKind.throttled => _tryAgain(context, failure),
        PlatformAdminFailureKind.unauthenticated => getTranslated('platform_admin_session_ended', context)!,
        PlatformAdminFailureKind.sessionNotFound ||
        PlatformAdminFailureKind.invalidRequest ||
        PlatformAdminFailureKind.server ||
        PlatformAdminFailureKind.malformed =>
          getTranslated('something_went_wrong', context)!,
      };

  /// What to do about it, when there is something to say beyond the title.
  static String? failureHint(BuildContext context, PlatformAdminFailure failure) =>
      failure.kind == PlatformAdminFailureKind.network ? getTranslated('connection_failed_message', context) : null;

  static IconData failureIcon(PlatformAdminFailure failure) => switch (failure.kind) {
        PlatformAdminFailureKind.network => Icons.wifi_off_rounded,
        PlatformAdminFailureKind.marketNotAllowed || PlatformAdminFailureKind.unauthenticated => Icons.lock_outline,
        PlatformAdminFailureKind.notAvailable => Icons.block_outlined,
        PlatformAdminFailureKind.notReady => Icons.hourglass_empty_rounded,
        PlatformAdminFailureKind.throttled => Icons.timer_outlined,
        _ => Icons.error_outline,
      };

  /// What a failed sign-in says: a refusal says nothing about which check failed,
  /// because the API does not either.
  static String signInFailure(BuildContext context, PlatformAdminFailure failure) =>
      failure.kind == PlatformAdminFailureKind.unauthenticated
          ? getTranslated('platform_admin_sign_in_failed', context)!
          : failureTitle(context, failure);

  /// The time of day a wait ends, in the phone's own zone.
  static String tryAgainClock(DateTime retryAt) => DateFormat('HH:mm').format(retryAt.toLocal());

  /// "Try again at 12:35", with the time the API named.
  static String _tryAgain(BuildContext context, PlatformAdminFailure failure) {
    final DateTime? retryAt = failure.retryAt;
    if (retryAt == null) return getTranslated('platform_admin_try_again_later', context)!;

    return '${getTranslated('platform_admin_try_again_at', context)!} ${tryAgainClock(retryAt)}';
  }
}
