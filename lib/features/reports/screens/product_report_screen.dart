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
      await reports.getProductReport(dateType: 'custom_date', from: range.start, to: range.end);
    }
  }

  /// The file must cover the period on screen, so the export carries the same
  /// parameters the report was fetched with.
  Map<String, dynamic> _exportQuery(BuildContext context) {
    final ReportController reports = Provider.of<ReportController>(context, listen: false);
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
                    child: Center(child: reports.isLoading
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))
                        : const NoDataScreen()),
                  )
                else ...[
                  Row(children: [
                    ReportMetricWidget(title: 'total_products', value: '${report.listedTotal}'),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    ReportMetricWidget(
                      title: 'active',
                      value: '${report.active}',
                      valueColor: Theme.of(context).colorScheme.onTertiaryContainer,
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
                      valueColor: report.rejected > 0 ? Theme.of(context).colorScheme.error : null,
                    ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  ReportCardWidget(children: [
                    Text(getTranslated('sales', context)!,
                        style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    ReportRowWidget(label: 'quantity_sold',
                        value: report.soldQuantity.toStringAsFixed(0)),
                    ReportRowWidget(label: 'sales_value',
                        value: PriceConverter.convertPrice(context, report.soldAmount)),
                    ReportRowWidget(label: 'discount_given',
                        value: PriceConverter.convertPrice(context, report.discountGiven)),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  ReportChartWidget(chart: report.chart, title: 'products_listed_over_time'),

                  if (report.topProducts.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
                      child: Text(getTranslated('best_selling_products', context)!,
                          style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    ),
                    ...report.topProducts.map((product) => Padding(
                      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                      child: ReportCardWidget(children: [
                        Text(product.name ?? '#${product.productId}',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: robotoMedium.copyWith(
                                color: Theme.of(context).textTheme.bodyLarge?.color)),
                        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                        ReportRowWidget(label: 'quantity_sold',
                            value: product.totalQuantity.toStringAsFixed(0)),
                        ReportRowWidget(label: 'sales_value',
                            value: PriceConverter.convertPrice(context, product.totalAmount)),
                      ]),
                    )),
                  ],

                  if (report.products.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
                      child: Text('${getTranslated('products', context)}  (${report.totalProductCount})',
                          style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    ),
                    ...report.products.map((product) => Padding(
                      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                      child: ReportCardWidget(children: [
                        Text(product.name ?? '#${product.id}',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: robotoMedium.copyWith(
                                color: Theme.of(context).textTheme.bodyLarge?.color)),
                        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                        ReportRowWidget(label: 'price',
                            value: PriceConverter.convertPrice(context, product.unitPrice)),
                        ReportRowWidget(label: 'current_stock', value: '${product.currentStock}'),
                        if (product.soldQuantity > 0)
                          ReportRowWidget(label: 'quantity_sold',
                              value: product.soldQuantity.toStringAsFixed(0)),
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
}
