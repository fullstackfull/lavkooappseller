import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/models/analytics_models.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Storefront analytics: how many people reached this shop, what they looked
/// at, and which products turned views into carts.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String? _range;

  @override
  void initState() {
    Provider.of<SellerCenterController>(context, listen: false).getAnalytics();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('analytics', context)),
      body: RefreshIndicator(
        onRefresh: () => Provider.of<SellerCenterController>(context, listen: false)
            .getAnalytics(range: _range),
        color: Theme.of(context).cardColor,
        backgroundColor: Theme.of(context).primaryColor,
        child: Consumer<SellerCenterController>(
          builder: (context, sellerCenter, _) {
            final SellerAnalyticsModel? analytics = sellerCenter.analytics;
            if (analytics == null) {
              return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * .6,
                  child: Center(child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  )),
                ),
              ]);
            }

            final AnalyticsSummaryModel summary = analytics.summary ?? AnalyticsSummaryModel();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                _RangePickerWidget(
                  analytics: analytics,
                  // The tapped range, not the one the last response echoed: the
                  // chip has to move on tap, while the new window is still loading.
                  selected: _range ?? analytics.range,
                  onChanged: (range) {
                    setState(() => _range = range);
                    sellerCenter.getAnalytics(range: range);
                  },
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                if (!analytics.hasData)
                  _CardWidget(children: [
                    Text(getTranslated('no_analytics_data_yet', context)!,
                        style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                    // The backend says WHY the window is empty; passing the reason
                    // through beats an empty screen with no explanation.
                    Text(getTranslated('analytics_state_${analytics.state}', context)
                            ?? getTranslated('no_traffic_in_this_period', context)!,
                        style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
                  ])
                else ...[
                  Row(children: [
                    _MetricCardWidget(title: 'visitors', value: '${summary.visitors}'),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    _MetricCardWidget(title: 'sessions', value: '${summary.sessions}'),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Row(children: [
                    _MetricCardWidget(title: 'product_views', value: '${summary.productViews}'),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    _MetricCardWidget(title: 'cart_adds', value: '${summary.cartAdds}'),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Row(children: [
                    _MetricCardWidget(title: 'orders', value: '${summary.orders}'),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    _MetricCardWidget(
                      title: 'revenue',
                      value: PriceConverter.convertPrice(context, summary.revenue),
                    ),
                  ]),

                  if (summary.productViews > 0) ...[
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    _CardWidget(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(getTranslated('view_to_cart_rate', context)!,
                            style: robotoRegular.copyWith(
                                color: Theme.of(context).textTheme.bodyLarge?.color)),
                        Text('${(summary.cartAddRate * 100).toStringAsFixed(1)}%',
                            style: robotoMedium.copyWith(color: Theme.of(context).primaryColor)),
                      ]),
                    ]),
                  ],

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
                    child: Text(getTranslated('most_viewed_products', context)!,
                        style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                  ),

                  if (analytics.products.isEmpty)
                    const NoDataScreen()
                  else
                    ...analytics.products.map((product) => Padding(
                      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                      child: _ProductRowWidget(product: product),
                    )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RangePickerWidget extends StatelessWidget {
  final SellerAnalyticsModel analytics;
  final String? selected;
  final ValueChanged<String> onChanged;
  const _RangePickerWidget({required this.analytics, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final List<String> ranges = analytics.ranges.isNotEmpty
        ? analytics.ranges
        : const ['today', '7d', '30d', '90d', '365d'];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ranges.length,
        separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSizeExtraSmall),
        itemBuilder: (context, index) {
          final String range = ranges[index];
          final bool isSelected = range == selected;
          return InkWell(
            onTap: () => onChanged(range),
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
              child: Text(getTranslated('range_$range', context) ?? range,
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

class _MetricCardWidget extends StatelessWidget {
  final String title;
  final String value;
  const _MetricCardWidget({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          boxShadow: [
            BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: .05),
                spreadRadius: -3, blurRadius: 12, offset: Offset.fromDirection(0, 6)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeExtraLarge,
                  color: Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: 2),
          Text(getTranslated(title, context)!,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
        ]),
      ),
    );
  }
}

class _ProductRowWidget extends StatelessWidget {
  final AnalyticsProductModel product;
  const _ProductRowWidget({required this.product});

  @override
  Widget build(BuildContext context) {
    return _CardWidget(children: [
      Text(product.name ?? '#${product.productId}',
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      Row(children: [
        _ProductStatWidget(title: 'views', value: product.views),
        _ProductStatWidget(title: 'visitors', value: product.visitors),
        _ProductStatWidget(title: 'cart_adds', value: product.cartAdds),
      ]),
    ]);
  }
}

class _ProductStatWidget extends StatelessWidget {
  final String title;
  final int value;
  const _ProductStatWidget({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$value',
            style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
        Text(getTranslated(title, context)!,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
      ]),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final List<Widget> children;
  const _CardWidget({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        boxShadow: [
          BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: .05),
              spreadRadius: -3, blurRadius: 12, offset: Offset.fromDirection(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
