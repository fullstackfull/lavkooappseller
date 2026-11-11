import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/helper/app_health_reporter.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_asset_image_widget.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/add_product_image_controller.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/add_product_tax_controller.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/digital_product_controller.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/variation_controller.dart';
import 'package:syriacosmeticsmanger/features/ai/controllers/ai_controller.dart';
import 'package:syriacosmeticsmanger/features/barcode/controllers/barcode_controller.dart';
import 'package:syriacosmeticsmanger/features/clearance_sale/controllers/clearance_sale_controller.dart';
import 'package:syriacosmeticsmanger/features/dashboard/widgets/custom_tutorial_dialog.dart';
import 'package:syriacosmeticsmanger/features/notification/controllers/notification_controller.dart';
import 'package:syriacosmeticsmanger/features/order_details/controllers/order_details_controller.dart';
import 'package:syriacosmeticsmanger/features/order_edit/controllers/order_edit_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/barcode_scan_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/coupon_discount_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/customer_controller.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/category_controller.dart';
import 'package:syriacosmeticsmanger/features/product/widgets/cookies_widget.dart';
import 'package:syriacosmeticsmanger/features/product_details/controllers/product_details_controller.dart';
import 'package:syriacosmeticsmanger/features/restock/controllers/restock_controller.dart';
import 'package:syriacosmeticsmanger/features/vat_management/controllers/vat_controller.dart';
import 'package:syriacosmeticsmanger/features/wallet/controllers/wallet_controller.dart';
import 'package:syriacosmeticsmanger/localization/app_localization.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/settings/controllers/business_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/cart_controller.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/offline_sales_controller.dart';
import 'package:syriacosmeticsmanger/features/chat/controllers/chat_controller.dart';
import 'package:syriacosmeticsmanger/features/coupon/controllers/coupon_controller.dart';
import 'package:syriacosmeticsmanger/features/delivery_man/controllers/delivery_man_controller.dart';
import 'package:syriacosmeticsmanger/features/emergency_contract/controllers/emergency_contact_controller.dart';
import 'package:syriacosmeticsmanger/features/language/controllers/language_controller.dart';
import 'package:syriacosmeticsmanger/localization/controllers/localization_controller.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/location_controller.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/features/product/controllers/product_controller.dart';
import 'package:syriacosmeticsmanger/features/review/controllers/product_review_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/refund/controllers/refund_controller.dart';
import 'package:syriacosmeticsmanger/features/addProduct/controllers/add_product_controller.dart';
import 'package:syriacosmeticsmanger/features/shipping/controllers/shipping_controller.dart';
import 'package:syriacosmeticsmanger/features/shop/controllers/shop_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';
import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';
import 'package:syriacosmeticsmanger/features/bank_info/controllers/bank_info_controller.dart';
import 'package:syriacosmeticsmanger/features/home/controllers/seller_analytics_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/reports/controllers/report_controller.dart';
import 'package:syriacosmeticsmanger/features/statement/controllers/statement_controller.dart';
import 'package:syriacosmeticsmanger/features/returns/controllers/return_controller.dart';
import 'package:syriacosmeticsmanger/features/inventory/controllers/inventory_controller.dart';
import 'package:syriacosmeticsmanger/features/automation/controllers/automation_controller.dart';
import 'package:syriacosmeticsmanger/features/brand_claims/controllers/brand_claim_controller.dart';
import 'package:syriacosmeticsmanger/features/security/controllers/security_controller.dart';
import 'package:syriacosmeticsmanger/features/finance_control/controllers/finance_control_controller.dart';
import 'package:syriacosmeticsmanger/features/control_tower/controllers/control_tower_controller.dart';
import 'package:syriacosmeticsmanger/features/action_center/controllers/action_center_controller.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/controllers/bulk_job_controller.dart';
import 'package:syriacosmeticsmanger/features/transaction/controllers/transaction_controller.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/glass/glass_container.dart';
import 'package:syriacosmeticsmanger/theme/dark_theme.dart';
import 'package:syriacosmeticsmanger/theme/light_theme.dart';
import 'package:syriacosmeticsmanger/helper/version_helper.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';
import 'package:syriacosmeticsmanger/features/splash/screens/splash_screen.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
export 'package:syriacosmeticsmanger/core/app_context.dart' show Get, navigatorKey, flutterLocalNotificationsPlugin;

