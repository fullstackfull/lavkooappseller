import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// One device that holds a session of this admin.
///
/// The session in use is marked and cannot be ended from here: that is signing
/// out, which has its own button. Any other can be ended, which signs that
/// device out on its next request; while one is being ended, the others wait.
class PlatformSessionTile extends StatelessWidget {
  final PlatformSessionModel session;
  final bool isEnding;

  /// Null while a session is being ended, which leaves the button there and not pressable.
  final VoidCallback? onEnd;

  const PlatformSessionTile({super.key, required this.session, this.isEnding = false, this.onEnd});

  @override
  Widget build(BuildContext context) {
    final DateTime? lastUsedAt = session.lastUsedAt;
    final DateTime? createdAt = session.createdAt;
    final DateTime? expiresAt = session.expiresAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(
          color: session.isCurrent
              ? Theme.of(context).primaryColor.withValues(alpha: .4)
              : Theme.of(context).hintColor.withValues(alpha: .15),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.phone_android_outlined, size: Dimensions.iconSizeMedium, color: Theme.of(context).primaryColor),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Wrap(
                spacing: Dimensions.paddingSizeSmall,
                runSpacing: Dimensions.paddingSizeExtraSmall,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(session.deviceName, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
                  if (session.isCurrent) _badge(context, getTranslated('platform_admin_this_device', context)!),
                ]),
          ),
        ]),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        if (createdAt != null)
          _line(context, getTranslated('platform_admin_signed_in_at', context)!, PlatformAdminTexts.moment(createdAt)),
        _line(
          context,
          getTranslated('platform_admin_last_used', context)!,
          lastUsedAt == null
              ? getTranslated('platform_admin_not_used_yet', context)!
              : PlatformAdminTexts.moment(lastUsedAt),
        ),
        if (expiresAt != null)
          _line(context, getTranslated('platform_admin_expires', context)!, PlatformAdminTexts.moment(expiresAt)),
        if (session.mfaMethod != null)
          _line(context, getTranslated('platform_admin_second_factor', context)!,
              PlatformAdminTexts.mfaMethodName(context, session.mfaMethod!)),
        if (!session.isCurrent) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: isEnding
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton.icon(
                    onPressed: onEnd,
                    icon: Icon(Icons.logout_rounded,
                        size: Dimensions.iconSizeDefault, color: Theme.of(context).colorScheme.error),
                    label: Text(
                      getTranslated('platform_admin_end_session', context)!,
                      style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).colorScheme.error),
                    ),
                  ),
          ),
        ],
      ]),
    );
  }

  Widget _badge(BuildContext context, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(Dimensions.radiusPill),
        ),
        child: Text(label,
            style:
                robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).primaryColor)),
      );

  Widget _line(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Wrap(spacing: Dimensions.paddingSizeExtraSmall, children: [
          Text('$label:',
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
          Text(value, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
        ]),
      );
}
