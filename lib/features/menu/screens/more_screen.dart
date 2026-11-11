import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/automation/screens/automation_screen.dart';
import 'package:syriacosmeticsmanger/features/brand_claims/screens/brand_claims_screen.dart';
import 'package:syriacosmeticsmanger/features/security/screens/security_screen.dart';
import 'package:syriacosmeticsmanger/features/finance_control/screens/finance_control_screen.dart';
import 'package:syriacosmeticsmanger/features/control_tower/screens/control_tower_screen.dart';
import 'package:syriacosmeticsmanger/features/statement/screens/statement_screen.dart';
import 'package:syriacosmeticsmanger/features/returns/screens/returns_screen.dart';
import 'package:syriacosmeticsmanger/features/inventory/screens/inventory_screen.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/screens/bulk_jobs_screen.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_bottom_sheet_widget.dart';
import 'package:syriacosmeticsmanger/features/addProduct/screens/add_product_tab_view_screen.dart';
import 'package:syriacosmeticsmanger/features/bank_info/screens/bank_info_screen.dart';
import 'package:syriacosmeticsmanger/features/chat/screens/inbox_screen.dart';
import 'package:syriacosmeticsmanger/features/clearance_sale/screens/clearance_sale_screen.dart';
import 'package:syriacosmeticsmanger/features/coupon/screens/coupon_list_screen.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/screens/delivery_man_setup_screen.dart';
import 'package:syriacosmeticsmanger/features/menu/widgets/sign_out_confirmation_dialog_widget.dart';
import 'package:syriacosmeticsmanger/features/more/screens/html_view_screen.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/screens/profile_view_screen.dart';
import 'package:syriacosmeticsmanger/features/refund/screens/refund_screen.dart';
import 'package:syriacosmeticsmanger/features/restock/screens/restock_list_screen.dart';
import 'package:syriacosmeticsmanger/features/review/screens/product_review_screen.dart';
import 'package:syriacosmeticsmanger/features/seller_center/screens/analytics_screen.dart';
import 'package:syriacosmeticsmanger/features/reports/screens/order_report_screen.dart';
import 'package:syriacosmeticsmanger/features/reports/screens/product_report_screen.dart';
import 'package:syriacosmeticsmanger/features/reports/screens/stock_report_screen.dart';
import 'package:syriacosmeticsmanger/features/seller_center/screens/payouts_screen.dart';
import 'package:syriacosmeticsmanger/features/seller_center/screens/scorecard_screen.dart';
import 'package:syriacosmeticsmanger/features/seller_center/screens/verification_screen.dart';
import 'package:syriacosmeticsmanger/features/settings/screens/setting_screen.dart';
import 'package:syriacosmeticsmanger/features/shop/screens/shop_screen.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/models/business_pages_model.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/models/config_model.dart';
import 'package:syriacosmeticsmanger/features/vat_management/screens/vat_management_screen.dart';
import 'package:syriacosmeticsmanger/features/wallet/screens/wallet_screen.dart';
import 'package:syriacosmeticsmanger/helper/version_helper.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The "more" tab of the unified shell — the old menu bottom sheet's entries,
/// grouped into sections instead of one flat grid.
class MoreScreen extends StatelessWidget {
  /// Switches the dashboard to another tab (POS and product entries live
  /// there now, so those tiles select a tab instead of pushing a route).
  final Function(int pageIndex)? onSelectTab;
  const MoreScreen({super.key, this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('more', context), isBackButtonExist: false),
      body: Consumer<SplashController>(
        builder: (context, splashController, _) {
          final ConfigModel? configModel = splashController.configModel;
          return Consumer<ProfileController>(
            builder: (context, profileProvider, child) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeDefault, Dimensions.floatingNavClearance,
                ),
                children: [
                  _MenuSection(title: 'shop_and_account', items: [
                    CustomBottomSheetWidget(image: '${profileProvider.userInfoModel?.imageFullUrl?.path}',
                      isProfile: true, title: getTranslated('profile', context),
                      onTap: () => _push(context, const ProfileScreenView()),
                    ),
                    CustomBottomSheetWidget(image: Images.myShop, title: getTranslated('my_shop', context),
                      onTap: () => _push(context, const ShopScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.pieChart, title: getTranslated('seller_center', context),
                      onTap: () => _push(context, const ScorecardScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.termsAndCondition, title: getTranslated('verification', context),
                      onTap: () => _push(context, const VerificationScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.settings, title: getTranslated('settings', context),
                      onTap: () => _push(context, const SettingsScreen()),
                    ),
                  ]),

                  _MenuSection(title: 'catalog_and_sales', items: [
                    CustomBottomSheetWidget(image: Images.addProduct, title: getTranslated('add_product', context),
                      onTap: () => _push(context, const AddProductTabView(fromHome: false)),
                    ),
                    CustomBottomSheetWidget(image: Images.productIconPp, title: getTranslated('products', context),
                      onTap: () => onSelectTab?.call(3),
                    ),
                    CustomBottomSheetWidget(image: Images.productIconPp, title: getTranslated('bulk_operations', context),
                      onTap: () => _push(context, const BulkJobsScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.restockIcon, title: getTranslated('inventory', context),
                      onTap: () => _push(context, const InventoryScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.restockIcon, title: getTranslated('restock', context),
                      onTap: () => _push(context, const RestockListScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.clearanceSaleImage, title: getTranslated('clearance_sale', context),
                      onTap: () => _push(context, const ClearanceSaleScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.couponIcon, title: getTranslated('coupons', context),
                      onTap: () => _push(context, const CouponListScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.reviewIcon, title: getTranslated('reviews', context),
                      onTap: () => _push(context, const ProductReviewScreen()),
                    ),
                  ]),

                  _MenuSection(title: 'orders_and_operations', items: [
                    if(configModel?.posActive == 1 && profileProvider.userInfoModel?.posActive == 1)
                      CustomBottomSheetWidget(image: Images.pos, title: getTranslated('pos', context),
                        onTap: () => onSelectTab?.call(2),
                      ),
                    CustomBottomSheetWidget(image: Images.refund, title: getTranslated('refund', context),
                      onTap: () => _push(context, const RefundScreen(fromNotification: false, isBacButtonExist: true)),
                    ),
                    CustomBottomSheetWidget(image: Images.refund, title: getTranslated('returns', context),
                      onTap: () => _push(context, const ReturnsScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.message, title: getTranslated('inbox', context),
                      onTap: () => _push(context, const InboxScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.deliveryManIcon, title: getTranslated('deliveryman', context),
                      onTap: () => _push(context, const DeliveryManSetupScreen()),
                    ),
                  ]),

                  _MenuSection(title: 'finance_and_reports', items: [
                    CustomBottomSheetWidget(image: Images.wallet, title: getTranslated('wallet', context),
                      onTap: () => _push(context, const WalletScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.bankingInfo, title: getTranslated('bank_info', context),
                      onTap: () => _push(context, const BankInfoScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.wallet, title: getTranslated('payouts', context),
                      onTap: () => _push(context, const PayoutsScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.bankingInfo, title: getTranslated('statement', context),
                      onTap: () => _push(context, const StatementScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.pieChart, title: getTranslated('analytics', context),
                      onTap: () => _push(context, const AnalyticsScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.reportIcon, title: getTranslated('control_tower', context),
                      onTap: () => _push(context, const ControlTowerScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.settings, title: getTranslated('automation', context),
                      onTap: () => _push(context, const AutomationScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.bankingInfo, title: getTranslated('money_and_pricing', context),
                      onTap: () => _push(context, const FinanceControlScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.privacyPolicy, title: getTranslated('brands', context),
                      onTap: () => _push(context, const BrandClaimsScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.privacyPolicy, title: getTranslated('security_centre', context),
                      onTap: () => _push(context, const SecurityScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.reportIcon, title: getTranslated('order_report', context),
                      onTap: () => _push(context, const OrderReportScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.reportIcon, title: getTranslated('product_report', context),
                      onTap: () => _push(context, const ProductReportScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.reportIcon, title: getTranslated('stock_report', context),
                      onTap: () => _push(context, const StockReportScreen()),
                    ),
                    CustomBottomSheetWidget(image: Images.reportIcon, title: getTranslated('vat_management', context),
                      onTap: () => _push(context, const VatManagementScreen()),
                    ),
                  ]),

                  _MenuSection(title: 'app_and_policies', items: [
                    if(_pageBySlug('terms-and-conditions', splashController.defaultBusinessPages) != null)
                      CustomBottomSheetWidget(image: Images.termsAndCondition, title: getTranslated('terms_and_condition', context),
                        onTap: () => _push(context, HtmlViewScreen(
                          page: _pageBySlug('terms-and-conditions', splashController.defaultBusinessPages),
                        )),
                      ),
                    if(_pageBySlug('about-us', splashController.defaultBusinessPages) != null)
                      CustomBottomSheetWidget(image: Images.aboutUs, title: getTranslated('about_us', context),
                        onTap: () => _push(context, HtmlViewScreen(
                          page: _pageBySlug('about-us', splashController.defaultBusinessPages),
                        )),
                      ),
                    if(_pageBySlug('privacy-policy', splashController.defaultBusinessPages) != null)
                      CustomBottomSheetWidget(image: Images.privacyPolicy, title: getTranslated('privacy_policy', context),
                        onTap: () => _push(context, HtmlViewScreen(
                          page: _pageBySlug('privacy-policy', splashController.defaultBusinessPages),
                        )),
                      ),
                    if(_pageBySlug('refund-policy', splashController.defaultBusinessPages) != null)
                      CustomBottomSheetWidget(image: Images.refundPolicy, title: getTranslated('refund_policy', context),
                        onTap: () => _push(context, HtmlViewScreen(
                          page: _pageBySlug('refund-policy', splashController.defaultBusinessPages),
                        )),
                      ),
                    if(_pageBySlug('return-policy', splashController.defaultBusinessPages) != null)
                      CustomBottomSheetWidget(image: Images.returnPolicy, title: getTranslated('return_policy', context),
                        onTap: () => _push(context, HtmlViewScreen(
                          page: _pageBySlug('return-policy', splashController.defaultBusinessPages),
                        )),
                      ),
                    if(_pageBySlug('cancellation-policy', splashController.defaultBusinessPages) != null)
                      CustomBottomSheetWidget(image: Images.cPolicy, title: getTranslated('cancellation_policy', context),
                        onTap: () => _push(context, HtmlViewScreen(
                          page: _pageBySlug('cancellation-policy', splashController.defaultBusinessPages),
                        )),
                      ),
                    CustomBottomSheetWidget(image: Images.logOut, title: getTranslated('logout', context),
                      onTap: () => showModalBottomSheet(context: context, builder: (_) => const SignOutConfirmationDialogWidget()),
                    ),
                    CustomBottomSheetWidget(image: Images.appInfo, title: 'v - ${AppVersion.current}', onTap: (){}),
                  ]),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  BusinessPageModel? _pageBySlug(String slug, List<BusinessPageModel>? pagesList) {
    if(pagesList != null){
      for (BusinessPageModel page in pagesList) {
        if(page.slug == slug) {
          return page;
        }
      }
    }
    return null;
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if(items.isEmpty) {
      return const SizedBox();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
        child: Text(getTranslated(title, context)!,
          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
      ),
      GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: items,
      ),
      const SizedBox(height: Dimensions.paddingSizeLarge),
    ]);
  }
}
