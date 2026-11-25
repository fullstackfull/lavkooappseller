import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/localization/app_localization.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';

/// The words of the platform admin shell, chosen by the codes the API speaks in.
///
/// The API's own error messages are plain English for a person reading a log and
/// are never shown. The sentence of an alert is shown only as detail under its
/// translated title, because the count of what is wrong is only in it. Every key
/// is written out where it is used, so that the translation check can see it.
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

  /// What an alert is about, by its code. The API's own sentence is English only, and
  /// carries the count, so it is shown under this as detail and never parsed.
  static String alertTitle(BuildContext context, String code) => switch (code) {
        'legal_not_ready' => getTranslated('platform_admin_alert_legal_not_ready', context)!,
        'stock_zero' => getTranslated('platform_admin_alert_stock_zero', context)!,
        'orders_pending_too_long' => getTranslated('platform_admin_alert_orders_pending_too_long', context)!,
        // The six operational health signals (L-09). An operator who does not hold
        // the health capability never receives any of these, so a title for one is
        // never drawn for them.
        'payments_stuck' => getTranslated('platform_admin_alert_payments_stuck', context)!,
        'payments_unreconciled' => getTranslated('platform_admin_alert_payments_unreconciled', context)!,
        'channels_failing' => getTranslated('platform_admin_alert_channels_failing', context)!,
        'carriers_failing' => getTranslated('platform_admin_alert_carriers_failing', context)!,
        'books_need_a_person' => getTranslated('platform_admin_alert_books_need_a_person', context)!,
        'shop_issues_open' => getTranslated('platform_admin_alert_shop_issues_open', context)!,
        'approvals_pending' => getTranslated('platform_admin_alert_approvals_pending', context)!,
        _ => code.toTitleCase(),
      };

  /// What a line of the audit log says was done. An action the app has not heard of
  /// is shown as its own name, as the server wrote it: the log is evidence, and a name the app made up
  /// from it would be a different line.
  static String auditAction(BuildContext context, String action) => switch (action) {
        'auth.login' => getTranslated('platform_admin_action_auth_login', context)!,
        'auth.login_failed' => getTranslated('platform_admin_action_auth_login_failed', context)!,
        'auth.logout' => getTranslated('platform_admin_action_auth_logout', context)!,
        'me.view' => getTranslated('platform_admin_action_me_view', context)!,
        'sessions.list' => getTranslated('platform_admin_action_sessions_list', context)!,
        'session.revoke' => getTranslated('platform_admin_action_session_revoke', context)!,
        'markets.view' => getTranslated('platform_admin_action_markets_view', context)!,
        'overview.view' => getTranslated('platform_admin_action_overview_view', context)!,
        'alerts.view' => getTranslated('platform_admin_action_alerts_view', context)!,
        'audit_logs.view' => getTranslated('platform_admin_action_audit_logs_view', context)!,
        'grant.created' => getTranslated('platform_admin_action_grant_created', context)!,
        'grant.updated' => getTranslated('platform_admin_action_grant_updated', context)!,
        'grant.reactivated' => getTranslated('platform_admin_action_grant_reactivated', context)!,
        'grant.revoked' => getTranslated('platform_admin_action_grant_revoked', context)!,
        'tokens.revoked' => getTranslated('platform_admin_action_tokens_revoked', context)!,
        'auth.mfa_challenge' => getTranslated('platform_admin_action_auth_mfa_challenge', context)!,
        'auth.mfa_failed' => getTranslated('platform_admin_action_auth_mfa_failed', context)!,
        'auth.mfa_locked' => getTranslated('platform_admin_action_auth_mfa_locked', context)!,
        'mfa.recovery_code_used' => getTranslated('platform_admin_action_mfa_recovery_code_used', context)!,
        'sessions.end_others' => getTranslated('platform_admin_action_sessions_end_others', context)!,
        'session.evicted' => getTranslated('platform_admin_action_session_evicted', context)!,
        'session.idle_ended' => getTranslated('platform_admin_action_session_idle_ended', context)!,
        'session.grant_expired' => getTranslated('platform_admin_action_session_grant_expired', context)!,
        'audit.pruned' => getTranslated('platform_admin_action_audit_pruned', context)!,
        'mfa.enrolled' => getTranslated('platform_admin_action_mfa_enrolled', context)!,
        'mfa.confirmed' => getTranslated('platform_admin_action_mfa_confirmed', context)!,
        'mfa.confirm_failed' => getTranslated('platform_admin_action_mfa_confirm_failed', context)!,
        'mfa.reset' => getTranslated('platform_admin_action_mfa_reset', context)!,
        'mfa.status' => getTranslated('platform_admin_action_mfa_status', context)!,
        _ => action,
      };

  /// Who a line of the audit log is about: this admin, another, or the operator at the console.
  static String auditActor(BuildContext context, PlatformAuditLine line, {required int? me}) {
    final int? adminId = line.adminId;
    if (adminId == null) return getTranslated('platform_admin_audit_operator', context)!;
    if (adminId == me) return getTranslated('platform_admin_audit_you', context)!;

    return '${getTranslated('platform_admin_audit_admin', context)!} $adminId';
  }

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
        PlatformAdminFailureKind.capabilityNotAllowed =>
          getTranslated('platform_admin_capability_not_allowed', context)!,
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
        PlatformAdminFailureKind.marketNotAllowed ||
        PlatformAdminFailureKind.capabilityNotAllowed ||
        PlatformAdminFailureKind.unauthenticated =>
          Icons.lock_outline,
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

  /// What the second step says when a code did not open a session. A code the API refused is said as that and with how
  /// many tries are left and nothing more, because the API says no more; anything else is said as what it is.
  static String secondFactorFailure(BuildContext context, PlatformAdminFailure failure, {required int triesLeft}) =>
      failure.kind == PlatformAdminFailureKind.unauthenticated
          ? '${getTranslated('platform_admin_mfa_wrong_code', context)!}\n${getTranslated('platform_admin_mfa_tries_left', context)!}: $triesLeft'
          : failureTitle(context, failure);

  /// How a session passed the second factor.
  static String mfaMethodName(BuildContext context, PlatformAdminMfaMethod method) => switch (method) {
        PlatformAdminMfaMethod.totp => getTranslated('platform_admin_mfa_totp', context)!,
        PlatformAdminMfaMethod.recoveryCode => getTranslated('platform_admin_mfa_recovery_code', context)!,
      };

  /// What to say when few recovery codes are left. With none, the admin has to ask for a new second factor; with some, for new codes.
  static String recoveryCodesLow(BuildContext context, int left) => left == 0
      ? getTranslated('platform_admin_mfa_recovery_none', context)!
      : '${getTranslated('platform_admin_mfa_recovery_low', context)!}: $left. ${getTranslated('platform_admin_mfa_recovery_low_advice', context)!}';

  /// Why the second step was left, said on the password step.
  static String secondFactorEnd(BuildContext context, PlatformAdminSecondFactorEnd end) => switch (end) {
        PlatformAdminSecondFactorEnd.expired => getTranslated('platform_admin_mfa_expired', context)!,
        PlatformAdminSecondFactorEnd.triesUsed => getTranslated('platform_admin_mfa_tries_used', context)!,
      };

  /// The time of day a wait ends, in the phone's own zone.
  static String tryAgainClock(DateTime retryAt) => DateFormat('HH:mm').format(retryAt.toLocal());

  /// "Try again at 12:35", with the time the API named.
  static String _tryAgain(BuildContext context, PlatformAdminFailure failure) {
    final DateTime? retryAt = failure.retryAt;
    if (retryAt == null) return getTranslated('platform_admin_try_again_later', context)!;

    return '${getTranslated('platform_admin_try_again_at', context)!} ${tryAgainClock(retryAt)}';
  }
}
