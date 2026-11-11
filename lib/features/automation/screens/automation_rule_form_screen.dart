import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/automation/controllers/automation_controller.dart';
import 'package:syriacosmeticsmanger/features/automation/domain/models/automation_models.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Writing or rewriting one rule.
///
/// The form is built from the server's catalogue rather than from a list in the
/// app: which actions a trigger accepts, and which settings each one needs, are
/// the server's answer. A hard-coded form would let a seller build a rule the
/// server then refuses, or hide a trigger the server has started offering.
class AutomationRuleFormScreen extends StatefulWidget {
  final AutomationRuleModel? rule;

  const AutomationRuleFormScreen({super.key, this.rule});

  @override
  State<AutomationRuleFormScreen> createState() => _AutomationRuleFormScreenState();
}

class _AutomationRuleFormScreenState extends State<AutomationRuleFormScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _cap = TextEditingController(text: '50');
  final TextEditingController _cooldown = TextEditingController(text: '15');
  final Map<String, TextEditingController> _settings = <String, TextEditingController>{};

  String? _trigger;
  String? _action;

  @override
  void initState() {
    super.initState();

    final AutomationRuleModel? rule = widget.rule;
    if (rule != null) {
      _name.text = rule.name;
      _trigger = rule.trigger;
      _action = rule.action;
      _cap.text = '${rule.maxActionsPerRun}';
      _cooldown.text = '${rule.cooldownMinutes}';
      rule.triggerSettings.forEach((key, value) => _controller('trigger_settings.$key').text = '$value');
      rule.actionSettings.forEach((key, value) => _controller('action_settings.$key').text = '$value');
      // The scope arrives as id lists and is edited as text, the same way the
      // web edits it until there is a picker on both.
      rule.scope.forEach((key, value) =>
          _controller('scope.$key').text = value is List ? value.join(',') : '$value');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _cap.dispose();
    _cooldown.dispose();
    for (final TextEditingController controller in _settings.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String key) =>
      _settings.putIfAbsent(key, () => TextEditingController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: getTranslated(widget.rule == null ? 'new_rule' : 'edit_rule', context),
      ),
      body: Consumer<AutomationController>(
        builder: (context, automation, _) {
          final AutomationCatalogueModel? catalogue = automation.catalogue;

          if (catalogue == null) {
            return Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
            );
          }

          final AutomationTriggerOption? trigger =
              _trigger == null ? null : catalogue.trigger(_trigger!);
          final AutomationActionOption? action = _action == null ? null : catalogue.action(_action!);

          return ListView(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            children: [
              _field(context, _name, 'rule_name', automation.fieldErrors['name']),
              const SizedBox(height: Dimensions.paddingSizeDefault),

              _dropdown(
                context,
                label: 'when',
                value: _trigger,
                options: catalogue.triggers.map((t) => t.key).toList(),
                prefix: 'trigger_',
                error: automation.fieldErrors['trigger'],
                onChanged: (value) => setState(() {
                  _trigger = value;
                  // The action may no longer be legal for the new trigger. Kept
                  // when it still is, so changing a threshold's trigger does not
                  // silently discard the action the seller already chose.
                  final AutomationTriggerOption? next = catalogue.trigger(value ?? '');
                  if (next != null && _action != null && !next.actions.contains(_action)) {
                    _action = null;
                  }
                }),
              ),

              if (trigger != null) ..._settingFields(context, automation, 'trigger_settings', trigger.fields),

              const SizedBox(height: Dimensions.paddingSizeDefault),
              _dropdown(
                context,
                label: 'then',
                value: _action,
                // Only the actions this trigger accepts. The server refuses the
                // rest, and offering them would be an invitation to be refused.
                options: trigger?.actions ?? const <String>[],
                prefix: 'action_',
                error: automation.fieldErrors['action'],
                onChanged: (value) => setState(() => _action = value),
              ),

              if (action != null) ...[
                // The safety class is the server's answer, shown where the
                // choice is made rather than discovered when saving is refused.
                _classification(context, action.classification),
                ..._settingFields(context, automation, 'action_settings', action.fields),
              ],

              const SizedBox(height: Dimensions.paddingSizeLarge),
              Text(getTranslated('limits', context) ?? '',
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(getTranslated('limits_explained', context) ?? '',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _field(context, _cap, 'most_changes_in_one_run',
                  automation.fieldErrors['max_actions_per_run'], numeric: true),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _field(context, _cooldown, 'wait_between_runs_minutes',
                  automation.fieldErrors['cooldown_minutes'], numeric: true),

              const SizedBox(height: Dimensions.paddingSizeLarge),
              Text(getTranslated('scope', context) ?? '',
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(getTranslated('scope_explained', context) ?? '',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
              ..._settingFields(context, automation, 'scope', catalogue.scope),

              const SizedBox(height: Dimensions.paddingSizeExtraLarge),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: automation.isBusy || !(action?.classification.isSafe ?? true)
                      ? null
                      : () => _save(context, automation),
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  child: Text(getTranslated('save', context) ?? '',
                      style: robotoMedium.copyWith(color: Colors.white)),
                ),
              ),

              if (widget.rule != null) ...[
                const SizedBox(height: Dimensions.paddingSizeSmall),
                TextButton(
                  onPressed: automation.isBusy ? null : () => _confirmDelete(context, automation),
                  child: Text(getTranslated('delete_rule', context) ?? '',
                      style: robotoMedium.copyWith(color: Colors.red.shade600)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// One control per setting, each of the kind the server said it needs.
  ///
  /// Nothing here knows what a threshold or a discount is. Before the server
  /// described its fields this method had to name `discount_type` as the one
  /// setting that is not a number, which meant the app carried a fact about the
  /// domain that only the server should own — and rendered a free-text box for
  /// a value with exactly two legal answers.
  List<Widget> _settingFields(
    BuildContext context,
    AutomationController automation,
    String bag,
    List<AutomationSettingField> fields,
  ) =>
      fields
          .map((field) => Padding(
                padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
                child: field.isChoice
                    ? _dropdown(
                        context,
                        label: 'setting_${field.key}',
                        value: _controller('$bag.${field.key}').text.isEmpty
                            ? null
                            : _controller('$bag.${field.key}').text,
                        options: field.options,
                        prefix: 'option_',
                        error: automation.fieldErrors['$bag.${field.key}'],
                        onChanged: (value) =>
                            setState(() => _controller('$bag.${field.key}').text = value ?? ''),
                      )
                    : _field(
                        context,
                        _controller('$bag.${field.key}'),
                        'setting_${field.key}',
                        automation.fieldErrors['$bag.${field.key}'],
                        numeric: field.isNumeric,
                        decimals: field.allowsDecimals,
                        help: _bounds(context, field),
                      ),
              ))
          .toList();

  /// What the server will accept, said before it is typed rather than after.
  String? _bounds(BuildContext context, AutomationSettingField field) {
    if (field.isIdList) return getTranslated('comma_separated_ids', context);
    if (field.min == null && field.max == null) return null;

    final String from = _plain(field.min);
    final String to = _plain(field.max);

    if (field.min != null && field.max != null) {
      return '${getTranslated('between', context) ?? ''} $from – $to';
    }

    return field.min != null
        ? '${getTranslated('at_least', context) ?? ''} $from'
        : '${getTranslated('at_most', context) ?? ''} $to';
  }

  String _plain(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? '${value.toInt()}' : '$value';
  }

  Widget _classification(BuildContext context, AutomationClassification classification) => Padding(
        padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            classification.isSafe ? Icons.check_circle_outline : Icons.block,
            size: Dimensions.fontSizeDefault,
            color: classification.isSafe ? Colors.green.shade600 : Theme.of(context).hintColor,
          ),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                getTranslated('automation_class_${classification.type}', context) ?? '',
                style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
              ),
              if (classification.reason != null)
                Text(
                  getTranslated(classification.reason!, context) ?? '',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                ),
            ]),
          ),
        ]),
      );

  Widget _field(
    BuildContext context,
    TextEditingController controller,
    String label,
    String? error, {
    bool numeric = false,
    bool decimals = true,
    String? help,
  }) =>
      TextField(
        controller: controller,
        keyboardType:
            numeric ? TextInputType.numberWithOptions(decimal: decimals) : TextInputType.text,
        inputFormatters: numeric
            // A whole-number setting refuses a decimal point at the keyboard,
            // because the server refuses it at the validator.
            ? [FilteringTextInputFormatter.allow(decimals ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'))]
            : const <TextInputFormatter>[],
        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
        decoration: InputDecoration(
          labelText: getTranslated(label, context) ?? label,
          helperText: help,
          helperStyle: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
          // The server said which field was wrong, so the form points at it
          // rather than showing a toast the seller has to map back themselves.
          errorText: error,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
        ),
      );

  Widget _dropdown(
    BuildContext context, {
    required String label,
    required String? value,
    required List<String> options,
    required String prefix,
    required ValueChanged<String?> onChanged,
    String? error,
  }) =>
      DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: getTranslated(label, context) ?? label,
          errorText: error,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
        ),
        items: options
            .map((option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(getTranslated('$prefix$option', context) ?? option,
                      overflow: TextOverflow.ellipsis,
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                ))
            .toList(),
        onChanged: onChanged,
      );

  Future<void> _save(BuildContext context, AutomationController automation) async {
    final Map<String, Map<String, dynamic>> bags = <String, Map<String, dynamic>>{
      'trigger_settings': <String, dynamic>{},
      'action_settings': <String, dynamic>{},
      'scope': <String, dynamic>{},
    };

    _settings.forEach((key, controller) {
      final String text = controller.text.trim();
      if (text.isEmpty) return;

      final int split = key.indexOf('.');
      final String bag = key.substring(0, split);
      final String field = key.substring(split + 1);
      if (!bags.containsKey(bag)) return;

      // The scope's three fields are id lists whatever they are typed as. Sent
      // as lists so the server cleans and bounds them rather than parsing prose.
      bags[bag]![field] = bag == 'scope' ? _ids(text) : text;
    });

    final bool ok = await automation.saveRule({
      'name': _name.text.trim(),
      'trigger': _trigger,
      'action': _action,
      'trigger_settings': bags['trigger_settings'],
      'action_settings': bags['action_settings'],
      'scope': bags['scope'],
      'max_actions_per_run': int.tryParse(_cap.text.trim()) ?? 50,
      'cooldown_minutes': int.tryParse(_cooldown.text.trim()) ?? 15,
    }, id: widget.rule?.id);

    if (ok && context.mounted) Navigator.of(context).pop();
  }

  List<int> _ids(String text) => text
      .split(RegExp(r'[,\s]+'))
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .where((id) => id > 0)
      .toList();

  Future<void> _confirmDelete(BuildContext context, AutomationController automation) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(getTranslated('delete_rule', context) ?? ''),
        // Says what deleting does and does not do: the record of what the rule
        // already did to the shop stays, because deleting the rule does not
        // un-happen it.
        content: Text(getTranslated('delete_rule_keeps_its_history', context) ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(getTranslated('cancel', context) ?? ''),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(getTranslated('delete', context) ?? '',
                style: robotoMedium.copyWith(color: Colors.red.shade600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final bool ok = await automation.deleteRule(widget.rule!.id);
    if (ok && context.mounted) Navigator.of(context).pop();
  }
}
