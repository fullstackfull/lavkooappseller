import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_severity_style.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// One thing the platform noticed in a market.
///
/// It says what it is about in the viewer's language, by its code, and gives the
/// server's own sentence under it for the count. It opens the market it is about
/// when there is a market to open.
class PlatformAlertTile extends StatelessWidget {
  final PlatformAlertModel alert;

  /// Null when the alert cannot be opened: no link the app can route, or a market
  /// this viewer may not see.
  final VoidCallback? onOpen;

  const PlatformAlertTile({super.key, required this.alert, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final Color color = PlatformSeverityStyle.color(context, alert.severity);

    return Semantics(
      button: onOpen != null,
      hint: onOpen == null ? null : getTranslated('platform_admin_open_market', context),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(color: color.withValues(alpha: .25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(PlatformSeverityStyle.icon(alert.severity), color: color, size: Dimensions.iconSizeDefault),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    PlatformAdminTexts.alertTitle(context, alert.code),
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.message,
                    style:
                        robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Wrap(
                      spacing: Dimensions.paddingSizeExtraSmall,
                      runSpacing: Dimensions.paddingSizeExtraSmall,
                      children: [
                        _tag(PlatformAdminTexts.severity(context, alert.severity), color),
                        _tag(PlatformAdminTexts.marketName(context, alert.market), Theme.of(context).hintColor),
                      ]),
                ]),
              ),
              if (onOpen != null) Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeOrder),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(Dimensions.radiusPill)),
        child: Text(label, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
      );
}
