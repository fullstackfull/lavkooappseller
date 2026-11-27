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

/// Products over a period: what is listed, what sold, and what earned the most.
class ProductReportScreen extends StatefulWidget {
  const ProductReportScreen({super.key});

  @override
  State<ProductReportScreen> createState() => _ProductReportScreenState();
}

class _ProductReportScreenState extends State<ProductReportScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<ReportController>(context, listen: false).getProductReport();
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
      await reports.getProductReport(
          dateType: 'custom_date', from: range.start, to: range.end);
    }
  }

  /// The file must cover the period on screen, so the export carries the same
  /// parameters the report was fetched with.
  Map<String, dynamic> _exportQuery(BuildContext context) {
    final ReportController reports =
        Provider.of<ReportController>(context, listen: false);
    return {
      'date_type': reports.productPeriod,
      if (reports.productPeriod == 'custom_date' && reports.customFrom != null)
        'from': _date(reports.customFrom!),
      if (reports.productPeriod == 'custom_date' && reports.customTo != null)
        'to': _date(reports.customTo!),
    };
  }

  String _date(DateTime moment) => '${moment.year.toString().padLeft(4, '0')}-'
      '${moment.month.toString().padLeft(2, '0')}-${moment.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: getTranslated('product_report', context),
        isAction: true,
        isTooltip: true,
        widget: ReportExportButtonWidget(options: [
          ReportExportOption(
            uri: AppConstants.productReportExportUri,
            fileName: 'product-report.xlsx',
            label: 'download_excel',
            icon: Icons.table_chart_outlined,
            queryParameters: _exportQuery(context),
          ),
        ]),
      ),
      body: Consumer<ReportController>(
        builder: (context, reports, _) {
          final ProductReportModel? report = reports.productReport;

          return RefreshIndicator(
            onRefresh: () => reports.getProductReport(),
            color: Theme.of(context).cardColor,
            backgroundColor: Theme.of(context).primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                ReportPeriodPickerWidget(
                  period: report?.period ?? ReportPeriodModel(),
                  selected: reports.productPeriod,
                  onChanged: (type) => reports.getProductReport(dateType: type),
                  onPickRange: () => _pickRange(reports),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                if (report == null)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * .5,
                    child: Center(
                        child: reports.isLoading
                            ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).primaryColor))
                            : const NoDataScreen()),
                  )
                else ...[
                  Row(children: [
                    ReportMetricWidget(
                        title: 'total_products',
                        value: '${report.listedTotal}'),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    ReportMetricWidget(
                      title: 'active',
                      value: '${report.active}',
                      valueColor:
                          Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Row(children: [
                    ReportMetricWidget(
                      title: 'pending',
                      value: '${report.pending}',
                      valueColor: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    ReportMetricWidget(
                      title: 'rejected',
                      value: '${report.rejected}',
                      valueColor: report.rejected > 0
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  ReportCardWidget(children: [
                    Text(getTranslated('sales', context)!,
                        style: robotoMedium.copyWith(
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    // The quantity is never refused, whatever the period holds:
                    // a unit sold in Riyadh and a unit sold in Dubai are two
                    // units. Only the two money figures can go missing.
                    ReportRowWidget(
                        label: 'quantity_sold',
                        value: report.soldQuantity.toStringAsFixed(0)),
                    if (!report.totalsRefused) ...[
                      ReportRowWidget(
                          label: 'sales_value',
                          value: PriceConverter.convertPrice(
                              context, report.soldAmount ?? 0)),
                      ReportRowWidget(
                          label: 'discount_given',
                          value: PriceConverter.convertPrice(
                              context, report.discountGiven ?? 0)),
                    ],
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  // Two currencies in the period and there is no one sales
                  // value to show, so the reason goes where the figures would
                  // have been and each currency is listed under it, as the
                  // order report does for its amounts.
                  //
                  // These two rows used to hand `PriceConverter` the server's
                  // null directly, and that converter dereferences the figure
                  // it is given (`price!`): the screen a seller opens to read
                  // what their products earned threw instead of drawing, and
                  // the one fix nobody should make is the obvious one of
                  // reading the refusal as zero (K-04.2).
                  if (report.totalsRefused) ...[
                    ..._perCurrency(context, report),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                  ],

                  ReportChartWidget(
                      chart: report.chart, title: 'products_listed_over_time'),

                  if (report.topProducts.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: Dimensions.paddingSizeDefault),
                      child: Text(
                          getTranslated('best_selling_products', context)!,
                          style: robotoMedium.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color)),
                    ),
                    ...report.topProducts.map((product) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: Dimensions.paddingSizeSmall),
                          child: ReportCardWidget(children: [
                            Text(product.name ?? '#${product.productId}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: robotoMedium.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color)),
                            const SizedBox(
                                height: Dimensions.paddingSizeExtraSmall),
                            ReportRowWidget(
                                label: 'quantity_sold',
                                value:
                                    product.totalQuantity.toStringAsFixed(0)),
                            ReportRowWidget(
                                label: 'sales_value',
                                value: PriceConverter.convertPrice(
                                    context, product.totalAmount)),
                          ]),
                        )),
                  ],

                  if (report.products.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: Dimensions.paddingSizeSmall),
                      child: Text(
                          '${getTranslated('products', context)}  (${report.totalProductCount})',
                          style: robotoMedium.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color)),
                    ),
                    ...report.products.map((product) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: Dimensions.paddingSizeSmall),
                          child: ReportCardWidget(children: [
                            Text(product.name ?? '#${product.id}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: robotoMedium.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color)),
                            const SizedBox(
                                height: Dimensions.paddingSizeExtraSmall),
                            ReportRowWidget(
                                label: 'price',
                                value: PriceConverter.convertPrice(
                                    context, product.unitPrice)),
                            ReportRowWidget(
                                label: 'current_stock',
                                value: '${product.currentStock}'),
                            if (product.soldQuantity > 0)
                              ReportRowWidget(
                                  label: 'quantity_sold',
                                  value:
                                      product.soldQuantity.toStringAsFixed(0)),
                          ]),
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

  /// What the period sold, in each currency it was sold in.
  ///
  /// The reason first, in the seller's language, then one card per currency
  /// with that currency's own real figures -- the same shape the order report
  /// and the statement use. Deliberately not one number with a footnote: the
  /// figure is the thing a seller reads, and there isn't one.
  List<Widget> _perCurrency(BuildContext context, ProductReportModel report) {
    return [
      ReportCardWidget(children: [
        Row(children: [
          Icon(Icons.info_outline,
              size: 18, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Expanded(
            child: Text(
              getTranslated(report.totalsRefusedBecause!, context) ??
                  report.totalsRefusedBecause!,
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
            ),
          ),
        ]),
      ]),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      ...report.totalsByCurrency.map((group) => Padding(
            padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
            child: ReportCardWidget(children: [
              Text(group.currencyCode,
                  style:
                      robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall)),
              ReportRowWidget(
                  label: 'quantity_sold',
                  value: _count(group['sold_quantity'])),
              ReportRowWidget(
                  label: 'sales_value', value: _amount(group['sold_amount'])),
              ReportRowWidget(
                  label: 'discount_given',
                  value: _amount(group['discount_given'])),
            ]),
          )),
    ];
  }

  /// A figure in its own currency, never converted to the display currency: the
  /// point of the per-currency answer is that these are different kinds of
  /// money.
  String _amount(double? figure) =>
      figure == null ? '\u2014' : figure.toStringAsFixed(2);

  /// A count, which has no currency and so is written as it came.
  String _count(double? figure) =>
      figure == null ? '\u2014' : figure.toStringAsFixed(0);
}
