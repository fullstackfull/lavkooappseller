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

/// What is left on the shelf, lowest first.
///
/// Not a period report — a stock level is a fact about now, so there are no
/// date chips here.
class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<ReportController>(context, listen: false).getStockReport();
  }

  /// The file must match the list on screen, so the export carries the same
  /// sort and category the report was fetched with.
  Map<String, dynamic> _exportQuery(BuildContext context) {
    final ReportController reports = Provider.of<ReportController>(context, listen: false);
    return {
      'sort': reports.stockSort,
      if (reports.stockCategoryId != null) 'category_id': reports.stockCategoryId,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: getTranslated('stock_report', context),
        isAction: true,
        isTooltip: true,
        widget: ReportExportButtonWidget(options: [
          ReportExportOption(
            uri: AppConstants.stockReportExportUri,
            fileName: 'product-stock-report.xlsx',
            label: 'download_excel',
            icon: Icons.table_chart_outlined,
            queryParameters: _exportQuery(context),
          ),
        ]),
      ),
      body: Consumer<ReportController>(
        builder: (context, reports, _) {
          final StockReportModel? report = reports.stockReport;

          return RefreshIndicator(
            onRefresh: () => reports.getStockReport(),
            color: Theme.of(context).cardColor,
            backgroundColor: Theme.of(context).primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                if (report == null)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * .6,
                    child: Center(child: reports.isLoading
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))
                        : const NoDataScreen()),
                  )
                else ...[
                  Row(children: [
                    ReportMetricWidget(title: 'products', value: '${report.totalSize}'),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    ReportMetricWidget(
                      title: 'running_low',
                      value: '${report.lowStockCount}',
                      valueColor: report.lowStockCount > 0 ? Theme.of(context).colorScheme.error : null,
                    ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  ReportCardWidget(children: [
                    ReportRowWidget(label: 'low_stock_threshold', value: '${report.stockLimit}'),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  Row(children: [
                    Expanded(
                      child: _SortToggleWidget(
                        sort: reports.stockSort,
                        onChanged: (sort) => reports.getStockReport(sort: sort),
                      ),
                    ),
                  ]),

                  if (report.categories.isNotEmpty) ...[
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    _CategoryFilterWidget(
                      categories: report.categories,
                      selected: reports.stockCategoryId,
                      onChanged: (id) => id == null
                          ? reports.getStockReport(clearCategory: true)
                          : reports.getStockReport(categoryId: id),
                    ),
                  ],

                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  if (report.products.isEmpty)
                    const NoDataScreen()
                  else
                    ...report.products.map((product) => Padding(
                      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                      child: _StockRowWidget(product: product),
                    )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SortToggleWidget extends StatelessWidget {
  final String sort;
  final ValueChanged<String> onChanged;
  const _SortToggleWidget({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final String option in const ['asc', 'desc'])
        Padding(
          padding: const EdgeInsets.only(right: Dimensions.paddingSizeExtraSmall),
          child: InkWell(
            onTap: () => onChanged(option),
            borderRadius: BorderRadius.circular(Dimensions.radiusPill),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(
                color: sort == option
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(Dimensions.radiusPill),
              ),
              child: Text(getTranslated(option == 'asc' ? 'low_to_high' : 'high_to_low', context)!,
                  style: (sort == option ? robotoBold : robotoRegular).copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: sort == option ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                  )),
            ),
          ),
        ),
    ]);
  }
}

class _CategoryFilterWidget extends StatelessWidget {
  final List<StockCategoryModel> categories;
  final int? selected;
  final ValueChanged<int?> onChanged;
  const _CategoryFilterWidget({required this.categories, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // One extra leading chip clears the filter, so "all" is a choice rather
        // than something only reachable by deselecting.
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSizeExtraSmall),
        itemBuilder: (context, index) {
          final StockCategoryModel? category = index == 0 ? null : categories[index - 1];
          final bool isSelected = category == null ? selected == null : selected == category.id;

          return InkWell(
            onTap: () => onChanged(category?.id),
            borderRadius: BorderRadius.circular(Dimensions.radiusPill),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(Dimensions.radiusPill),
              ),
              child: Text(category?.name ?? getTranslated('all', context) ?? 'all',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: (isSelected ? robotoBold : robotoRegular).copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                  )),
            ),
          );
        },
      ),
    );
  }
}

class _StockRowWidget extends StatelessWidget {
  final StockProductModel product;
  const _StockRowWidget({required this.product});

  @override
  Widget build(BuildContext context) {
    return ReportCardWidget(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Text(product.name ?? '#${product.id}',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        // The server decides what counts as low against this seller's own
        // threshold; the screen only reports its verdict.
        Text('${product.currentStock}',
            style: robotoBold.copyWith(
              fontSize: Dimensions.fontSizeLarge,
              color: product.isLowStock
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onTertiaryContainer,
            )),
      ]),
      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
      ReportRowWidget(label: 'price', value: PriceConverter.convertPrice(context, product.unitPrice)),
      if (product.isLowStock)
        Padding(
          padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
          child: Text(getTranslated('running_low', context)!,
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).colorScheme.error)),
        ),
    ]);
  }
}
