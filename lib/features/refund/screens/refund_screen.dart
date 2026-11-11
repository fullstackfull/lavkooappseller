import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_asset_image_widget.dart';
import 'package:syriacosmeticsmanger/features/dashboard/screens/dashboard_screen.dart';
import 'package:syriacosmeticsmanger/features/refund/domain/models/refund_model.dart';
import 'package:syriacosmeticsmanger/features/vat_management/controllers/vat_controller.dart';
import 'package:syriacosmeticsmanger/features/vat_management/widgets/vat_filter_bottomsheet.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/refund/controllers/refund_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/refund/widgets/refund_widget.dart';
import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';

class RefundScreen extends StatefulWidget {
  final bool isBacButtonExist;
  final bool fromNotification;
  const RefundScreen({super.key, this.isBacButtonExist = false, required this.fromNotification});

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  String result  = 'all_time';


  @override
  void initState() {
    Provider.of<VatController>(context, listen: false).resetReviewData(isUpdate: false);
    Provider.of<RefundController>(context, listen: false).setFilterActive(false, isUpdate: false);

    super.initState();
  }

  /*
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      Provider.of<RefundController>(context, listen:false)
          .setDummyRefundData();

    });
  }
*/
  @override
  Widget build(BuildContext context) {
   Provider.of<RefundController>(context, listen: false).getRefundList(context);

    return PopScope(
      canPop: !widget.fromNotification,
      onPopInvokedWithResult: (didPop, _) async {
        if(!didPop && widget.fromNotification) {
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (BuildContext context) => const DashboardScreen()), (route) => false);
        }
        return;
      },
      child: Scaffold(
        body: Consumer<RefundController>(builder: (context, refund, child) {
          List<RefundModel>? refundList = [];

          if(refund.refundTypeIndex == 0) {
            refundList = refund.refundList;
          }else if (refund.refundTypeIndex == 1) {
            refundList = refund.pendingList;
          }else if (refund.refundTypeIndex == 2) {
            refundList = refund.approvedList;
          }else if (refund.refundTypeIndex == 3) {
            refundList = refund.deniedList;
          }else if (refund.refundTypeIndex == 4) {
            refundList = refund.doneList;
          }
          return Column(children: [
            CustomAppBarWidget(
              title: getTranslated('refund', context), isBackButtonExist: widget.isBacButtonExist,
              onBackPressed: () {
                if(widget.fromNotification) {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (BuildContext context) => const DashboardScreen()));
                } else {
                  Navigator.of(context).pop();
                }
              },

              isAction: true, isFilter: true,
              widget: Consumer<RefundController>(
                builder: (context, refundController, _) {
                  return Stack(
                    children: [
                      if(result != 'all_time' && (refundController.isFilterActive ?? false))
                      Positioned(
                        top: 1, right: 0,
                        child: Container(
                          height: 7, width: 7,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: Theme.of(context).colorScheme.error
                          ),
                        ),
                      ),

                      SizedBox(
                        height: 25, width: 25,
                        child: PopupMenuButton<String>(
                          offset: const Offset(0, 40),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
                          icon: CustomAssetImageWidget(
                            Images.dropdown,
                            color: Theme.of(context).colorScheme.primary,
                            height: Dimensions.paddingSizeExtraLarge,
                            width: Dimensions.paddingSizeExtraLarge,
                          ),
                          onSelected: (String selected) async {
                            result = selected;

                            if (selected == 'all_time') {
                              refundController.getRefundList(context, type: 'all', isReload: true);
                            } else if (selected == 'today') {
                              refundController.setFilterActive(true);
                              refundController.getRefundList(context, type: 'today', isReload: true);
                            }  else if (selected == 'this_week') {
                              refundController.setFilterActive(true);
                              refundController.getRefundList(context, type: 'this_week', isReload: true);
                            } else if (selected == 'this_month') {
                              refundController.setFilterActive(true);
                              refundController.getRefundList(context, type: 'this_month', isReload: true);
                            } else if (selected == 'custom_date') {
                              refundController.setFilterActive(true);
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
                                  return const VatFilterBottomSheet(formRefund: true);
                                },
                              );
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'all_time',
                              height: 30,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const SizedBox(width: Dimensions.paddingSizeSmall),
                                  Text(getTranslated('all_time', context)!, style: robotoRegular.copyWith(
                                    color: result == 'all_time' ? Theme.of(context).textTheme.bodyLarge?.color :
                                    Theme.of(context).textTheme.headlineLarge?.color
                                  )),
                                  const SizedBox(width: Dimensions.paddingSizeExtraLarge),
                                ],
                              ),
                            ),

                            PopupMenuItem<String>(
                              height: 30,
                              value: 'today',
                              child: Row(
                                children: [
                                  const SizedBox(width: Dimensions.paddingSizeSmall),
                                  Text(getTranslated('today', context)!, style: robotoRegular.copyWith(color: result == 'today' ?
                                  Theme.of(context).textTheme.bodyLarge?.color :
                                  Theme.of(context).textTheme.headlineLarge?.color)),
                                ],
                              ),
                            ),

                            PopupMenuItem<String>(
                              height: 30,
                              value: 'this_week',
                              child: Row(
                                children: [
                                  const SizedBox(width: Dimensions.paddingSizeSmall),
                                  Text(getTranslated('this_week', context)!, style: robotoRegular.copyWith(
                                      color: result == 'this_week' ?
                                      Theme.of(context).textTheme.bodyLarge?.color :
                                      Theme.of(context).textTheme.headlineLarge?.color
                                  )),
                                ],
                              ),
                            ),

                            PopupMenuItem<String>(
                              height: 30,
                              value: 'this_month',
                              child: Row(
                                children: [
                                  const SizedBox(width: Dimensions.paddingSizeSmall),
                                  Text(getTranslated('this_month', context)!, style: robotoRegular.copyWith(
                                      color: result == 'this_month' ?
                                      Theme.of(context).textTheme.bodyLarge?.color :
                                      Theme.of(context).textTheme.headlineLarge?.color
                                  )),
                                ],
                              ),
                            ),

                            PopupMenuItem<String>(
                              height: 30,
                              value: 'custom_date',
                              child: Row(
                                children: [
                                  const SizedBox(width: Dimensions.paddingSizeSmall),
                                  Text(getTranslated('custom_date', context)!, style: robotoRegular.copyWith(
                                      color: result == 'custom_date' ?
                                      Theme.of(context).textTheme.bodyLarge?.color :
                                      Theme.of(context).textTheme.headlineLarge?.color
                                  )),
                                ],
                              ),
                            ),

                          ],
                        ),
                      ),
                    ],
                  );
                }
              ),
            ),

            refund.pendingList != null ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
              child: SizedBox(
                height: 40,
                child: ListView(shrinkWrap: true, scrollDirection: Axis.horizontal, children: [
                  RefundTypeButton(text: getTranslated('all', context), index: 0, refundList: refund.refundList),
                  const SizedBox(width: 5),
                  RefundTypeButton(text: getTranslated('pending', context), index: 1, refundList: refund.pendingList),
                  const SizedBox(width: 5),
                  RefundTypeButton(text: getTranslated('approved', context), index: 2, refundList: refund.approvedList),
                  const SizedBox(width: 5),
                  RefundTypeButton(text: getTranslated('rejected', context), index: 3, refundList: refund.deniedList),
                  const SizedBox(width: 5),
                  RefundTypeButton(text: getTranslated('refunded', context), index: 4, refundList: refund.doneList),
                  const SizedBox(width: 5),
                  ],
                ),
              ),
            ) : const SizedBox(),

            refund.pendingList != null ? refundList!.isNotEmpty ?
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await refund.getRefundList(context, isReload: true);
                }, child: ListView.builder(
                  itemCount: refundList.length,
                  padding: const EdgeInsets.all(0),
                  itemBuilder: (context, index) => RefundWidget(refundModel : refundList![index], isLast: refundList.length-1 == index).animateListEntrance(index),
                ),
              ),
            ) : const Expanded(child: NoDataScreen(title: 'no_refund_request_found')) : const Expanded(child: OrderShimmer()),

            ],
          );
        }),
      ),
    );
  }
}