import 'di_container.dart' as di;
import 'firebase_options.dart';
import 'notification/my_notification.dart';
import 'package:syriacosmeticsmanger/common/controller/show_bottom_sheet_controller.dart';
import 'package:syriacosmeticsmanger/common/controller/tutorial_controller.dart';


Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Route every uncaught framework and async error to Crashlytics, so a crash
    // on a seller's phone is visible without waiting for a phone call.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      // Banked locally and sent on the next launch. Crashlytics gets the stack
      // trace; the server gets the count, which is what turns crashes into a
      // crash-free RATE on the monitoring console's mobile sections.
      AppHealthReporter.recordCrash();
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      AppHealthReporter.recordCrash();
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Background notifications
    FirebaseMessaging.onBackgroundMessage(
      myBackgroundMessageHandler,
    );

    // TLS verification stays on in release; verbose download logging is debug-only.
    await FlutterDownloader.initialize(
      debug: kDebugMode,
      ignoreSsl: false,
    );

    await di.init();
    await AppVersion.load();

    // Bank this launch as a session and flush whatever earlier launches banked.
    // After AppVersion.load() so the counters carry the version they belong to,
    // and awaited-but-guarded inside so a slow network cannot delay first paint
    // beyond the client's own timeout.
    AppHealthReporter.begin(di.sl<SharedPreferences>(), di.sl<DioClient>().dio!);

    NotificationBody? body;

    try {
      final RemoteMessage? remoteMessage =
      await FirebaseMessaging.instance.getInitialMessage();

      if (remoteMessage != null) {
        body = NotificationBody.fromJson(remoteMessage.data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Initial notification error: $e');
      }
    }

    await MyNotification.initialize(
      flutterLocalNotificationsPlugin,
    );

    // Deferred to after first paint: asking for the notification permission
    // before runApp() blocks cold start behind an OS dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    });

    runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (context) => di.sl<ThemeController>()),
      ChangeNotifierProvider(create: (context) => di.sl<SplashController>()),
      ChangeNotifierProvider(create: (context) => di.sl<LanguageController>()),
      ChangeNotifierProvider(create: (context) => di.sl<LocalizationController>()),
      ChangeNotifierProvider(create: (context) => di.sl<AuthController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ProfileController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ShopController>()),
      ChangeNotifierProvider(create: (context) => di.sl<OrderController>()),
      ChangeNotifierProvider(create: (context) => di.sl<BankInfoController>()),
      ChangeNotifierProvider(create: (context) => di.sl<SellerAnalyticsController>()),
      ChangeNotifierProvider(create: (context) => di.sl<SellerCenterController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ReportController>()),
      ChangeNotifierProvider(create: (context) => di.sl<BulkJobController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ActionCenterController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ControlTowerController>()),
      ChangeNotifierProvider(create: (context) => di.sl<AutomationController>()),
      ChangeNotifierProvider(create: (context) => di.sl<FinanceControlController>()),
      ChangeNotifierProvider(create: (context) => di.sl<BrandClaimController>()),
      ChangeNotifierProvider(create: (context) => di.sl<SecurityController>()),
      ChangeNotifierProvider(create: (context) => di.sl<InventoryController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ReturnController>()),
      ChangeNotifierProvider(create: (context) => di.sl<StatementController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ChatController>()),
      ChangeNotifierProvider(create: (context) => di.sl<BusinessController>()),
      ChangeNotifierProvider(create: (context) => di.sl<TransactionController>()),
      ChangeNotifierProvider(create: (context) => di.sl<AddProductController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ProductController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ProductReviewController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ShippingController>()),
      ChangeNotifierProvider(create: (context) => di.sl<DeliveryManController>()),
      ChangeNotifierProvider(create: (context) => di.sl<RefundController>()),
      ChangeNotifierProvider(create: (context) => di.sl<CartController>()),
      ChangeNotifierProvider(create: (context) => di.sl<EmergencyContactController>()),
      ChangeNotifierProvider(create: (context) => di.sl<CouponController>()),
      ChangeNotifierProvider(create: (context) => di.sl<LocationController>()),
      ChangeNotifierProvider(create: (context) => di.sl<NotificationController>()),
      ChangeNotifierProvider(create: (context) => di.sl<WalletController>()),
      ChangeNotifierProvider(create: (context) => di.sl<OrderDetailsController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ProductDetailsController>()),
      ChangeNotifierProvider(create: (context) => di.sl<BarcodeController>()),
      ChangeNotifierProvider(create: (context) => di.sl<RestockController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ClearanceSaleController>()),
      ChangeNotifierProvider(create: (context) => di.sl<CustomerController>()),
      ChangeNotifierProvider(create: (context) => di.sl<CouponDiscountController>()),
      ChangeNotifierProvider(create: (context) => di.sl<BarcodeScanController>()),
      ChangeNotifierProvider(create: (context) => di.sl<AddProductImageController>()),
      ChangeNotifierProvider(create: (context) => di.sl<VariationController>()),
      ChangeNotifierProvider(create: (context) => di.sl<DigitalProductController>()),
      ChangeNotifierProvider(create: (context) => di.sl<CategoryController>()),
      ChangeNotifierProvider(create: (context) => di.sl<ShowBottomSheetController>()),
      ChangeNotifierProvider(create: (context) => di.sl<TutorialController>()),
      ChangeNotifierProvider(create: (context) => di.sl<AddProductTaxController>()),
      ChangeNotifierProvider(create: (context) => di.sl<VatController>()),
      ChangeNotifierProvider(create: (context) => di.sl<AiController>()),
      ChangeNotifierProvider(create: (context) => di.sl<OrderEditController>()),
      ChangeNotifierProvider(create: (context) => di.sl<OfflineSalesController>()..initialise()),
    ],
      child: _GlobalScrollListener(
        child: MyApp(body: body)
      ),

    ));
  }, (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    AppHealthReporter.recordCrash();
  });
}

