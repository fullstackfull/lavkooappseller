import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/automation/domain/models/automation_models.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The colours a rule's state is allowed to use.
///
/// Suspended is not a warmer shade of paused. A paused rule is one the seller
/// switched off and nothing is wrong; a suspended one was stopped by the
/// marketplace and needs reading. Giving them the same colour family would put
/// the two most different states side by side looking alike.
class RuleStatusStyle {
  static Color color(BuildContext context, String status) {
    switch (status) {
      case 'active':
        return Colors.green.shade600;
      case 'paused':
        return Theme.of(context).hintColor;
      case 'suspended':
        return Colors.red.shade600;
      default:
        return Theme.of(context).hintColor;
    }
  }

  static IconData icon(String status) {
    switch (status) {
      case 'active':
        return Icons.play_circle_outline;
      case 'paused':
        return Icons.pause_circle_outline;
      case 'suspended':
        return Icons.report_gmailerrorred_outlined;
      default:
        return Icons.help_outline;
    }
  }
}

/// One rule, with what it has actually done.
class AutomationRuleCardWidget extends StatelessWidget {
  final AutomationRuleModel rule;
  final VoidCallback? onTap;
  final VoidCallback? onPreview;
  final VoidCallback? onRun;
  final ValueChanged<String>? onStatus;
  final bool isBusy;

  const AutomationRuleCardWidget({
    super.key,
    required this.rule,
    this.onTap,
    this.onPreview,
    this.onRun,
    this.onStatus,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = RuleStatusStyle.color(context, rule.status);

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(RuleStatusStyle.icon(rule.status), size: 20, color: statusColor),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: Text(rule.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
              ),
              Text(getTranslated('rule_status_${rule.status}', context) ?? rule.status,
                  style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: statusColor)),
            ]),
            const SizedBox(height: Dimensions.paddingSizeSmall),

            Text(
              '${getTranslated('trigger_${rule.trigger}', context) ?? rule.trigger}'
              ' → '
              '${getTranslated('action_${rule.action}', context) ?? rule.action}',
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
            ),

            // Whether the rule is pointed at part of the shop or all of it. Said
            // on the card because it is the difference between a rule that may
            // touch four listings and one that may touch four thousand — the
            // brands and categories themselves are named where they are edited,
            // since resolving their names is a lookup a list should not make.
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            Text(
              getTranslated(rule.isNarrowed ? 'limited_to_part_of_the_catalogue' : 'whole_catalogue',
                      context) ??
                  '',
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
            ),

            if (rule.isSuspended && rule.suspensionReason != null) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _banner(
                context,
                Icons.report_gmailerrorred_outlined,
                Colors.red.shade600,
                getTranslated(rule.suspensionReason!, context) ?? rule.suspensionReason!,
              ),
            ],

            // Said plainly, because the button that would otherwise be here is
            // gone: a seller staring at a stopped rule with no way to start it
            // needs to know that is the point, not a bug.
            if (rule.isStoppedByMarketplace) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _banner(context, Icons.info_outline, Theme.of(context).hintColor,
                  getTranslated('only_the_marketplace_can_start_this_rule_again', context) ?? ''),
            ],

            const SizedBox(height: Dimensions.paddingSizeSmall),
            Wrap(spacing: Dimensions.paddingSizeSmall, runSpacing: Dimensions.paddingSizeExtraSmall, children: [
              _stat(context, getTranslated('times_run', context) ?? '', '${rule.runCount}'),
              _stat(context, getTranslated('changes_made', context) ?? '', '${rule.appliedCount}'),
              if (rule.lastRunAt != null)
                _stat(context, getTranslated('last_run', context) ?? '',
                    DateConverter.isoStringToLocalDateOnly(rule.lastRunAt!)),
            ]),

            // A rule that runs and never acts is not broken, but the seller
            // should not have to compare two numbers to notice it.
            if (rule.hasNeverActed) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _banner(context, Icons.info_outline, Theme.of(context).hintColor,
                  getTranslated('rule_has_never_changed_anything', context) ?? ''),
            ],

            const SizedBox(height: Dimensions.paddingSizeSmall),
            Row(children: [
              if (onPreview != null)
                TextButton.icon(
                  onPressed: isBusy ? null : onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(getTranslated('preview', context) ?? '',
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
                ),
              if (onRun != null && !rule.isSuspended)
                TextButton.icon(
                  onPressed: isBusy ? null : onRun,
                  icon: const Icon(Icons.play_arrow_outlined, size: 16),
                  label: Text(getTranslated('run_now', context) ?? '',
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
                ),
              const Spacer(),
              if (onStatus != null && !rule.isStoppedByMarketplace)
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () => onStatus!(rule.isActive ? 'paused' : 'active'),
                  child: Text(
                    rule.isActive
                        ? (getTranslated('pause', context) ?? '')
                        // Restarting a stopped rule and switching a paused one
                        // back on are the same act, deliberately: the reason it
                        // stopped is still on screen while it happens.
                        : (getTranslated(rule.isSuspended ? 'restart_rule' : 'resume', context) ?? ''),
                    style: robotoMedium.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: Theme.of(context).primaryColor),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Text(
        '$label: $value',
        style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
      );

  Widget _banner(BuildContext context, IconData icon, Color color, String text) => Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Expanded(
            child: Text(text,
                style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
          ),
        ]),
      );
}

/// What a rule would do right now, listed row by row.
///
/// Shows the rows it would decline as well as the ones it would change. A
/// preview that only listed the changes would let a seller think a rule covers
/// forty products when it can only act on six of them.
class AutomationPreviewWidget extends StatelessWidget {
  final AutomationPreviewModel preview;

  const AutomationPreviewWidget({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    if (preview.matched == 0) {
      return Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Text(getTranslated('nothing_matches_this_rule_right_now', context) ?? '',
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (preview.capped)
        Container(
          margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: Colors.red.shade600.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          ),
          child: Row(children: [
            Icon(Icons.block_outlined, size: 16, color: Colors.red.shade600),
            const SizedBox(width: Dimensions.paddingSizeExtraSmall),
            Expanded(
              child: Text(getTranslated('this_would_stop_instead_of_running', context) ?? '',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Colors.red.shade600)),
            ),
          ]),
        ),
      Text('${getTranslated('would_match', context) ?? ''}: ${preview.matched}',
          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      ...preview.subjects.map((subject) => Padding(
            padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                subject.willApply ? Icons.check_circle_outline : Icons.remove_circle_outline,
                size: 16,
                color: subject.willApply ? Colors.green.shade600 : Theme.of(context).hintColor,
              ),
              const SizedBox(width: Dimensions.paddingSizeExtraSmall),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(subject.label ?? '#${subject.subjectId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                  if (subject.reason != null)
                    Text(getTranslated(subject.reason!, context) ?? subject.reason!,
                        style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall,
                            color: Theme.of(context).hintColor)),
                ]),
              ),
            ]),
          )),
    ]);
  }
}

