import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The spinner of the app, centred.
class PlatformAdminLoader extends StatelessWidget {
  const PlatformAdminLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
    );
  }
}

/// A call that came to nothing, said once, with the way out.
///
/// The no-connection look is the one the splash screen already has: the icon, a
/// title, one line of what to do, and Retry.
class PlatformAdminFailureView extends StatelessWidget {
  final PlatformAdminFailure failure;

  /// Asking again. Not offered for a market the viewer may not see.
  final VoidCallback? onRetry;

  /// The way out of a market the viewer may not see.
  final VoidCallback? onBackToAllMarkets;

  const PlatformAdminFailureView({super.key, required this.failure, this.onRetry, this.onBackToAllMarkets});

  @override
  Widget build(BuildContext context) {
    final String? hint = PlatformAdminTexts.failureHint(context, failure);
    final bool notAllowed = failure.kind == PlatformAdminFailureKind.marketNotAllowed;

    // Asking again for what the grant does not include would only be refused again.
    final bool refused = notAllowed || failure.kind == PlatformAdminFailureKind.capabilityNotAllowed;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(PlatformAdminTexts.failureIcon(failure), size: 44, color: Theme.of(context).hintColor),
          const SizedBox(height: Dimensions.paddingSize),
          Text(
            PlatformAdminTexts.failureTitle(context, failure),
            textAlign: TextAlign.center,
            style: titilliumSemiBold.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          if (hint != null) ...[
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: robotoRegular.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall),
            ),
          ],
          const SizedBox(height: Dimensions.paddingSizeLarge),
          if (notAllowed && onBackToAllMarkets != null)
            ElevatedButton(
              onPressed: onBackToAllMarkets,
              child: Text(getTranslated('platform_admin_back_to_all_markets', context)!),
            )
          else if (!refused && onRetry != null)
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: Dimensions.iconSizeDefault),
              label: Text(getTranslated('retry', context)!),
            ),
        ]),
      ),
    );
  }
}

/// A line of context above the content: a note that is not an error.
class PlatformAdminNote extends StatelessWidget {
  final String text;
  final IconData icon;

  /// Puts the note away. Without it the note stays.
  final VoidCallback? onDismiss;

  const PlatformAdminNote({super.key, required this.text, this.icon = Icons.info_outline, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: Dimensions.iconSizeDefault, color: Theme.of(context).primaryColor),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: Text(text, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall))),
        if (onDismiss != null)
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(Dimensions.radiusPill),
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeVeryTiny),
              child:
                  Icon(Icons.close, size: Dimensions.iconSizeDefault, semanticLabel: getTranslated('dismiss', context)),
            ),
          ),
      ]),
    );
  }
}

/// A failure of a screen that still has what it showed a moment ago: the failure
/// is said above it, and the figures stay where they were.
class PlatformAdminFailureBanner extends StatelessWidget {
  final PlatformAdminFailure failure;

  /// What to say instead of the failure's own title, where the screen knows better.
  final String? message;

  const PlatformAdminFailureBanner({super.key, required this.failure, this.message});

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(PlatformAdminTexts.failureIcon(failure), size: Dimensions.iconSizeDefault, color: color),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(
          child: Text(
            message ?? PlatformAdminTexts.failureTitle(context, failure),
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: color),
          ),
        ),
      ]),
    );
  }
}
