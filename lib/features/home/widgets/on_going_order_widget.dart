import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syriacosmeticsmanger/features/home/controllers/seller_analytics_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/features/home/widgets/order_type_button_head_widget.dart';

class OngoingOrderWidget extends StatelessWidget {
  final Function? callback;
  const OngoingOrderWidget({super.key, this.callback});

  @override
  Widget build(BuildContext context) {
    return Consumer<SellerAnalyticsController>(
      builder: (context,analyticsController,child){
        return analyticsController.businessAnalyticsFilterData  == null ? BusinessAnalyticsShimmer(isDarkMode: Provider.of<ThemeController>(context).darkTheme) : Container(
          padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
         /*
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha:.05),
                  spreadRadius: -3, blurRadius: 12, offset: Offset.fromDirection(0,6)
              )
            ],
          ),
          */
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeMedium),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(getTranslated('business_analytics', context)!, style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: Dimensions.fontSizeLarge)
                  ),

                  const Expanded(child: SizedBox(width: Dimensions.paddingSizeExtraLarge,)),
                  Container(
                    height: 40, width: 120,
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border.all(width: .7,color: Theme.of(context).hintColor.withValues(alpha:.3)),
                      borderRadius: BorderRadius.circular(Dimensions.paddingSizeExtraSmall),
                    ),
                    child: DropdownButton<String>(
                      iconEnabledColor: Theme.of(context).primaryColor,
                      value: analyticsController.analyticsIndex == 0 ? 'overall' :
                      analyticsController.analyticsIndex == 1 ?  'today' :
                      analyticsController.analyticsIndex == 2 ?  'this_week' :
                      analyticsController.analyticsIndex == 3 ?  'this_month' :
                      'this_year',
                      items: <String>['overall', 'today', 'this_week', 'this_month', 'this_year'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                              getTranslated(value, context)!,
                              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: Theme.of(context).textTheme.bodyLarge?.color)
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        analyticsController.setAnalyticsFilterName(value);
                        analyticsController.setAnalyticsFilterType(
                            value == 'overall' ? 0 :
                            value == 'today'? 1 :
                            value == 'this_week'? 2 :
                            value == 'this_month'? 3 : 4,
                        );
                      },
                      isExpanded: true,
                      underline: const SizedBox(),
                    ),
                  ),
                ],),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),



            Consumer<SellerAnalyticsController>(
              builder: (context, analyticsController, child) {
                // 1. جلب البيانات من السيرفر
                final int pending = analyticsController.businessAnalyticsFilterData?.pending ?? 0;
                final int processing = analyticsController.businessAnalyticsFilterData?.processing ?? 0;
                final int confirmed =analyticsController.businessAnalyticsFilterData?.confirmed ?? 0;
                final int outForDelivery = analyticsController.businessAnalyticsFilterData?.outForDelivery ?? 0;

                final int totalOrders = pending + processing + confirmed + outForDelivery;

                // 2. دالة حساب النسبة
                String calculatePercentage(int count) {
                  if (totalOrders == 0) return "0%";
                  double percentage = (count / totalOrders) * 100;
                  return "${percentage.toStringAsFixed(0)}%";
                }

                return Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall), // إضافة مسافة من جميع الحواف الشاشة
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: (1 / 0.72), // تعديل النسبة قليلاً لتناسب الحجم الجديد مع الارتفاع
                    crossAxisSpacing: Dimensions.paddingSizeSmall, // <--- المسافة الأفقية بين الكاردين يمين ويسار
                    mainAxisSpacing: Dimensions.paddingSizeSmall,  // <--- المسافة العمودية بين الكاردات فوق وتحت
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      OrderTypeButtonHeadWidget(
                        color: const Color(0xFF197F54).withValues(alpha: 0.15),  // ← هون
                        circleColor: const Color(0xFF197F54),
                        // color: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
                        // circleColor: Theme.of(context).colorScheme.error,
                        image: Images.pendingOrderCardIcon,
                        text: getTranslated('pending', context),
                        index: 1,
                        subText: getTranslated('orders', context),
                        numberOfOrder: pending,
                        percentage: calculatePercentage(pending),
                        callback: callback,
                      ),

                      OrderTypeButtonHeadWidget(
                        color: const Color(0xFF2C6F53).withValues(alpha: 0.15),   // ← هون
                        circleColor: const Color(0xFF2C6F53),
                        // color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
                        // circleColor: Theme.of(context).colorScheme.tertiary,
                        image: Images.packagingOrdersCardIcon,
                        text: getTranslated('processing', context),
                        index: 2,
                        numberOfOrder: processing,
                        subText: getTranslated('orders', context),
                        percentage: calculatePercentage(processing),
                        callback: callback,
                      ),

                      OrderTypeButtonHeadWidget(
                        color: const Color(0xFF2C825E).withValues(alpha: 0.15),   // ← هون
                        circleColor: const Color(0xFF2C825E),
                        // color: Theme.of(context).colorScheme.onTertiaryContainer.withValues(alpha: 0.15),
                        // circleColor: Theme.of(context).colorScheme.onTertiaryContainer,
                        image: Images.confirmOrderCardIcon,
                        text: getTranslated('confirmed', context),
                        index: 7,
                        subText: getTranslated('orders', context),
                        numberOfOrder: confirmed,
                        percentage: calculatePercentage(confirmed),
                        callback: callback,
                      ),

                      OrderTypeButtonHeadWidget(
                        color: const Color(0xFF1A7C53).withValues(alpha: 0.15),  // ← هون
                        circleColor: const Color(0xFF1A7C53),
                        // color: Theme.of(context).colorScheme.surfaceTint.withValues(alpha: 0.15),
                        // circleColor: Theme.of(context).colorScheme.surfaceTint,
                        image: Images.outForDeliveryCardIcon,
                        text: getTranslated('out_for_delivery', context),
                        index: 8,
                        subText: '',
                        numberOfOrder: outForDelivery,
                        percentage: calculatePercentage(outForDelivery),
                        callback: callback,
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: Dimensions.paddingSizeSmall),
          ],),);
      },
    );
  }
}



class BusinessAnalyticsShimmer extends StatelessWidget {
  final bool isDarkMode;
  const BusinessAnalyticsShimmer({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final shimmerColor = Theme.of(context).colorScheme.secondaryContainer;

    final baseColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[500]! : Colors.grey[100]!;

    return Container(
      padding: const EdgeInsets.only(top: 12), // Dimensions.paddingSizeSmall
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            spreadRadius: -3,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Icon + Title + Dropdown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(width: 36, height: 36, color: shimmerColor),
                  const SizedBox(width: 12),
                  Container(height: 14, width: 140, color: shimmerColor),
                  const Spacer(),
                  Container(height: 50, width: 120, color: shimmerColor),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Section Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
              child: Container(height: 14, width: 120, color: shimmerColor),
            ),

            // Grid Shimmer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1 / 0.65,
                children: List.generate(4, (_) {
                  return Container(
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}


