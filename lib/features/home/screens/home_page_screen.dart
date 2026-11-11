import 'package:flutter/cupertino.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/notification/controllers/notification_controller.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/features/bank_info/controllers/bank_info_controller.dart';
import 'package:syriacosmeticsmanger/features/home/controllers/seller_analytics_controller.dart';
import 'package:syriacosmeticsmanger/features/action_center/controllers/action_center_controller.dart';
import 'package:syriacosmeticsmanger/features/action_center/widgets/action_center_card_widget.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/widgets/seller_center_card_widget.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/controllers/delivery_man_controller.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/review/controllers/product_review_controller.dart';
import 'package:syriacosmeticsmanger/features/shipping/controllers/shipping_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/features/home/widgets/chart_widget.dart';
import 'package:syriacosmeticsmanger/features/home/widgets/completed_order_widget.dart';
import 'package:syriacosmeticsmanger/features/home/widgets/on_going_order_widget.dart';
import 'package:syriacosmeticsmanger/features/product/widgets/stock_out_product_widget.dart';
import 'package:syriacosmeticsmanger/features/notification/screens/notification_screen.dart';
import 'package:syriacosmeticsmanger/features/product/screens/most_popular_product_screen.dart';
import 'package:syriacosmeticsmanger/features/product/screens/top_selling_product_screen.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/widgets/top_delivery_man_view_widget.dart';


import 'package:syriacosmeticsmanger/core/animations/app_animations.dart';


class HomePageScreen extends StatefulWidget {
  final Function? callback;
  const HomePageScreen({super.key, this.callback});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}



class _HomePageScreenState extends State<HomePageScreen> {
  final ScrollController _scrollController = ScrollController();
  Future<void> _loadData(BuildContext context, bool reload) async {
    final profile = Provider.of<ProfileController>(context, listen: false);
    final bank = Provider.of<BankInfoController>(context, listen: false);
    profile.getSellerInfo().then((_) => bank.setBankInfo(profile.userInfoModel));

    if(Provider.of<OrderController>(context, listen: false).orderModel == null || reload) {
      Provider.of<OrderController>(context, listen: false).getOrderList(context,1,'all', null, reload: reload);
    }
    Provider.of<SellerAnalyticsController>(context, listen: false).getAnalyticsFilterData('overall');
    Provider.of<SellerCenterController>(context, listen: false).getSellerCenterOverview();
    Provider.of<ActionCenterController>(context, listen: false).getInsights(clearSeverity: true);
    Provider.of<SellerCenterController>(context, listen: false).getActivities();
    Provider.of<SplashController>(context,listen: false).getColorList();
    Provider.of<ProductController>(context,listen: false).getStockOutProductList(1, LocalizationController.apiLanguageCode(context), reload: reload);

    Provider.of<ProductController>(context,listen: false).getTopSellingProductList(1, context, LocalizationController.apiLanguageCode(context), reload: reload);
    Provider.of<ShippingController>(context,listen: false).getCategoryWiseShippingMethod();
    Provider.of<ShippingController>(context,listen: false).getSelectedShippingMethodType(context);
    Provider.of<DeliveryManController>(context, listen: false).getTopDeliveryManList(context);
    Provider.of<SellerAnalyticsController>(context, listen: false).getDashboardRevenueData('yearEarn');

    Provider.of<SellerAnalyticsController>(context, listen: false).setRevenueFilterType(0, notify: false);
    Provider.of<NotificationController>(context, listen: false).getNotificationList(1);
    Provider.of<ProductController>(context, listen: false).getStockLimitStatus(context);
    Provider.of<ProductController>(context,listen: false).setShowCookie(true, notify: false);

    Provider.of<ProductController>(context,listen: false).getMostPopularProductList(1, context, LocalizationController.apiLanguageCode(context), reload: reload);

    Provider.of<ProductReviewController>(context, listen: false).getReviewList(context);
  }


  @override
  void initState() {
    super.initState();
    Provider.of<SellerAnalyticsController>(context, listen: false).setAnalyticsFilterType(0, notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData(context, false);
    });
  }
  @override
  Widget build(BuildContext context) {
    double limitedStockCardHeight = MediaQuery.of(context).size.width / 1.4;


    return Scaffold(
      body: Consumer<OrderController>(builder: (context, order, child) {
          return RefreshIndicator(
            onRefresh: () async {
              Provider.of<SellerAnalyticsController>(context, listen: false).setAnalyticsFilterName('overall');
              Provider.of<SellerAnalyticsController>(context, listen: false).setAnalyticsFilterType(0);
              await _loadData(context, true);
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  elevation: 0,
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  surfaceTintColor: Theme.of(context).highlightColor,
                  backgroundColor: Theme.of(context).highlightColor,
                  snap: true,
                  title: Image.asset(Images.logoWithAppName, height: 35),
                  actions: [
                    Consumer<NotificationController>(
                      builder: (context, notificationController, _) {
                        return InkWell(onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const NotificationScreen())),
                          child: Stack(
                            children: [
                              Padding(padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, 0),
                                child: Icon(CupertinoIcons.bell, color: Theme.of(context).primaryColor),
                              ),
                              Positioned(top: 5,right: 18,child: Align(alignment: AlignmentDirectional.topEnd,
                                child: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.error,
                                  radius: 8,child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(1.0),
                                      child: Text('${notificationController.notificationModel?.newNotificationItem??0}',
                                        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white),),
                                    ),
                                  ),)
                                )
                              ),
                            ],
                          ),
                        );
                      }
                    )
                  ],
                ),

                SliverToBoxAdapter(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      const SellerCenterCardWidget().animateSectionEntrance(index: 0),
                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      // Above the order lists on purpose: what needs attention comes
                      // before what merely happened. It renders nothing at all when
                      // nothing is waiting.
                      const ActionCenterCardWidget().animateSectionEntrance(index: 0),

                       OngoingOrderWidget(callback: widget.callback).animateSectionEntrance(index: 1),

                      CompletedOrderWidget(callback: widget.callback).animateSectionEntrance(index: 2),
                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      Consumer<ProductController>(
                        builder: (context, prodProvider, child) {
                          List<Product> productList;
                          productList = prodProvider.stockOutProductList ?? [];
                          return productList.isNotEmpty ?
                          SizedBox(
                            height: limitedStockCardHeight,
                            /*
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              boxShadow: [
                                BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha:.05),
                                  spreadRadius: -3, blurRadius: 12, offset: Offset.fromDirection(0,6))],
                            ),
                             */
                            child: const StockOutProductView( isHome: true)
                          ).animateSectionEntrance(index: 3) : const SizedBox();
                        }
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      const ChartWidget().animateSectionEntrance(index: 4),

                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      const TopSellingProductScreen(isMain: true).animateSectionEntrance(index: 5),

                      const MostPopularProductScreen(isMain: true).animateSectionEntrance(index: 6),
                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      (Provider.of<SplashController>(context, listen: false).configModel!.shippingMethod != 'inhouse_shipping' ?
                      const TopDeliveryManViewWidget(isMain: true) : const SizedBox()).animateSectionEntrance(index: 7)

                    ],
                  ),
                )
              ],
            ),
          );
        },

      ),
    );
  }
}







class TutorialFlowDialogWidget extends StatelessWidget {
  const TutorialFlowDialogWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: 200,
      color: Colors.red,
    );
  }
}
