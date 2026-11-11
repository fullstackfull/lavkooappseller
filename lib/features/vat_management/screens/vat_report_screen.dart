import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/vat_management/domain/models/vat_report_model.dart';
import 'package:syriacosmeticsmanger/helper/report_export_helper.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_asset_image_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/paginated_list_view_widget.dart';
import 'package:syriacosmeticsmanger/features/vat_management/controllers/vat_controller.dart';
import 'package:syriacosmeticsmanger/features/vat_management/widgets/order_info_card_widget.dart';
import 'package:syriacosmeticsmanger/features/vat_management/widgets/order_list_card_shimmer_widget.dart';
import 'package:syriacosmeticsmanger/features/vat_management/widgets/order_list_card_widget.dart';
import 'package:syriacosmeticsmanger/features/vat_management/widgets/tax_info_card.dart';
import 'package:syriacosmeticsmanger/features/vat_management/widgets/vat_filter_bottomsheet.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';

class VatReportScreen extends StatefulWidget {
  const VatReportScreen({super.key});

  @override
  State<VatReportScreen> createState() => _VatReportScreenState();
}

class _VatReportScreenState extends State<VatReportScreen> {

  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    Provider.of<VatController>(context, listen: false).resetReviewData(isUpdate: false);
    Provider.of<VatController>(context, listen: false).getVatReportList(1);
  }


  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  Future<void> _exportVatReport(BuildContext context, VatController vatController) async {
    final List<OrderTransactions> rows =
        vatController.vatReportModel?.orderTransactions ?? <OrderTransactions>[];
    if (rows.isEmpty) return;

    await ReportExportHelper.shareCsv(
      context: context,
      fileNamePrefix: 'vat_report',
      headers: <String>[
        getTranslated('order_id', context) ?? 'Order ID',
        getTranslated('date', context) ?? 'Date',
        getTranslated('order_amount', context) ?? 'Order amount',
        getTranslated('tax', context) ?? 'Tax',
        getTranslated('payment_method', context) ?? 'Payment method',
        getTranslated('status', context) ?? 'Status',
      ],
      rows: rows.map((OrderTransactions t) => <Object?>[
        t.orderId,
        t.createdAt,
        t.orderAmount,
        t.tax,
        t.paymentMethod,
        t.status,
      ]).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Consumer<VatController>(
        builder: (context, vatController, _) {
          final bool hasRows =
              (vatController.vatReportModel?.orderTransactions?.isNotEmpty ?? false);
          if (!hasRows) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _exportVatReport(context, vatController),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(getTranslated('export_csv', context) ?? ''),
          );
        },
      ),
      appBar: CustomAppBarWidget(title: getTranslated('vat_report', context),
         isAction: true, isFilter: true,
         widget: Consumer<VatController>(
           builder: (context, vatController, child) {
             return (vatController.vatReportModel?.typeWiseTaxesList != null &&  vatController.vatReportModel!.typeWiseTaxesList!.isNotEmpty || (vatController.vatReportModel?.typeWiseTaxesList != null &&  vatController.vatReportModel!.typeWiseTaxesList!.isEmpty && (vatController.isFilterActive ?? false))) ? InkWell(
              onTap: () {
                showModalBottomSheet(
                  backgroundColor: Theme.of(context).cardColor,
                  useSafeArea: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  isScrollControlled: true,
                  context: context,
                  builder: (BuildContext context) {
                    return const VatFilterBottomSheet();
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.onTertiaryContainer),
                  borderRadius: BorderRadius.circular(Dimensions.paddingSizeExtraSmall),
                ),
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                child: CustomAssetImageWidget(
                  Images.dropdown,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  height: Dimensions.paddingSizeDefault,
                  width: Dimensions.paddingSizeDefault,
                ),
              ),
             ) : const SizedBox();
           }
         )
      ),
      body: SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeMedium, vertical: Dimensions.paddingSizeLarge),

          child: Consumer<VatController>(
            builder: (context, vatController, child) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start,children: [

                vatController.vatReportModel != null   ?
                vatController.vatReportModel!.typeWiseTaxesList!.isNotEmpty ?
                Column(
                  children: [
                    Row(children: [
                      Expanded(
                        child: OrderInfoCardWidget(
                          image: Images.totalOrderIcon,
                          amount: vatController.vatReportModel?.totalOrders.toString(),
                          infoName: getTranslated('total_orders', context)!,
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),

                      Expanded(
                        child: OrderInfoCardWidget(
                          image: Images.totalAmountIcon,
                          amount: PriceConverter.convertPrice(context,  double.tryParse(vatController.vatReportModel?.totalOrderAmount.toString() ?? '') ?? 0,),
                          infoName: getTranslated('total_order_amount', context)!,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ]).animateSectionEntrance(index: 0),
                    const SizedBox(height: Dimensions.paddingSizeSmall),

                    Container(
                      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall).copyWith(right: 0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(Dimensions.paddingSizeExtraSmall),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min,crossAxisAlignment: CrossAxisAlignment.start,children: [

                        Row(mainAxisAlignment: MainAxisAlignment.start,children: [
                          CustomAssetImageWidget(
                            Images.vatReportIcon,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            height: Dimensions.topSpace,
                            width: Dimensions.topSpace,
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),

                          Column(crossAxisAlignment: CrossAxisAlignment.start,children: [

                            Text(PriceConverter.convertPrice(context,  double.tryParse(vatController.vatReportModel?.totalTax.toString() ?? '') ?? 0 ), style: robotoBold.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: Dimensions.fontSizeLarge,
                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                            )),

                            Text(getTranslated('total_vat_amount', context)!, style: robotoMedium.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                            )),
                          ]),
                        ]),
                        const SizedBox(height: Dimensions.paddingSizeLarge),

                        /// ToDo:
                        if(vatController.vatReportModel?.typeWiseTaxesList != null)
                        Container(
                          height: 66,
                          padding: const EdgeInsetsDirectional.only(end: Dimensions.paddingSizeSmall),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: (vatController.vatReportModel?.typeWiseTaxesList?.length) ?? 0,
                            itemBuilder: (context, index) {
                              return TaxInfoCard(taxModel: vatController.vatReportModel!.typeWiseTaxesList![index]).animateListEntrance(index);
                            },
                            separatorBuilder: (context, index) => const SizedBox(width: Dimensions.paddingEye),
                          ),
                        ),
                      ]),
                    ).animateSectionEntrance(index: 1),
                  ],
                ) : (vatController.vatReportModel?.orderTransactions?.isEmpty ?? false) ?
                SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  width: MediaQuery.of(context).size.width,
                  child: const Center(
                    child: NoDataScreen(
                      title: 'no_tax_report_found',
                    ),
                  ),
                ) : const SizedBox()
                : const VatReportShimmerWidget(isEnabled: true),
                

                if(vatController.vatReportModel?.orderTransactions?.isNotEmpty ?? false) ...[
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  Text(getTranslated('order_list', context)!, style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  )),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                ],

              vatController.vatReportModel != null ? (vatController.vatReportModel?.orderTransactions?.isNotEmpty ?? false) ?
                PaginatedListViewWidget(
                  scrollController: scrollController,
                  totalSize: vatController.vatReportModel?.totalOrders,
                  offset: vatController.vatReportModel?.offset,
                  onPaginate: (int? offset) async {
                    await vatController.getVatReportList(
                      offset ?? 1,
                      startDate: (vatController.isFilterActive ?? false) ? vatController.startDate.toString() : null,
                      endDate: (vatController.isFilterActive ?? false) ? vatController.endDate.toString() : null
                    );
                  },
                  itemView: ListView.separated(
                    itemCount:vatController.vatReportModel?.orderTransactions?.length ?? 0,
                    padding: const EdgeInsets.all(0),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemBuilder: (BuildContext context, int index) {
                      return OrderListCardWidget(orderModel:  vatController.vatReportModel?.orderTransactions?[index]).animateListEntrance(index);
                    },
                    separatorBuilder: (BuildContext context, int index) => const SizedBox(height: Dimensions.paddingSizeSmall),
                  ),
                ) : const SizedBox() : const OrderListCardShimmer(),

              ]);
            }
          ),
        ),
      ),
    );
  }
}