class OrderShimmer extends StatelessWidget {
  const OrderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      padding: const EdgeInsets.all(0),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          color: Theme.of(context).highlightColor,
          child: Shimmer.fromColors(
            baseColor: ShimmerColors.base(context),
            highlightColor: ShimmerColors.highlight(context),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 10, width: 150, color: Theme.of(context).colorScheme.secondaryContainer),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(child: Container(height: 45, color: Colors.white)),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Container(height: 20, color: Theme.of(context).colorScheme.secondaryContainer),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(height: 10, width: 70, color: Colors.white),
                              const SizedBox(width: 10),
                              Container(height: 10, width: 20, color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
class RefundTypeButton extends StatelessWidget {
  final String? text;
  final int index;
  final List<RefundModel>? refundList;

  const RefundTypeButton({
    super.key,
    required this.text,
    required this.index,
    required this.refundList,
  });

  @override
  Widget build(BuildContext context) {

    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimensions.paddingSizeLarge),

        onTap: () {
          Provider.of<RefundController>(
            context,
            listen: false,
          ).setIndex(index);
        },

        child: Consumer<RefundController>(
          builder: (context, refund, child) {

            final bool selected = refund.refundTypeIndex == index;

            return Container(
              height: 40,

              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeLarge,
              ),

              alignment: Alignment.center,

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  Dimensions.paddingSizeLarge,
                ),

                color: selected
                    ? Theme.of(context).primaryColor
                    : isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Theme.of(context).colorScheme.secondaryContainer,
              ),

              child: Text(
                text ?? '',

                style: selected
                    ? titilliumBold.copyWith(
                  color: Colors.white,
                )
                    : robotoRegular.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.color,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}