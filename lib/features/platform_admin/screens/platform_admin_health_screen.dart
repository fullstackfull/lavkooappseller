import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_health_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_overview_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_state_widgets.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_health_card.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Whether the machinery of each market is working: the payment attempts that
/// never came back, and the integrations that have stopped syncing (L-09).
///
/// Counts and timestamps, which is all the server sends. Rows whose market the
/// platform does not record come last and say so, because a market that sold
/// nothing must never be made to look busy by another market's rows.
///
/// The sentence under each figure is the SERVER'S, not the app's: a stuck
/// payment attempt is not a failed one, and a channel resource and a carrier
/// capability are called failing by different tests. Writing those sentences
/// here would leave a stale explanation on the screen the day a definition
/// changes.
class PlatformAdminHealthScreen extends StatelessWidget {
  const PlatformAdminHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformAdminController>(
      builder: (BuildContext context, PlatformAdminController controller, _) {
        final PlatformAdminFailure? failure = controller.healthFailure;
        final PlatformHealthModel? health = controller.health;

        return RefreshIndicator(
          onRefresh: () => controller.loadHealth(force: true),
          color: Theme.of(context).cardColor,
          backgroundColor: Theme.of(context).primaryColor,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            children: [
              PlatformMarketSelector(controller: controller, onChanged: () => controller.loadHealth()),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              if (failure != null && health != null) ...[
                PlatformAdminFailureBanner(failure: failure),
                const SizedBox(height: Dimensions.paddingSizeSmall),
              ],
              ..._body(context, controller, health, failure),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body(
    BuildContext context,
    PlatformAdminController controller,
    PlatformHealthModel? health,
    PlatformAdminFailure? failure,
  ) {
    if (health == null && failure != null) {
      return [
        SizedBox(
          height: 320,
          child: PlatformAdminFailureView(
            failure: failure,
            onRetry: () => controller.loadHealth(force: true),
            onBackToAllMarkets: () {
              controller.selectMarket(PlatformMarketCode.all);
              controller.loadHealth();
            },
          ),
        ),
      ];
    }
    if (health == null) return const [SizedBox(height: 320, child: PlatformAdminLoader())];

    final List<PlatformMarketHealth> rows = health.rows;

    if (rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Text(
            getTranslated('platform_admin_no_health', context)!,
            textAlign: TextAlign.center,
            style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      ];
    }

    return [
      for (final PlatformMarketHealth row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
          child: PlatformHealthCard(health: row, means: health.means),
        ),
      ...[
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text(
          PlatformAdminTexts.freshness(context, health.freshness, health.generatedAt),
          textAlign: TextAlign.center,
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
        ),
      ],
      const SizedBox(height: Dimensions.paddingSizeLarge),
    ];
  }
}
