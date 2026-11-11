import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/order_details/screens/order_details_screen.dart';
import 'package:syriacosmeticsmanger/features/reports/widgets/report_widgets.dart';
import 'package:syriacosmeticsmanger/features/statement/controllers/statement_controller.dart';
import 'package:syriacosmeticsmanger/features/statement/domain/models/statement_models.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The account, line by line.
///
/// A seller has been shown four totals and never the entries behind them, so a
/// balance was something to believe or not. Here every line says what it was,
/// what the balance became, which order earned it, and which payout took it out.
///
/// The filter narrows the list. It deliberately does not touch the balances at
/// the top: what a seller can withdraw today does not change because they are
/// looking at last week.
class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<StatementController>(context, listen: false)
          .getStatement(clearEntryType: true, clearStatus: true, clearDates: true);
    });
  }

  Future<void> _export(StatementController statements) async {
    final String? path = await statements.exportStatement();
    if (!mounted) return;

    showCustomSnackBarWidget(
      path != null
          ? '${getTranslated('saved_to', context) ?? ''} $path'
          : getTranslated('download_failed', context),
      context,
      sanckBarType: path != null ? SnackBarType.success : SnackBarType.error,
    );
  }

  Future<void> _pickRange(StatementController statements) async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: statements.from != null && statements.to != null
          ? DateTimeRange(start: statements.from!, end: statements.to!)
          : null,
    );

    if (range == null) return;
    await statements.getStatement(from: range.start, to: range.end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: getTranslated('statement', context),
        isAction: true,
        isTooltip: true,
        widget: Consumer<StatementController>(
          builder: (context, statements, _) => IconButton(
            onPressed: statements.isExporting ? null : () => _export(statements),
            tooltip: getTranslated('download_csv', context),
            icon: statements.isExporting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
          ),
        ),
      ),
      body: Consumer<StatementController>(
        builder: (context, statements, _) {
          final StatementSummaryModel summary = statements.summary;
          final List<StatementEntryModel> entries = statements.entries;

          return RefreshIndicator(
            onRefresh: () => statements.getStatement(),
            color: Theme.of(context).cardColor,
            backgroundColor: Theme.of(context).primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                // The account, never the filter. Narrowing to last week must not
                // change what can be withdrawn today.
                Row(children: [
                  ReportMetricWidget(
                    title: 'withdrawable_balance',
                    value: PriceConverter.convertPrice(context, summary.withdrawable),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  ReportMetricWidget(
                    title: 'pending',
                    value: PriceConverter.convertPrice(context, summary.pending),
                  ),
                ]),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                ReportCardWidget(children: [
                  ReportRowWidget(label: 'available', value: PriceConverter.convertPrice(context, summary.available)),
                  ReportRowWidget(label: 'reserved', value: PriceConverter.convertPrice(context, summary.reserved)),
                  ReportRowWidget(label: 'paid', value: PriceConverter.convertPrice(context, summary.paid)),
                  ReportRowWidget(label: 'balance', value: PriceConverter.convertPrice(context, summary.balance)),
                ]),

                const SizedBox(height: Dimensions.paddingSizeDefault),
                _filters(context, statements),

                const SizedBox(height: Dimensions.paddingSizeSmall),
                // The range, which does follow the filter — and says so by
                // sitting under the filter rather than beside the balances.
                ReportCardWidget(children: [
                  ReportRowWidget(label: 'entries', value: '${summary.rangeEntries}'),
                  ReportRowWidget(
                      label: 'credited', value: PriceConverter.convertPrice(context, summary.rangeCredits),
                      valueColor: Colors.green.shade700),
                  ReportRowWidget(
                      label: 'debited', value: PriceConverter.convertPrice(context, summary.rangeDebits),
                      valueColor: Theme.of(context).colorScheme.error),
                  ReportRowWidget(label: 'net', value: PriceConverter.convertPrice(context, summary.rangeNet)),
                ]),

                const SizedBox(height: Dimensions.paddingSizeLarge),

                if (entries.isEmpty)
                  SizedBox(
                    height: 200,
                    child: Center(child: statements.isLoading
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))
                        : const NoDataScreen()),
                  )
                else
                  ...entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
                        child: _entry(context, entry),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filters(BuildContext context, StatementController statements) {
    final StatementModel? statement = statements.statement;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _chip(context, getTranslated('all', context) ?? '', statements.entryType == null,
                () => statements.getStatement(clearEntryType: true)),
            ...(statement?.entryTypes ?? const <String>[]).map((type) => _chip(
                  context,
                  getTranslated('ledger_$type', context) ?? type,
                  statements.entryType == type,
                  () => statements.getStatement(entryType: type),
                )),
          ],
        ),
      ),
      Row(children: [
        TextButton.icon(
          onPressed: () => _pickRange(statements),
          icon: const Icon(Icons.date_range, size: 18),
          label: Text(
            statements.from != null && statements.to != null
                ? '${DateConverter.isoStringToLocalDateOnly(statements.from!.toIso8601String())}'
                    ' — ${DateConverter.isoStringToLocalDateOnly(statements.to!.toIso8601String())}'
                : getTranslated('any_date', context) ?? '',
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
          ),
        ),
        if (statements.from != null)
          TextButton(
            onPressed: () => statements.getStatement(clearDates: true),
            child: Text(getTranslated('clear', context) ?? '',
                style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
          ),
      ]),
    ]);
  }

  Widget _chip(BuildContext context, String label, bool isSelected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: Dimensions.paddingSizeExtraSmall),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          labelStyle: robotoMedium.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).hintColor,
          ),
          onSelected: (_) => onTap(),
        ),
      );

  Widget _entry(BuildContext context, StatementEntryModel entry) {
    final Color amountColor =
        entry.isCredit ? Colors.green.shade700 : Theme.of(context).colorScheme.error;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        // Every line opens the thing that produced it, which is what makes the
        // balance checkable rather than merely visible.
        onTap: entry.orderId == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OrderDetailsScreen(orderId: entry.orderId),
                )),
        child: Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: .08)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(getTranslated('ledger_${entry.entryType}', context) ?? entry.entryType,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
              ),
              Text(
                entry.isCredit
                    ? PriceConverter.convertPrice(context, entry.credit)
                    : '- ${PriceConverter.convertPrice(context, entry.debit)}',
                style: robotoBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: amountColor),
              ),
            ]),
            Row(children: [
              Expanded(
                child: Text(
                  [
                    if (entry.orderId != null) '${getTranslated('order', context) ?? ''} #${entry.orderId}',
                    if (entry.payoutReference != null) entry.payoutReference!,
                    if (entry.settlementReference != null) entry.settlementReference!,
                    if (entry.description != null && entry.description!.isNotEmpty) entry.description!,
                  ].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                ),
              ),
              // What the balance became — read from the ledger, not added up here.
              Text('→ ${PriceConverter.convertPrice(context, entry.balanceAfter)}',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
            ]),
            Row(children: [
              if (entry.createdAt != null)
                Text(DateConverter.isoStringToLocalDateAndTime(entry.createdAt!),
                    style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
              const Spacer(),
              // Money still inside the return window, and when it comes out.
              if (entry.isPending && entry.availableAt != null)
                Text(
                  '${getTranslated('available_on', context) ?? ''} ${DateConverter.isoStringToLocalDateOnly(entry.availableAt!)}',
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}
