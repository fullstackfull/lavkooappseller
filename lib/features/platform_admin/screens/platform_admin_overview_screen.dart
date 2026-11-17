import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_state_widgets.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_choice_chips.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_market_card.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The state of the markets the admin is allowed to see: a card for each, over a
/// window of days, counted by the server when the screen asked.
///
/// The market chosen here is the market of every screen of the shell. The figures
/// of one market are never added to another's, and there is no money on this
/// screen: sales say why they are not reported.
class PlatformAdminOverviewScreen extends StatelessWidget {
  const PlatformAdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformAdminController>(
      builder: (BuildContext context, PlatformAdminController controller, _) {
        final PlatformOverviewModel? overview = controller.overview;
        final PlatformAdminFailure? failure = controller.overviewFailure;

        return RefreshIndicator(
          onRefresh: () => controller.loadOverview(force: true),
          color: Theme.of(context).cardColor,
          backgroundColor: Theme.of(context).primaryColor,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            children: [
              if (controller.isRestricted) ...[
                PlatformAdminNote(
                    text: getTranslated('platform_admin_restricted_view', context)!, icon: Icons.visibility_outlined),
                const SizedBox(height: Dimensions.paddingSizeDefault),
              ],
              PlatformMarketSelector(controller: controller, onChanged: () => controller.loadOverview()),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _WindowSelector(controller: controller),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              if (overview != null && controller.hasOverview) _Provenance(overview: overview),
              if (failure != null && controller.hasOverview) ...[
                const SizedBox(height: Dimensions.paddingSizeSmall),
                PlatformAdminFailureBanner(failure: failure),
              ],
              const SizedBox(height: Dimensions.paddingSizeDefault),
              ..._body(context, controller, overview, failure),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, PlatformAdminController controller, PlatformOverviewModel? overview,
      PlatformAdminFailure? failure) {
    if (overview != null && controller.hasOverview) {
      return _cards(context, controller, overview);
    }
    if (failure != null) {
      return [
        SizedBox(
          height: 320,
          child: PlatformAdminFailureView(
            failure: failure,
            onRetry: () => controller.loadOverview(force: true),
            onBackToAllMarkets: () {
              controller.selectMarket(PlatformMarketCode.all);
              controller.loadOverview();
            },
          ),
        ),
      ];
    }
    return const [SizedBox(height: 320, child: PlatformAdminLoader())];
  }

  List<Widget> _cards(BuildContext context, PlatformAdminController controller, PlatformOverviewModel overview) {
    if (overview.markets.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Text(
            getTranslated('platform_admin_no_markets', context)!,
            textAlign: TextAlign.center,
            style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      ];
    }

    return [
      for (final PlatformMarketOverview market in overview.markets) ...[
        PlatformMarketCard(overview: market, market: controller.marketInfo(market.market)),
        const SizedBox(height: Dimensions.paddingSizeDefault),
      ],
      if (overview.unattributed != null) PlatformUnattributedCard(unattributed: overview.unattributed!),
      const SizedBox(height: Dimensions.paddingSizeLarge),
    ];
  }
}

/// All markets, or one of the markets the server lists for this admin. It is the
/// same choice on every screen that has one, so it is made once and kept.
class PlatformMarketSelector extends StatelessWidget {
  final PlatformAdminController controller;

  /// What the screen asks for again once the choice has been made.
  final VoidCallback onChanged;

  const PlatformMarketSelector({super.key, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PlatformChipRow<String>(
      selected: controller.market,
      options: [
        PlatformChipOption<String>(
          value: PlatformMarketCode.all,
          label: PlatformAdminTexts.allMarkets(context, restricted: controller.isRestricted),
        ),
        for (final PlatformMarketModel market in controller.markets)
          PlatformChipOption<String>(value: market.code, label: PlatformAdminTexts.marketName(context, market.code)),
      ],
      onSelected: (String market) {
        controller.selectMarket(market);
        onChanged();
      },
    );
  }
}

class _WindowSelector extends StatelessWidget {
  final PlatformAdminController controller;

  const _WindowSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    // Until the choice is made the server counts its own window, and the chip that
    // matches what it says it counted is the one that is lit.
    final int? shown = controller.windowDays ?? controller.overview?.window?.days;

    return PlatformChipRow<int>(
      selected: shown,
      options: [
        for (final int days in PlatformWindows.choices)
          PlatformChipOption<int>(value: days, label: PlatformAdminTexts.windowLabel(context, days)),
      ],
      onSelected: (int days) {
        controller.selectWindow(days);
        controller.loadOverview();
      },
    );
  }
}

/// What the figures are about and how old they are: the days they count, and when.
class _Provenance extends StatelessWidget {
  final PlatformOverviewModel overview;

  const _Provenance({required this.overview});

  @override
  Widget build(BuildContext context) {
    final PlatformWindowModel? window = overview.window;
    final TextStyle style =
        robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (window != null) Text(PlatformAdminTexts.windowSummary(context, window), style: style),
      if (window != null && window.clamped) Text(getTranslated('platform_admin_window_cut', context)!, style: style),
      Text(PlatformAdminTexts.freshness(context, overview.freshness, overview.generatedAt), style: style),
    ]);
  }
}
