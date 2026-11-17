import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/localization/app_localization.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';

/// The words of the platform admin shell, chosen by the codes the API speaks in.
///
/// The API's own messages are plain English for a person reading a log and are
/// never shown. Every key is written out where it is used, so that the
/// translation check can see it.
abstract final class PlatformAdminTexts {
  /// A moment, in the zone of the phone, as the rest of the app writes one.
  static String moment(DateTime moment) => DateConverter.formatDateWithCommaAnd24Hour(moment);

  /// The market chip, and the name of a market on its card. A market the app has no
  /// name for is shown by its code, which is what the platform calls it.
  static String marketName(BuildContext context, String code) => switch (code) {
        'SA' => getTranslated('platform_admin_market_sa', context)!,
        'AE' => getTranslated('platform_admin_market_ae', context)!,
        'KW' => getTranslated('platform_admin_market_kw', context)!,
        'QA' => getTranslated('platform_admin_market_qa', context)!,
        'BH' => getTranslated('platform_admin_market_bh', context)!,
        'OM' => getTranslated('platform_admin_market_om', context)!,
        _ => code,
      };

  /// The chip that means every market the viewer may see: all of them for the
  /// platform owner, and only their own for anyone else.
  static String allMarkets(BuildContext context, {required bool restricted}) => restricted
      ? getTranslated('platform_admin_my_markets', context)!
      : getTranslated('platform_admin_all_markets', context)!;

  /// An order status in the words the seller app already uses for it. A status the
  /// app has never heard of is written out from its own name.
  static String orderStatus(BuildContext context, String status) => switch (status) {
        'pending' => getTranslated('pending', context)!,
        'confirmed' => getTranslated('confirmed', context)!,
        'processing' => getTranslated('processing', context)!,
        'out_for_delivery' => getTranslated('out_for_delivery', context)!,
        'delivered' => getTranslated('delivered', context)!,
        'returned' => getTranslated('returned', context)!,
        'failed' => getTranslated('failed', context)!,
        'canceled' => getTranslated('canceled', context)!,
        _ => status.toTitleCase(),
      };

  static String severity(BuildContext context, String severity) => switch (severity) {
        PlatformSeverity.critical => getTranslated('platform_admin_severity_critical', context)!,
        PlatformSeverity.warning => getTranslated('platform_admin_severity_warning', context)!,
        PlatformSeverity.info => getTranslated('platform_admin_severity_info', context)!,
        _ => severity.toTitleCase(),
      };

  /// A window of days, written the way a chip says it.
  static String windowLabel(BuildContext context, int days) => switch (days) {
        7 => getTranslated('platform_admin_window_7', context)!,
        30 => getTranslated('platform_admin_window_30', context)!,
        92 => getTranslated('platform_admin_window_92', context)!,
        _ => '$days ${getTranslated('platform_admin_window_days', context)!}',
      };

  /// The days the overview counted, as the server resolved them.
  static String windowSummary(BuildContext context, PlatformWindowModel window) {
    final bool hasDates = window.from.isNotEmpty && window.to.isNotEmpty;
    final String days = windowLabel(context, window.days);
    if (!hasDates) return days;

    return '${DateConverter.stringToLocalDateOnly(window.from)} \u2013 ${DateConverter.stringToLocalDateOnly(window.to)} \u00b7 $days';
  }

  /// How the figures were counted, and when.
  static String freshness(BuildContext context, PlatformFreshness freshness, DateTime? generatedAt) {
    final String how = freshness.cached
        ? getTranslated('platform_admin_saved_copy', context)!
        : getTranslated('platform_admin_live', context)!;
    return generatedAt == null
        ? how
        : '$how \u00b7 ${getTranslated('platform_admin_updated', context)!} ${moment(generatedAt)}';
  }

  /// Why there is no sales figure. Never an amount: the app is never given one to show.
  static String sales(BuildContext context, PlatformSalesFigure sales) => switch (sales.reason) {
        'order_currency_not_recorded' => getTranslated('platform_admin_sales_order_currency_not_recorded', context)!,
        _ => getTranslated('platform_admin_sales_not_shown', context)!,
      };

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