class VatReportShimmerWidget extends StatelessWidget {
  final bool isEnabled;
  const VatReportShimmerWidget({super.key, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeExtraSmall,
        horizontal: Dimensions.paddingSizeSmall,
      ),
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).highlightColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.grey[200]!, blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: ShimmerColors.base(context),
        highlightColor: ShimmerColors.highlight(context),
        enabled: isEnabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// === Top two stat cards row ===
            Row(children: [
              Expanded(child: _buildCardSkeleton(context)),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(child: _buildCardSkeleton(context)),
            ]),
            const SizedBox(height: Dimensions.paddingSizeSmall),

            /// === VAT summary container ===
            Container(
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall).copyWith(right: 0),
              decoration: BoxDecoration(
                color: Theme.of(context).highlightColor,
                borderRadius: BorderRadius.circular(Dimensions.paddingSizeExtraSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      height: Dimensions.topSpace,
                      width: Dimensions.topSpace,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 80, height: 14, color: Colors.grey[400]),
                        const SizedBox(height: 6),
                        Container(width: 100, height: 12, color: Colors.grey[400]),
                      ],
                    )
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeLarge),

                  /// Horizontal tax list placeholders
                  SizedBox(
                    height: Dimensions.topSpace,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingEye),
                      itemBuilder: (context, index) => Container(
                        width: Dimensions.topSpace * 2,
                        height: Dimensions.topSpace,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
          ],
        ),
      ),
    );
  }

  /// mini skeleton for each stat card
  Widget _buildCardSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).highlightColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 40, width: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Container(height: 14, width: 60, color: Colors.grey[400]),
          const SizedBox(height: 6),
          Container(height: 12, width: 100, color: Colors.grey[400]),
        ],
      ),
    );
  }
}



