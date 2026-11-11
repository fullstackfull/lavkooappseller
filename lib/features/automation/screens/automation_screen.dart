import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/automation/controllers/automation_controller.dart';
import 'package:syriacosmeticsmanger/features/automation/domain/models/automation_models.dart';
import 'package:syriacosmeticsmanger/features/automation/screens/automation_rule_form_screen.dart';
import 'package:syriacosmeticsmanger/features/automation/widgets/automation_widgets.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The seller's rules, and everything those rules have done to the shop.
///
/// Two tabs rather than one screen: writing a rule and auditing what rules did
/// are different jobs done at different times, and a seller checking a change
/// they did not make should not have to scroll past a form to find it.
class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Provider.of<AutomationController>(context, listen: false).load(),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('automation', context)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () => _openForm(context, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(children: [
        TabBar(
          controller: _tabs,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Theme.of(context).hintColor,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(text: getTranslated('rules', context)),
            Tab(text: getTranslated('what_automation_did', context)),
          ],
        ),
        Expanded(
          child: Consumer<AutomationController>(
            builder: (context, automation, _) {
              if (automation.isLoading) {
                return Center(
                  child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
                );
              }

              return TabBarView(controller: _tabs, children: [
                _rules(context, automation),
                _activity(context, automation),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _rules(BuildContext context, AutomationController automation) {
    if (automation.rules.isEmpty) {
      return _empty(context, Icons.auto_mode_outlined, 'no_rules_yet', 'rules_explained');
    }

    return RefreshIndicator(
      onRefresh: automation.load,
      color: Theme.of(context).cardColor,
      backgroundColor: Theme.of(context).primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        itemCount: automation.rules.length,
        itemBuilder: (context, index) {
          final AutomationRuleModel rule = automation.rules[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
            child: AutomationRuleCardWidget(
              rule: rule,
              isBusy: automation.isBusy,
              onTap: () => _openForm(context, rule),
              onPreview: () => _showPreview(context, automation, rule),
              onRun: () => automation.runRule(rule.id),
              onStatus: (status) => automation.setStatus(rule.id, status),
            ),
          );
        },
      ),
    );
  }

  Widget _activity(BuildContext context, AutomationController automation) {
    if (automation.activity.isEmpty) {
      return _empty(context, Icons.history_outlined, 'automation_has_done_nothing_yet',
          'automation_trail_explained');
    }

    return RefreshIndicator(
      onRefresh: () => automation.loadActivity(),
      color: Theme.of(context).cardColor,
      backgroundColor: Theme.of(context).primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        itemCount: automation.activity.length,
        itemBuilder: (context, index) {
          final AutomationActivityModel row = automation.activity[index];

          return AutomationActivityTileWidget(
            activity: row,
            isBusy: automation.isBusy,
            onRevert: () => automation.revert(row.id),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, IconData icon, String title, String body) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Theme.of(context).hintColor),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(getTranslated(title, context) ?? '',
                textAlign: TextAlign.center,
                style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            Text(getTranslated(body, context) ?? '',
                textAlign: TextAlign.center,
                style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
          ]),
        ),
      );

  Future<void> _openForm(BuildContext context, AutomationRuleModel? rule) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AutomationRuleFormScreen(rule: rule),
    ));
  }

  /// The preview is a sheet rather than a screen: it answers one question and
  /// the seller goes straight back to the rule they asked it about.
  Future<void> _showPreview(
    BuildContext context,
    AutomationController automation,
    AutomationRuleModel rule,
  ) async {
    automation.loadPreview(rule.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
      ),
      builder: (_) => Consumer<AutomationController>(
        builder: (context, live, __) => Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rule.name, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(getTranslated('preview_changes_nothing', context) ?? '',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              if (live.preview == null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
                  ),
                )
              else
                AutomationPreviewWidget(preview: live.preview!),
              const SizedBox(height: Dimensions.paddingSizeLarge),
            ]),
          ),
        ),
      ),
    );

    automation.clearPreview();
  }
}
