import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/finance_control/controllers/finance_control_controller.dart';
import 'package:syriacosmeticsmanger/features/finance_control/domain/models/finance_control_models.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Three questions a seller could not previously ask about their own money.
///
/// Does what I sold add up to what I was paid; what would this sale cost me;
/// who changed this price. Kept together because they are the same subject and
/// a seller checking one usually wants another, and kept in tabs because they
/// are asked one at a time.
class FinanceControlScreen extends StatefulWidget {
  const FinanceControlScreen({super.key});

  @override
  State<FinanceControlScreen> createState() => _FinanceControlScreenState();
}

class _FinanceControlScreenState extends State<FinanceControlScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  final TextEditingController _price = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  final TextEditingController _discount = TextEditingController();

  final TextEditingController _minMargin = TextEditingController();
  final TextEditingController _minPrice = TextEditingController();

  /// Filled from the server the first time the policy arrives, and never again:
  /// re-filling on every rebuild would fight the seller while they type.
  bool _floorFieldsSeeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Provider.of<FinanceControlController>(context, listen: false).load(),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _price.dispose();
    _quantity.dispose();
    _discount.dispose();
    _minMargin.dispose();
    _minPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('money_and_pricing', context)),
      body: Column(children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Theme.of(context).hintColor,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(text: getTranslated('does_it_add_up', context)),
            Tab(text: getTranslated('fee_simulator', context)),
            Tab(text: getTranslated('price_history', context)),
            Tab(text: getTranslated('price_floor', context)),
          ],
        ),
        Expanded(
          child: Consumer<FinanceControlController>(
            builder: (context, finance, _) => TabBarView(controller: _tabs, children: [
              _reconciliation(context, finance),
              _simulator(context, finance),
              _priceHistory(context, finance),
              _priceFloor(context, finance),
            ]),
          ),
        ),
      ]),
    );
  }

  /// The floor under the seller's own prices.
  ///
  /// Two honest states the screen refuses to smooth over: a floor switched on
  /// with nothing in it refuses nothing, and a margin floor over a catalogue
  /// with no recorded costs can speak about none of it. Both look like working
  /// protection from the toggle alone, which is exactly why they are said out
  /// loud.
  Widget _priceFloor(BuildContext context, FinanceControlController finance) {
    if (finance.isLoading && finance.pricingPolicy == null) {
      return _spinner(context);
    }

    final PricingPolicyModel? policy = finance.pricingPolicy;

    if (policy == null) {
      return _message(context, 'nothing_to_reconcile_yet');
    }

    if (!_floorFieldsSeeded) {
      _minMargin.text = policy.minMarginPercent?.toString() ?? '';
      _minPrice.text = policy.minPrice?.toString() ?? '';
      _floorFieldsSeeded = true;
    }

    return ListView(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      children: [
        Text(
          getTranslated('a_price_below_this_is_refused_before_it_is_saved', context) ?? '',
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        TextField(
          controller: _minMargin,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: getTranslated('minimum_margin_over_cost_percent', context),
            helperText: getTranslated('only_applies_to_products_with_a_recorded_cost', context),
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        TextField(
          controller: _minPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: getTranslated('never_sell_below_this_price', context)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: policy.enforce,
          title: Text(
            getTranslated('enforce_this_floor', context) ?? '',
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
          ),
          subtitle: Text(
            getTranslated('applies_to_your_own_edits_bulk_changes_and_rules', context) ?? '',
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
          ),
          onChanged: (on) => finance.savePricingPolicy(
            minMarginPercent: double.tryParse(_minMargin.text),
            minPrice: double.tryParse(_minPrice.text),
            enforce: on,
          ),
        ),
        if (policy.onButEmpty)
          _floorWarning(context, 'this_floor_is_on_but_has_nothing_in_it'),
        if (policy.marginCoversNothing)
          _floorWarning(context, 'none_of_your_products_have_a_recorded_cost'),
        Padding(
          padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
          child: Text(
            '${policy.productsWithACost} / ${policy.productsTotal} '
            '${getTranslated('products_have_a_recorded_cost', context) ?? ''}',
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeExtraSmall,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: finance.isSavingPolicy
                ? null
                : () => finance.savePricingPolicy(
                      minMarginPercent: double.tryParse(_minMargin.text),
                      minPrice: double.tryParse(_minPrice.text),
                      enforce: policy.enforce,
                    ),
            child: Text(
              getTranslated(finance.isSavingPolicy ? 'saving' : 'save', context) ?? '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _floorWarning(BuildContext context, String key) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimensions.paddingSizeExtraSmall),
      ),
      child: Text(
        getTranslated(key, context) ?? '',
        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.orange),
      ),
    );
  }

  Widget _reconciliation(BuildContext context, FinanceControlController finance) {
    if (finance.isLoading && finance.reconciliation == null) {
      return _spinner(context);
    }

    final ReconciliationModel? report = finance.reconciliation;
    if (report == null) {
      return _message(context, 'nothing_to_reconcile_yet');
    }

    return RefreshIndicator(
      onRefresh: () => finance.load(),
      color: Theme.of(context).cardColor,
      backgroundColor: Theme.of(context).primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        children: [
          Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              color: (report.reconciles ? Colors.green.shade600 : Colors.orange.shade700)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
            child: Row(children: [
              Icon(report.reconciles ? Icons.verified_outlined : Icons.warning_amber_outlined,
                  color: report.reconciles ? Colors.green.shade600 : Colors.orange.shade700),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: Text(
                  getTranslated(
                          report.reconciles ? 'everything_adds_up' : 'something_does_not_add_up',
                          context) ??
                      '',
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
                ),
              ),
            ]),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text('${report.from} — ${report.to}',
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),

          const SizedBox(height: Dimensions.paddingSizeLarge),
          // The chain, in the order it happens. Reading it top to bottom is how
          // a seller sees which hand-off dropped their money.
          _stage(context, 'you_delivered', '${report.delivered.lines}',
              PriceConverter.convertPrice(context, report.delivered.gross)),
          _stage(
            context,
            'marketplace_recorded',
            '${report.recorded.lines}',
            report.recorded.isRecorded
                ? PriceConverter.convertPrice(context, report.recorded.net)
                : getTranslated('not_recorded_yet', context) ?? '',
          ),
          _stage(context, 'paid_into_your_balance', '${report.credited.entries}',
              PriceConverter.convertPrice(context, report.credited.amount)),

          if (report.linesWithoutEarning.count > 0) ...[
            const SizedBox(height: Dimensions.paddingSizeLarge),
            _gap(context, 'delivered_but_not_recorded', report.linesWithoutEarning,
                'order'),
          ],
          if (report.earningsWithoutCredit.count > 0) ...[
            const SizedBox(height: Dimensions.paddingSizeLarge),
            _gap(context, 'recorded_but_not_paid_in', report.earningsWithoutCredit, 'order_id'),
          ],
        ],
      ),
    );
  }

  Widget _stage(BuildContext context, String label, String count, String amount) => Padding(
        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
        child: Row(children: [
          Expanded(
            child: Text(getTranslated(label, context) ?? label,
                style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
          ),
          Text(count,
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Text(amount, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
        ]),
      );

  Widget _gap(BuildContext context, String label, ReconciliationGap gap, String idKey) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(getTranslated(label, context) ?? label,
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
            ),
            Text(PriceConverter.convertPrice(context, gap.amount),
                style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall, color: Colors.orange.shade700)),
          ]),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text('${gap.count}',
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          // The sample is what makes the number checkable rather than
          // believable: every row names an order the seller can go and look at.
          ...gap.sample.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
                child: Row(children: [
                  Expanded(
                    child: Text('#${row['order_id'] ?? row[idKey] ?? ''}',
                        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                  ),
                  if (row['amount'] != null)
                    Text(
                        PriceConverter.convertPrice(
                            context, double.tryParse('${row['amount']}') ?? 0),
                        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
                ]),
              )),
        ],
      );

  Widget _simulator(BuildContext context, FinanceControlController finance) {
    return ListView(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      children: [
        Text(getTranslated('fee_simulator_explained', context) ?? '',
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        _numberField(context, _price, 'price_you_are_considering'),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        _numberField(context, _quantity, 'quantity'),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        _numberField(context, _discount, 'your_discount_optional'),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: finance.isSimulating ? null : () => _runSimulation(finance),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: Text(getTranslated('work_it_out', context) ?? '',
                style: robotoMedium.copyWith(color: Colors.white)),
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeLarge),
        if (finance.isSimulating)
          _spinner(context)
        else if (finance.simulation != null)
          _simulationResult(context, finance.simulation!),
      ],
    );
  }

  Widget _simulationResult(BuildContext context, FeeSimulationModel result) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stage(context, 'customer_pays', '${result.quantity}',
              PriceConverter.convertPrice(context, result.gross)),
          if (result.discountPerUnit > 0)
            _stage(context, 'your_discount', '',
                '- ${PriceConverter.convertPrice(context, result.discountPerUnit * result.quantity)}'),
          _stage(context, 'marketplace_commission', '',
              '- ${PriceConverter.convertPrice(context, result.commissionAmount)}'),
          const Divider(),
          _stage(context, 'you_receive', '',
              PriceConverter.convertPrice(context, result.sellerReceives)),

          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            result.effectiveRatePercent == null
                // A percentage of nothing is undefined, not nought per cent.
                ? (getTranslated('no_rate_to_show_on_a_free_line', context) ?? '')
                : '${getTranslated('effective_rate', context) ?? ''}: ${result.effectiveRatePercent}%'
                    '${result.ruleLabel == null ? '' : ' · ${result.ruleLabel}'}',
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
          ),

          const SizedBox(height: Dimensions.paddingSizeSmall),
          // Named rather than estimated. A plausible number a seller prices
          // against is worse than an honest gap.
          Text(
            '${getTranslated('not_included', context) ?? ''}: '
            '${result.excludes.map((key) => getTranslated('excludes_$key', context) ?? key).join(', ')}',
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
          ),
        ],
      );

  Widget _priceHistory(BuildContext context, FinanceControlController finance) {
    if (finance.isLoading && finance.priceChanges.isEmpty) {
      return _spinner(context);
    }

    if (finance.priceChanges.isEmpty) {
      return _message(context, 'no_price_changes_recorded_yet');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      itemCount: finance.priceChanges.length,
      itemBuilder: (context, index) {
        final PriceChangeModel change = finance.priceChanges[index];
        final bool up = change.delta > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          ),
          child: Row(children: [
            Icon(
              change.isFirstPrice
                  ? Icons.flag_outlined
                  : (up ? Icons.trending_up : Icons.trending_down),
              size: 18,
              color: change.isFirstPrice
                  ? Theme.of(context).hintColor
                  : (up ? Colors.green.shade600 : Colors.orange.shade700),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  change.isFirstPrice
                      // Not a change from nothing: the first price a product was
                      // ever given is a different fact.
                      ? '${getTranslated('first_price', context) ?? ''} · ${PriceConverter.convertPrice(context, change.newPrice)}'
                      : '${PriceConverter.convertPrice(context, change.previousPrice ?? 0)} → ${PriceConverter.convertPrice(context, change.newPrice)}',
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
                ),
                Text(
                  '${getTranslated('price_source_${change.source}', context) ?? change.source}'
                  '${change.reason == null || change.reason!.isEmpty ? '' : ' · ${change.reason}'}'
                  '${change.actorName == null ? '' : ' · ${change.actorName}'}',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                ),
              ]),
            ),
            if (change.createdAt != null)
              Text(DateConverter.isoStringToLocalDateOnly(change.createdAt!),
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
          ]),
        );
      },
    );
  }

  Widget _numberField(BuildContext context, TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
        decoration: InputDecoration(
          labelText: getTranslated(label, context) ?? label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
        ),
      );

  Widget _spinner(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
        ),
      );

  Widget _message(BuildContext context, String key) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
          child: Text(getTranslated(key, context) ?? '',
              textAlign: TextAlign.center,
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
        ),
      );

  void _runSimulation(FinanceControlController finance) {
    finance.simulate({
      'unit_price': _price.text.trim(),
      'quantity': _quantity.text.trim().isEmpty ? '1' : _quantity.text.trim(),
      if (_discount.text.trim().isNotEmpty) 'discount': _discount.text.trim(),
      if (_discount.text.trim().isNotEmpty) 'discount_type': 'flat',
    });
  }
}
