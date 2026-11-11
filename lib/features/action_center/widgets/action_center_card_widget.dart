import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/action_center/controllers/action_center_controller.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/models/seller_insight_model.dart';
import 'package:syriacosmeticsmanger/features/action_center/screens/action_center_screen.dart';
import 'package:syriacosmeticsmanger/features/action_center/widgets/action_center_widgets.dart';
import 'package:syriacosmeticsmanger/features/action_center/widgets/insight_action_handler.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// What needs attention, at the top of the home feed.
///
/// It disappears entirely when nothing is waiting rather than showing a cheerful
/// empty state. A card that is always there stops being read; one that only
/// appears when something is wrong is worth looking at.
class ActionCenterCardWidget extends StatelessWidget {
  /// How many insights to name before the card stops listing and starts counting.
  static const int _previewCount = 3;

  const ActionCenterCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActionCenterController>(
      builder: (context, actions, _) {
        final List<SellerInsightModel> insights = actions.insights;
        if (insights.isEmpty) return const SizedBox();

        final List<SellerInsightModel> preview = insights.take(_previewCount).toList();
        final int remaining = insights.length - preview.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
          child: Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: .08)),
              boxShadow: [
                BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: .05),
                    spreadRadius: -3, blurRadius: 12, offset: Offset.fromDirection(0, 6)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(getTranslated('action_center', context) ?? '',
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                if (actions.urgentCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(Dimensions.radiusPill),
                    ),
                    child: Text('${actions.urgentCount}',
                        style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall,
                            color: Theme.of(context).colorScheme.error)),
                  ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ActionCenterScreen())),
                  child: Row(children: [
                    Text(getTranslated('view_all', context) ?? '',
                        style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor)),
                    Icon(Icons.arrow_forward_ios_rounded, size: Dimensions.fontSizeSmall,
                        color: Theme.of(context).primaryColor),
                  ]),
                ),
              ]),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              ...preview.map((insight) => Padding(
                    padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
                    child: InsightCardWidget(
                      insight: insight,
                      onTap: () => InsightActionHandler.open(context, insight),
                    ),
                  )),

              if (remaining > 0)
                Text('+$remaining ${getTranslated('more_waiting', context) ?? ''}',
                    style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
            ]),
          ),
        );
      },
    );
  }
}
