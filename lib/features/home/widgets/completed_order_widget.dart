import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syriacosmeticsmanger/features/home/controllers/seller_analytics_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/features/home/widgets/order_type_button_widget.dart';

class CompletedOrderWidget extends StatelessWidget {
  final Function? callback;
  const CompletedOrderWidget({super.key, this.callback});

  @override
  Widget build(BuildContext context) {
    return Consumer<SellerAnalyticsController>(
      builder: (context, analyticsController, child) {
        // ✅ شلنا الـ Consumer الداخلي المكرر، وحسبنا القيم مرة وحدة
        final data = analyticsController.businessAnalyticsFilterData;

        // ✅ إذا البيانات فاضية نرجع الـ Shimmer
        if (data == null) {
          return CompletedOrdersShimmer(
            isDarkMode: Provider.of<ThemeController>(context).darkTheme,
          );
        }

        final int delivered = data.delivered ?? 0;
        final int canceled  = data.canceled  ?? 0;
        final int returned  = data.returned  ?? 0;
        final int failed    = data.failed    ?? 0;
        final int total = delivered + canceled + returned + failed;
        double percent(int v) => total > 0 ? v / total : 0;

        // ✅ التعديلات: أضفنا margin و borderRadius
        return  Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeMedium,
                vertical: Dimensions.paddingSizeSmall,
              ),
              child: Text(
                getTranslated('completed_orders', context)!,
                style: robotoMedium.copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: Dimensions.fontSizeLarge,
                ),
              ),
            ),


            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeMedium,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: .05),
                    spreadRadius: -3,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  OrderTypeButtonWidget(
                    color: const Color(0xFF2C825E),
                    // color: Theme.of(context).colorScheme.onTertiaryContainer,
                    text: getTranslated('delivered', context),
                    index: 3,
                    numberOfOrder: delivered,
                    percentage: percent(delivered),
                    callback: callback,
                  ),

                  OrderTypeButtonWidget(
                    color: const Color(0xFF17724C),
                    // color: Theme.of(context).colorScheme.error,
                    text: getTranslated('cancelled', context),
                    index: 6,
                    numberOfOrder: canceled,
                    percentage: percent(canceled),
                    callback: callback,
                  ),

                  OrderTypeButtonWidget(
                    color: const Color(0xFF2C825E),
                    // color: Theme.of(context).textTheme.bodyLarge?.color ??
                    //     Theme.of(context).primaryColor,
                    text: getTranslated('returned', context),
                    index: 4,
                    numberOfOrder: returned,
                    percentage: percent(returned),
                    callback: callback,
                  ),

                  OrderTypeButtonWidget(
                    showBorder: false,
                    color: const Color(0xFF0E442E),
                    // color: Theme.of(context).colorScheme.error,
                    text: getTranslated('failed_title', context),
                    index: 5,
                    numberOfOrder: failed,
                    percentage: percent(failed),
                    callback: callback,
                  ),

                  const SizedBox(height: Dimensions.paddingSizeSmall),

                ],
              ),
            ),
          ],
        );
      },
    );
  }
}



class CompletedOrdersShimmer extends StatelessWidget {
  final bool isDarkMode;
  const CompletedOrdersShimmer({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final shimmerColor = Theme.of(context).colorScheme.secondaryContainer;

    final baseColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[500]! : Colors.grey[100]!;

    return Container(
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
            // Title shimmer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(height: 14, width: 160, color: shimmerColor),
            ),
            const SizedBox(height: 12),

            // Shimmer list
            ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (_, __) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  height: 70,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

