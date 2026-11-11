import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/models/seller_insight_model.dart';
import 'package:syriacosmeticsmanger/features/action_center/widgets/insight_action_handler.dart';
import 'package:syriacosmeticsmanger/features/control_tower/controllers/control_tower_controller.dart';
import 'package:syriacosmeticsmanger/features/control_tower/domain/models/control_tower_models.dart';
import 'package:syriacosmeticsmanger/features/control_tower/widgets/control_tower_widgets.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// What is wrong, arranged by when it needs doing.
///
/// Not the Action Center, which is one flat list, and not Home, which reports
/// how the business is going. This answers a different question — what should I
/// do next — and the sections are the answer rather than a way of organising
/// one.
///
/// A section with nothing in it is not rendered. An empty heading is the screen
/// taking up space to say nothing, and a seller learns to scroll past headings.
class ControlTowerScreen extends StatefulWidget {
  const ControlTowerScreen({super.key});

  @override
  State<ControlTowerScreen> createState() => _ControlTowerScreenState();
}

class _ControlTowerScreenState extends State<ControlTowerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Provider.of<ControlTowerController>(context, listen: false).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('control_tower', context)),
      body: Consumer<ControlTowerController>(
        builder: (context, tower, _) {
          final List<TowerSectionModel> sections = tower.sections;

          return RefreshIndicator(
            onRefresh: tower.load,
            color: Theme.of(context).cardColor,
            backgroundColor: Theme.of(context).primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                if (tower.briefing != null) DailyBriefingWidget(briefing: tower.briefing!),
                const SizedBox(height: Dimensions.paddingSizeLarge),

                if (sections.isEmpty)
                  SizedBox(
                    height: 240,
                    child: Center(
                      child: tower.isLoading
                          ? CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))
                          : Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade600),
                              const SizedBox(height: Dimensions.paddingSizeSmall),
                              // Nothing wrong is a real answer and the best one.
                              Text(getTranslated('nothing_needs_attention', context) ?? '',
                                  textAlign: TextAlign.center,
                                  style: robotoRegular.copyWith(
                                      fontSize: Dimensions.fontSizeSmall,
                                      color: Theme.of(context).hintColor)),
                            ]),
                    ),
                  )
                else
                  ...sections.map((section) => _section(context, tower, section)),

                if (tower.tower != null && tower.tower!.health.isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  Text(getTranslated('system_health', context) ?? '',
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  DomainHealthGridWidget(health: tower.tower!.health),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, ControlTowerController tower, TowerSectionModel section) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(getTranslated('tower_${section.key}', context) ?? section.key,
              style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
        ),
        // The number a seller acts on: how many things, not how many rows.
        Text(
          section.affected > section.count
              ? '${section.affected} ${getTranslated('affected', context) ?? ''}'
              : '${section.count}',
          style: robotoMedium.copyWith(
              fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
        ),
      ]),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      ...section.issues.map((issue) => Padding(
            padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
            child: IssueCardWidget(
              issue: issue,
              isUpdating: tower.updatingIssueId == issue.id,
              onTap: () => InsightActionHandler.open(context, _asInsight(issue)),
              onStatus: (status) => tower.setStatus(issue.id, status),
            ),
          )),
      if (section.count > section.issues.length)
        Padding(
          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
          child: Text(
            '+${section.count - section.issues.length} ${getTranslated('more_waiting', context) ?? ''}',
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
          ),
        ),
      const SizedBox(height: Dimensions.paddingSizeDefault),
    ]);
  }

  /// Reuse the Action Center's navigation rather than writing a second one.
  ///
  /// Both surfaces read the same issue store and both open the same records; two
  /// handlers would be two chances for the same tap to land somewhere different.
  SellerInsightModel _asInsight(IssueModel issue) => SellerInsightModel(
        id: issue.id,
        type: issue.type,
        severity: issue.severity,
        title: issue.title,
        body: issue.body,
        entityType: issue.entityType,
        entityId: issue.entityId,
        actionKey: issue.actionKey,
        actionParams: issue.actionParams,
        dismissible: issue.dismissible,
      );
}