/// One thing a rule did, with the value it replaced and a way to put it back.
class AutomationActivityTileWidget extends StatelessWidget {
  final AutomationActivityModel activity;
  final VoidCallback? onRevert;
  final bool isBusy;

  const AutomationActivityTileWidget({
    super.key,
    required this.activity,
    this.onRevert,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool applied = activity.status == 'applied';

    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(activity.subjectLabel ?? '#${activity.subjectId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
          ),
          if (activity.createdAt != null)
            Text(DateConverter.isoStringToLocalDateOnly(activity.createdAt!),
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
        ]),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(getTranslated('action_${activity.action}', context) ?? activity.action,
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),

        if (!applied && activity.reason != null)
          Padding(
            padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
            child: Text(getTranslated(activity.reason!, context) ?? activity.reason!,
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
          ),

        // The value before and after is the whole point of the trail: a seller
        // who disagrees with an automated change has to be able to see exactly
        // what it was.
        if (applied && activity.before.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
            child: Text('${_describe(activity.before)} → ${_describe(activity.after)}',
                style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
          ),

        if (activity.revertedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
            child: Text(getTranslated('undone', context) ?? '',
                style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
          )
        else if (activity.revertible && onRevert != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: isBusy ? null : onRevert,
              child: Text(getTranslated('undo', context) ?? '',
                  style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: Theme.of(context).primaryColor)),
            ),
          ),
      ]),
    );
  }

  String _describe(Map<String, dynamic> values) {
    if (values.isEmpty) return '—';

    return values.entries
        .where((entry) => entry.key != 'price_after_discount')
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
  }
}