class MyApp extends StatelessWidget {
  final NotificationBody? body;
  const MyApp({super.key, this.body});

  @override
  Widget build(BuildContext context) {
    final bool isLtr  = Provider.of<LocalizationController>(context, listen: false).isLtr;

    List<Locale> locals = [];
    for (var language in AppConstants.languages) {
      locals.add(Locale(language.languageCode!, language.countryCode));
    }

    return MaterialApp(
      navigatorObservers: [_BottomSheetObserver(context: context)],
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: Provider.of<ThemeController>(context).darkTheme ? dark : light,
      locale: Provider.of<LocalizationController>(context).locale,
      builder:(context,child) {
        return Consumer<ShopController>(
          builder: (context, shopController, _) {
            return Consumer<ProductController>(
                builder: (context, productController, _) {
                  // System font scaling is honoured up to 1.3x instead of being
                  // switched off entirely, which used to make the app unusable
                  // for anyone relying on larger text.
                  final double systemScale = MediaQuery.textScalerOf(context).scale(1.0);
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(systemScale.clamp(1.0, 1.3)),
                    ),
                    child: AmbientBackground(
                      child: Stack(children: [
                      SafeArea(top: false, child: child!),


                      if(Provider.of<AuthController>(context, listen: false).isLoggedIn() && shopController.shopModel != null &&
                        (100 != (shopController.shopModel?.setupGuideApp?.values.where((v) => v == 1).length ?? 0) / (shopController.shopModel?.setupGuideApp?.length ?? 0) * 100))
                        Selector<ShowBottomSheetController, bool>(
                          selector: (_, provider) => provider.isBottomSheetOpen,
                          builder: (_, isBottomSheetOpen, __) {
                            return  (!isBottomSheetOpen || TutorialDialogController().isDialogOpen) ? Positioned.fill(
                              child: Align(alignment: AlignmentDirectional.bottomStart,
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: Platform.isIOS ? 130 : 100, left: Dimensions.paddingSizeDefault, right: Dimensions.paddingSizeDefault),
                                  child: GestureDetector(
                                    onTap: () {
                                      TutorialDialogController().show(context);
                                    },
                                    child: Stack(
                                      children: [
                                        Selector<TutorialController, bool>(
                                          selector: (_, provider) => provider.isVisible,
                                          builder: (_, isVisible, __) {
                                            return isVisible ? Container(
                                              margin: EdgeInsets.only(
                                                top: Dimensions.radiusDefault,
                                                right: isLtr ? Dimensions.radiusDefault : 0,
                                                left: isLtr ? 0 : Dimensions.radiusDefault
                                              ),
                                              height: 50, width: 50,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).cardColor,
                                                borderRadius: BorderRadius.only(
                                                  topRight: Radius.circular(TutorialDialogController().isDialogOpen && isLtr ? Dimensions.radiusDefault : 0),
                                                  topLeft: Radius.circular(TutorialDialogController().isDialogOpen && isLtr ? 0 : Dimensions.radiusDefault),
                                                  bottomLeft: const Radius.circular(Dimensions.radiusDefault),
                                                  bottomRight: const Radius.circular(Dimensions.radiusDefault),
                                                ),
                                                boxShadow: [BoxShadow(color: Colors.grey[200]!, blurRadius: 3, spreadRadius: 1)],
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.all(Dimensions.paddingSize),
                                                child: CustomAssetImageWidget(Images.tutorialFlowIcon, width: 20, height: 20)
                                              ),
                                            ) : const SizedBox();
                                          }
                                        ) ,

                                        if((Provider.of<ShopController>(context, listen: false).shopModel?.setupGuideApp?.length ?? 0) > 0)
                                          Positioned(
                                            top: 0,
                                            right: isLtr ? 0 : null,
                                            left: isLtr ? null : 0,
                                            child: const Material(color: Colors.transparent, child: TutorialCountWidget()),
                                          ),
                                      ],
                                    )
                                  )
                                )
                              ),
                            ) : const SizedBox();
                          }
                        ),

                      if((productController.stockLimitStatus != null
                          && Provider.of<AuthController>(context, listen: false).isLoggedIn()
                          && productController.showCookies
                          && !productController.isShowCookies()
                          && (productController.stockLimitStatus?.productCount ?? 0) > 0))
                        const Positioned.fill(child: Align(alignment: Alignment.bottomCenter, child: CookiesWidget())),


                    ]),
                    ),
                  );
                }
            );
          }
        );
      },
      localizationsDelegates: const [
        AppLocalization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: locals,
      home: SplashScreen(body: body),
    );
  }
}

