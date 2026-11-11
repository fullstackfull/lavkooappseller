import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/theme/app_glass.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/confirmation_dialog_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_dialog_widget.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/digital_product_controller.dart';
import 'package:syriacosmeticsmanger/features/ai/controllers/ai_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/category_controller.dart';
import 'package:syriacosmeticsmanger/features/shop/controllers/shop_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/wallet/controllers/wallet_controller.dart';
import 'package:syriacosmeticsmanger/helper/network_info.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/features/home/screens/home_page_screen.dart';
import 'package:syriacosmeticsmanger/features/menu/screens/more_screen.dart';
import 'package:syriacosmeticsmanger/features/order/screens/order_screen.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/barcode_scan_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/screens/pos_product_screen.dart';
import 'package:syriacosmeticsmanger/features/product/screens/product_list_screen.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  int _pageIndex = 0;
  late List<Widget> _screens;

  // Tabs are built on first visit, then kept alive by the IndexedStack.
  // Building all five eagerly fired the POS and catalogue requests on every
  // cold start before the user ever opened those tabs.
  final Set<int> _visitedTabs = {0, 1};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    String languageCode = LocalizationController.apiLanguageCode(context);
    // getSellerInfo() is fetched by HomePageScreen; calling it here too meant
    // two identical requests on every cold start.
    Provider.of<DigitalProductController>(context, listen: false).getDigitalAuthor();
    Provider.of<DigitalProductController>(context, listen: false).getPublishingHouse();
    Provider.of<CategoryController>(context,listen: false).getCategoryList(context, null, languageCode);
    Provider.of<CartController>(context,listen: false).getCartData();
    Provider.of<ShopController>(context, listen: false).getShopInfo();

    // The transaction list is unpaginated and grows forever; it is now fetched
    // by the transaction screen itself rather than at every app launch.
    Provider.of<WalletController>(context, listen: false).getPaymentInfoList();

    if(Provider.of<SplashController>(context,listen: false).configModel?.isAiFeatureActive == 1) {
      Provider.of<AiController>(context,listen: false).generateLimitCheck();
    }

    _screens = [
      HomePageScreen(callback: () {
        setState(() {
          setPage(1);
        });
      }),

      const OrderScreen(),
      const POSProductScreen(),
      const ProductListMenuScreen(isTab: true),
      MoreScreen(onSelectTab: setPage),
    ];

    NetworkInfo.checkConnectivity(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool posEnabled = Provider.of<SplashController>(context).configModel?.posActive == 1
        && Provider.of<ProfileController>(context).userInfoModel?.posActive == 1;
    if (!posEnabled && _pageIndex == 2) {
      // POS access was revoked while the POS tab was open — its nav item is
      // gone, so land back on Home instead of showing an orphaned page.
      _pageIndex = 0;
    }
    final List<({int page, String icon, String label})> navItems = [
      (page: 0, icon: Images.home, label: 'home'),
      (page: 1, icon: Images.order, label: 'my_order'),
      if (posEnabled) (page: 2, icon: Images.pos, label: 'pos'),
      (page: 3, icon: Images.productIcon, label: 'products'),
      (page: 4, icon: Images.menu, label: 'more'),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (_pageIndex != 0) {
          setPage(0);
        } else {
          _onWillPop(context);
        }
        if(didPop) return;
      },

      child: Scaffold(
        key: _scaffoldKey,
        extendBody: true, // 👈 مهم حتى يمشي المحتوى خلف الشريط ويشتغل تأثير الزجاج

        floatingActionButton: posEnabled && _pageIndex == 2 ? FloatingActionButton(
          backgroundColor: Theme.of(context).primaryColor,
          onPressed: () {
            Provider.of<BarcodeScanController>(context, listen: false).scanProductBarCode(context);
          },
          child: Padding(padding: const EdgeInsets.all(12.0), child: Image.asset(Images.scanner)),
        ) : null,

        // 👇 الشريط الجديد: عائم + زجاجي
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: AppGlass.of(context).blurFilter,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      Theme.of(context).cardColor.withValues(alpha: 0.82),
                      Theme.of(context).cardColor.withValues(alpha: 0.62),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(Dimensions.radiusXLarge),
                  border: Border.all(color: AppGlass.of(context).border),
                  boxShadow: AppGlass.of(context).shadowMedium,
                ),
                child: BottomNavigationBar(
                  backgroundColor: Colors.transparent, // 👈 ضروري حتى يبين الزجاج
                  elevation: 0,
                  selectedItemColor: Theme.of(context).primaryColor,
                  unselectedItemColor: Theme.of(context).hintColor,
                  selectedFontSize: Dimensions.fontSizeSmall,
                  unselectedFontSize: Dimensions.fontSizeSmall,
                  selectedLabelStyle: robotoBold,
                  showUnselectedLabels: true,
                  currentIndex: _selectedNavIndex(navItems),
                  type: BottomNavigationBarType.fixed,
                  items: [
                    for (final item in navItems)
                      _barItem(item.icon, getTranslated(item.label, context), item.page),
                  ],
                  onTap: (int index) => setPage(navItems[index].page),
                ),
              ),
            ),
          ),
        ),
        // IndexedStack keeps each tab's State alive. With PageView.builder the
        // Home tab was disposed on every switch and re-fired its ~16 startup
        // requests when the user came back to it.
        body: IndexedStack(
          index: _pageIndex,
          children: [
            for (int i = 0; i < _screens.length; i++)
              _visitedTabs.contains(i) ? _screens[i] : const SizedBox(),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _barItem(String icon, String? label, int index) {
    final bool isSelected = index == _pageIndex;
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSize,
          vertical: Dimensions.paddingSizeExtraSmall,
        ),
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Dimensions.radiusPill),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(width: index == _pageIndex ? Dimensions.iconSizeLarge : Dimensions.iconSizeMedium,
                child: Image.asset(icon, color: index == _pageIndex ?
                Theme.of(context).primaryColor : Theme.of(context).hintColor)
            ),
          ],
        ),
      ),
      label: label,
    );
  }

  int _selectedNavIndex(List<({int page, String icon, String label})> navItems) {
    final int index = navItems.indexWhere((item) => item.page == _pageIndex);
    return index >= 0 ? index : 0;
  }

  void setPage(int pageIndex) {
    setState(() {
      _visitedTabs.add(pageIndex);
      _pageIndex = pageIndex;
    });
  }


  Future<bool> _onWillPop(BuildContext context) async {
    showAnimatedDialogWidget(context,  ConfirmationDialogWidget(icon: Images.logOut,
      title: getTranslated('exit_app', context),
      description: getTranslated('do_you_want_to_exit_the_app', context),
      onYesPressed: () {
        SystemNavigator.pop();
      },
    ), isFlip: true);

    return true;
  }

}