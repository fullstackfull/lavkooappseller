import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/action_center/controllers/action_center_controller.dart';
import 'package:syriacosmeticsmanger/features/action_center/domain/models/seller_insight_model.dart';
import 'package:syriacosmeticsmanger/features/action_center/widgets/action_center_widgets.dart';
import 'package:syriacosmeticsmanger/features/action_center/widgets/insight_action_handler.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Everything waiting for the seller, in one list, worst first.
///
/// Before this each screen counted its own problems and none of them agreed: the
/// dashboard knew about unchecked orders, the stock page about low stock, the
/// scorecard about breaches, and nothing told a seller what to do first. This
/// reads the one insight store, so home and this list cannot contradict each
/// other.
///
/// An empty list is a real answer. Nothing here is produced to fill the screen.
class ActionCenterScreen extends StatefulWidget {
  const ActionCenterScreen({super.key});

  @override
  State<ActionCenterScreen> createState() => _ActionCenterScreenState();
}

class _ActionCenterScreenState extends State<ActionCenterScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<ActionCenterController>(context, listen: false).getInsights(clearSeverity: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('action_center', context)),
      body: Consumer<ActionCenterController>(
        builder: (context, actions, _) {
          final List<SellerInsightModel> insights = actions.insights;

          return Column(children: [
            const SizedBox(height: Dimensions.paddingSizeSmall),
            InsightSeverityFilterWidget(
              selected: actions.severity,
              counts: actions.actionCenter?.counts ?? const <String, int>{},
              onChanged: (severity) => severity == null
                  ? actions.getInsights(clearSeverity: true)
                  : actions.getInsights(severity: severity),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => actions.getInsights(),
                color: Theme.of(context).cardColor,
                backgroundColor: Theme.of(context).primaryColor,
                child: insights.isEmpty
                    ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * .6,
                          child: Center(
                            child: actions.isLoading
                                ? CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))
                                : Column(mainAxisSize: MainAxisSize.min, children: [
                                    const NoDataScreen(),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
                                      // An empty Action Center is a good day, not a broken screen.
                                      child: Text(getTranslated('nothing_needs_attention', context) ?? '',
                                          textAlign: TextAlign.center,
                                          style: robotoRegular.copyWith(
                                              fontSize: Dimensions.fontSizeSmall,
                                              color: Theme.of(context).hintColor)),
                                    ),
                                  ]),
                          ),
                        ),
                      ])
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                        itemCount: insights.length,
                        separatorBuilder: (_, __) => const SizedBox(height: Dimensions.paddingSizeSmall),
                        itemBuilder: (context, index) {
                          final SellerInsightModel insight = insights[index];
                          return InsightCardWidget(
                            insight: insight,
                            onTap: () => InsightActionHandler.open(context, insight),
                            onDismiss: insight.dismissible ? () => actions.dismiss(insight.id) : null,
                          );
                        },
                      ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
