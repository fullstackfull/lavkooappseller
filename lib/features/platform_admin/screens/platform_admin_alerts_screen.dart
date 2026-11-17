import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_overview_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_state_widgets.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_alert_tile.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_choice_chips.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// What the platform has noticed in the markets the admin may see, worst first.
///
/// The market is the market of the whole shell, chosen with the same selector as
/// on the overview. An alert that links to a market opens it.
class PlatformAdminAlertsScreen extends StatelessWidget {
  /// Opens the market an alert is about, on the screen that shows its card.
  final ValueChanged<String> onOpenMarket;

  const PlatformAdminAlertsScreen({super.key, required this.onOpenMarket});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformAdminController>(
      builder: (BuildContext context, PlatformAdminController controller, _) {
        final PlatformAdminFailure? failure = controller.alertsFailure;
        final bool hasList = controller.hasAlertList;

        return RefreshIndicator(
          onRefresh: () => controller.loadAlerts(force: true),
          color: Theme.of(context).cardColor,
          backgroundColor: Theme.of(context).primaryColor,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            children: [
              PlatformMarketSelector(controller: controller, onChanged: () => controller.loadAlerts()),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              PlatformChipRow<String?>(
                selected: controller.alertSeverity,
                options: [
                  PlatformChipOption<String?>(
                      value: null, label: getTranslated('platform_admin_severity_all', context)!),
                  for (final String severity in PlatformSeverity.all)
                    PlatformChipOption<String?>(value: severity, label: PlatformAdminTexts.severity(context, severity)),
                ],
                onSelected: (String? severity) {
                  controller.selectAlertSeverity(severity);
                  controller.loadAlerts();
                },
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              if (failure != null && hasList) ...[
                PlatformAdminFailureBanner(failure: failure),
                const SizedBox(height: Dimensions.paddingSizeSmall),
              ],
              ..._body(context, controller, failure, hasList),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body(
      BuildContext context, PlatformAdminController controller, PlatformAdminFailure? failure, bool hasList) {
    if (!hasList && failure != null) {
      return [
        SizedBox(
          height: 320,
          child: PlatformAdminFailureView(
            failure: failure,
            onRetry: () => controller.loadAlerts(force: true),
            onBackToAllMarkets: () {
              controller.selectMarket(PlatformMarketCode.all);
              controller.loadAlerts();
            },
          ),
        ),
      ];
    }
    if (!hasList) return const [SizedBox(height: 320, child: PlatformAdminLoader())];

    if (controller.alerts.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Text(
            getTranslated('platform_admin_no_alerts', context)!,
            textAlign: TextAlign.center,
            style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      ];
    }

    return [
      for (final PlatformAlertModel alert in controller.alerts)
        Padding(
          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
          child: PlatformAlertTile(
            alert: alert,
            onOpen: controller.canOpen(alert) ? () => onOpenMarket(alert.link!.market) : null,
          ),
        ),
      if (controller.alertsHaveMore)
        Center(
          child: controller.isLoadingMoreAlerts
              ? const Padding(
                  padding: EdgeInsets.all(Dimensions.paddingSizeDefault),
                  child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: controller.loadMoreAlerts,
                  child: Text(getTranslated('platform_admin_load_more', context)!)),
        ),
      const SizedBox(height: Dimensions.paddingSizeLarge),
    ];
  }
}
