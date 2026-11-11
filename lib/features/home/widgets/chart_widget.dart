import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/home/controllers/seller_analytics_controller.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/features/home/widgets/transaction_chart_widget.dart';

class ChartWidget extends StatelessWidget {
  const ChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            spreadRadius: 0,
            blurRadius: 2,
          ),
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            spreadRadius: -3,
            blurRadius: 12,
            offset: Offset.fromDirection(0,6),
          )
        ],
      ),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall, horizontal: Dimensions.paddingSizeSmall),
        child: Consumer<SellerAnalyticsController>(builder: (context, analytics, child) {
          return (analytics.userCommissions!=null && analytics.userEarnings != null) ?
          const TransactionChart() : SizedBox(height : 300,  child: EarningStatisticsShimmer(isDarkMode: Provider.of<ThemeController>(context).darkTheme));
        }),
      ),
    );
  }
}
