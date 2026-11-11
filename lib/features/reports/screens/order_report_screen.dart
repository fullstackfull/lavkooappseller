import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/reports/controllers/report_controller.dart';
import 'package:syriacosmeticsmanger/features/reports/domain/models/report_models.dart';
import 'package:syriacosmeticsmanger/features/reports/widgets/report_export_button_widget.dart';
import 'package:syriacosmeticsmanger/features/reports/widgets/report_widgets.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Orders over a period: how many, in what state, worth how much, and paid by
/// what means — the vendor panel's order report, on a phone.
class OrderReportScreen extends StatefulWidget {
  const OrderReportScreen({super.key});

  @override
  State<OrderReportScreen> createState() => _OrderReportScreenState();
}

class _OrderReportScreenState extends State<OrderReportScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<ReportController>(context, listen: false).getOrderReport();
  }

  Future<void> _pickRange(ReportController reports) async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: reports.customFrom != null && reports.customTo != null
          ? DateTimeRange(start: reports.customFrom!, end: reports.customTo!)
          : null,
    );

    if (range != null) {
      await reports.getOrderReport(dateType: 'custom_date', from: range.start, to: range.end);
    }
  }

  /// The file must cover the period on screen, so the export carries the same
  /// parameters the report was fetched with.
  Map<String, dynamic> _exportQuery(BuildContext context) {
    final ReportController reports = Provider.of<ReportController>(context, listen: false);
    return {
      'date_type': reports.orderPeriod,
      if (reports.orderPeriod == 'custom_date' && reports.customFrom != null)
        'from': _date(reports.customFrom!),
      if (reports.orderPeriod == 'custom_date' && reports.customTo != null)
        'to': _date(reports.customTo!),
    };
  }

  String _date(DateTime moment) => '${moment.year.toString().padLeft(4, '0')}-'
      '${moment.month.toString().padLeft(2, '0')}-${moment.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: getTranslated('order_report', context),
        isAction: true,
        isTooltip: true,
        // Reuses the app bar's existing trailing slot rather than growing its
        // action chain another branch.
        widget: ReportExportButtonWidget(options: [
          ReportExportOption(
            uri: AppConstants.orderReportExportUri,
            fileName: 'order-report.xlsx',
            label: 'download_excel',
            icon: Icons.table_chart_outlined,
            queryParameters: _exportQuery(context),
          ),
          ReportExportOption(
            uri: AppConstants.orderReportPdfUri,
            fileName: 'order-report.pdf',
            label: 'download_pdf',
            icon: Icons.picture_as_pdf_outlined,
            queryParameters: _exportQuery(context),
          ),
        ]),
      ),
      body: Consumer<ReportController>(
        builder: (context, reports, _) {
          final OrderReportModel? report = reports.orderReport;

          return RefreshIndicator(
            onRefresh: () => reports.getOrderReport(),
            color: Theme.of(context).cardColor,
            backgroundColor: Theme.of(context).primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                ReportPeriodPickerWidget(
                  period: report?.period ?? ReportPeriodModel(),
                  selected: reports.orderPeriod,
                  onChanged: (type) => reports.getOrderReport(dateType: type),
                  onPickRange: () => _pickRange(reports),
                ),
                if (report?.period.isCustom ?? false) ...[
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Text('${report!.period.from ?? ''}  —  ${report.period.to ?? ''}',
                      style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
                ],
                const SizedBox(height: Dimensions.paddingSizeSmall),

                if (report == null)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * .5,
                    child: Center(child: reports.isLoading
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))
                        : const NoDataScreen()),
                  )
                else ...[
                  Row(children: [
                    ReportMetricWidget(title: 'total_orders', value: '${report.total}'),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    ReportMetricWidget(
                      title: 'delivered',
                      value: '${report.delivered}',
                      valueColor: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Row(children: [
                    ReportMetricWidget(
                      title: 'ongoing',
                      value: '${report.ongoing}',
                      valueColor: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    ReportMetricWidget(
                      title: 'canceled',
                      value: '${report.canceled}',
                      valueColor: report.canceled > 0 ? Theme.of(context).colorScheme.error : null,
                    ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  ReportCardWidget(children: [
                    Text(getTranslated('order_amount', context)!,
                        style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    ReportRowWidget(
                      label: 'settled',
                      value: PriceConverter.convertPrice(context, report.settled),
                      valueColor: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    ReportRowWidget(
                      label: 'due',
                      value: PriceConverter.convertPrice(context, report.due),
                    ),
                    const Divider(height: Dimensions.paddingSizeDefault),
                    ReportRowWidget(
                      label: 'total',
                      value: PriceConverter.convertPrice(context, report.turnover),
                    ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  if (report.payments.hasAny) ...[
                    ReportCardWidget(children: [
                      Text(getTranslated('payments_received', context)!,
                          style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      ReportRowWidget(label: 'cash_payments',
                          value: PriceConverter.convertPrice(context, report.payments.cash)),
                      ReportRowWidget(label: 'digital_payments',
                          value: PriceConverter.convertPrice(context, report.payments.digital)),
                      ReportRowWidget(label: 'wallet',
                          value: PriceConverter.convertPrice(context, report.payments.wallet)),
                      ReportRowWidget(label: 'offline_payments',
                          value: PriceConverter.convertPrice(context, report.payments.offline)),
                      if (report.payments.returned > 0)
                        ReportRowWidget(
                          label: 'returned_amount',
                          value: '- ${PriceConverter.convertPrice(context, report.payments.returned)}',
                          valueColor: Theme.of(context).colorScheme.error,
                        ),
                      const Divider(height: Dimensions.paddingSizeDefault),
                      // The server has already folded in what an order edit
                      // added and taken back what it returned, so this is not
                      // the sum of the rows above and must not be recomputed.
                      ReportRowWidget(label: 'total_payment',
                          value: PriceConverter.convertPrice(context, report.payments.total)),
                    ]),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                  ],

                  ReportChartWidget(chart: report.chart, title: 'settled_over_time'),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  if (report.orders.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
                      child: Text('${getTranslated('orders', context)}  (${report.totalOrderCount})',
                          style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    ),
                    ...report.orders.map((order) => Padding(
                      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                      child: _OrderRowWidget(order: order),
                    )),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrderRowWidget extends StatelessWidget {
  final ReportOrderModel order;
  const _OrderRowWidget({required this.order});

  @override
  Widget build(BuildContext context) {
    return ReportCardWidget(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('#${order.id}',
            style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
        Text(getTranslated(order.orderStatus ?? '', context) ?? (order.orderStatus ?? ''),
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
      ]),
      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
      ReportRowWidget(label: 'amount', value: PriceConverter.convertPrice(context, order.orderAmount)),
      if (order.productDiscount > 0)
        ReportRowWidget(label: 'product_discount',
            value: PriceConverter.convertPrice(context, order.productDiscount)),
      if (order.couponDiscount > 0)
        ReportRowWidget(label: 'coupon_discount',
            value: PriceConverter.convertPrice(context, order.couponDiscount)),
      if (order.tax > 0)
        ReportRowWidget(label: 'tax', value: PriceConverter.convertPrice(context, order.tax)),
      if (order.commission > 0)
        ReportRowWidget(label: 'commission',
            value: PriceConverter.convertPrice(context, order.commission)),
    ]);
  }
}