class TutorialDialogController {
  static final TutorialDialogController _instance = TutorialDialogController._internal();
  factory TutorialDialogController() => _instance;
  TutorialDialogController._internal();

  bool _isDialogOpen = false;
  bool get isDialogOpen => _isDialogOpen;

  Future<void> show(BuildContext context) async {
    if (_isDialogOpen) return;

    _isDialogOpen = true;

    await showDialog(
      context: Get.context!,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (_) => const CustomTutorialDialog(),
    );

    _isDialogOpen = false;
  }

  void close(BuildContext context) {
    if (_isDialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      _isDialogOpen = false;
    }
  }
}


class _GlobalScrollListener extends StatelessWidget {
  final Widget child;

  const _GlobalScrollListener({required this.child});

  @override
  Widget build(BuildContext context) {
    bool isUserScrolling = false;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {

        if(TutorialDialogController().isDialogOpen) {
          return false;
        }

        final tutorialController = Provider.of<TutorialController>(context, listen: false);

        if (notification is ScrollStartNotification) {
          tutorialController.setVisibility(false);

        }else if (notification is ScrollEndNotification) {
          tutorialController.setVisibility(true);
        }

        if (notification is UserScrollNotification) {
          isUserScrolling = notification.direction != ScrollDirection.idle;
        }

        if(notification.metrics.pixels >= notification.metrics.maxScrollExtent && isUserScrolling) {
          tutorialController.setVisibility(false);
        }

        return false;
      },
      child: child,
    );
  }
}


class _BottomSheetObserver extends NavigatorObserver {
  final BuildContext context;
  final Set<Route> _activeOverlayRoutes = {};

  _BottomSheetObserver({required this.context});

  bool _isOverlay(Route route) =>
      route is ModalBottomSheetRoute || route is DialogRoute;

  void _updateState() {
    final hasActiveOverlay = _activeOverlayRoutes.isNotEmpty;
    final controller = Provider.of<ShowBottomSheetController>(context, listen: false);
    hasActiveOverlay ? controller.openBottomSheet() : controller.closeBottomSheet();
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    if (_isOverlay(route)) {
      _activeOverlayRoutes.add(route);
      _updateState();
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (_isOverlay(route)) {
      _activeOverlayRoutes.remove(route);
      _updateState();
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    if (_isOverlay(route)) {
      _activeOverlayRoutes.remove(route);
      _updateState();
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (_isOverlay(oldRoute!)) _activeOverlayRoutes.remove(oldRoute);
    if (_isOverlay(newRoute!)) _activeOverlayRoutes.add(newRoute);
    _updateState();
  }
}
