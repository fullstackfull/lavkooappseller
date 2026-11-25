import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/helper/version_helper.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/maintenance/maintenance_screen.dart';
import 'package:syriacosmeticsmanger/features/notification/screens/notification_screen.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/models/config_model.dart';
import 'package:syriacosmeticsmanger/features/update/screen/update_screen.dart';
import 'package:syriacosmeticsmanger/helper/network_info.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';
import 'package:syriacosmeticsmanger/notification/my_notification.dart';
import 'package:syriacosmeticsmanger/notification/notification_screens.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/features/auth/screens/auth_screen.dart';
import 'package:syriacosmeticsmanger/features/dashboard/screens/dashboard_screen.dart';

import '../../../theme/controllers/theme_controller.dart';

class SplashScreen extends StatefulWidget {
  final NotificationBody? body;
  const SplashScreen({super.key, this.body});
  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    Provider.of<AuthController>(context, listen: false).setUnAuthorize(false, update: false);
    initCall();
  }

  bool _configFailed = false;
  bool _retrying = false;

  Future<void> initCall() async {
    if(mounted) {
      setState(() {
        _configFailed = false;
        _retrying = true;
      });
    }
    NetworkInfo.checkConnectivity(context);
    Provider.of<SplashController>(context, listen: false).initConfig().then((bool isSuccess) {
      if(!isSuccess) {
        // Without this the app sat on the logo forever whenever the config
        // endpoint was unreachable, with no way out but force-quitting.
        if(mounted) {
          setState(() {
            _configFailed = true;
            _retrying = false;
          });
        }
        return;
      }
      if(mounted) setState(() => _retrying = false);
      if(isSuccess) {
        Provider.of<SplashController>(Get.context!, listen: false).getBusinessPagesList('default');
        Provider.of<SplashController>(Get.context!, listen: false).initShippingTypeList(Get.context!,'');
        Timer(const Duration(seconds: 1), () async {
          final config = Provider.of<SplashController>(Get.context!, listen: false).configModel;
          SellerAppVersionControl? appVersion = Provider.of<SplashController>(Get.context!, listen: false).configModel?.sellerAppVersionControl;
          String? minimumVersion = '0';

          if(Platform.isAndroid) {
            minimumVersion =  appVersion?.forAndroid?.version ?? '0';
          } else if(Platform.isIOS) {
            minimumVersion = appVersion?.forIos?.version ?? '0';
          }


          if(AppVersion.isUpdateRequired(minimumVersion)) {
            Navigator.of(Get.context!).pushReplacement(MaterialPageRoute(builder: (_) => const UpdateScreen()));
          } else if(config?.maintenanceModeData?.maintenanceStatus == 1 && config?.maintenanceModeData?.selectedMaintenanceSystem?.vendorApp == 1) {
            Navigator.of(Get.context!).pushReplacement(MaterialPageRoute(
              builder: (_) => const MaintenanceScreen(),
              settings: const RouteSettings(name: 'MaintenanceScreen'),
            ));
          } else {
            // The screen a notification opens is NotificationScreens' to say, and it is the same list the opener used while the app is
            // running asks (K-11). There were two lists here and they disagreed: this one switched on the type alone, so an order notice
            // carrying an order number and no type -- which is most of them -- opened the notification LIST when it started the app and the
            // ORDER when the app was already running, and an order notice with a type and no number crashed on `int.parse` of the word
            // "null". A notification that was tapped and names no screen this build knows still opens the list it is in, as it always did:
            // the seller tapped something and has to land somewhere about it.
            final AuthController auth = Provider.of<AuthController>(context, listen: false);
            final bool signedIn = auth.isLoggedIn();
            final Widget? fromNotification = widget.body != null && signedIn
                ? (NotificationScreens.of(widget.body, signedIn: true) ?? const NotificationScreen())
                : null;

            if (fromNotification != null && await MyNotification.marketIsReady(widget.body)) {
              Navigator.of(Get.context!).pushReplacement(MaterialPageRoute(builder: (BuildContext context) => fromNotification));
            } else if (signedIn) {
              if (!mounted) {
                return;
              }

              await auth.updateToken(context);
              Navigator.of(Get.context!).pushReplacement(MaterialPageRoute(builder: (BuildContext context) => const DashboardScreen()));
            } else {
              // A deep link or a push lands here too when there is no session: every one of those screens fetches on open, so following it
              // signed out meant a 401 and a bounce, rather than a login screen.
              Navigator.of(Get.context!).pushReplacement(MaterialPageRoute(builder: (BuildContext context) => const AuthScreen()));
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Provider.of<ThemeController>(context).darkTheme ? Colors.black : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'logo',
                child: Image.asset(
                  width: 0.8 * MediaQuery.of(context).size.width,
                  Images.logoWithAppName,
                  fit: BoxFit.cover,
                ),
              ),
              if (_configFailed) Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeExtraLarge,
                  vertical: Dimensions.paddingSizeLarge,
                ),
                child: Column(children: [
                  Icon(Icons.wifi_off_rounded, size: 44, color: Theme.of(context).hintColor),
                  const SizedBox(height: Dimensions.paddingSize),
                  Text(
                    getTranslated('connection_failed_title', context) ?? '',
                    textAlign: TextAlign.center,
                    style: titilliumSemiBold.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Text(
                    getTranslated('connection_failed_message', context) ?? '',
                    textAlign: TextAlign.center,
                    style: robotoRegular.copyWith(
                      color: Theme.of(context).hintColor,
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  ElevatedButton.icon(
                    onPressed: _retrying ? null : initCall,
                    icon: const Icon(Icons.refresh_rounded, size: Dimensions.iconSizeDefault),
                    label: Text(getTranslated('retry', context) ?? ''),
                  ),
                ]),
              ) else if (_retrying) Padding(
                padding: const EdgeInsets.only(top: Dimensions.paddingSizeLarge),
                child: SizedBox(
                  height: 22, width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        )
    );
  }

  int compareVersions(String version1, String version2) {
    List<String> v1Components = version1.split('.');
    List<String> v2Components = version2.split('.');

    int maxLength = v1Components.length > v2Components.length
        ? v1Components.length
        : v2Components.length;

    for (int i = 0; i < maxLength; i++) {
      int v1Part = i < v1Components.length ? int.tryParse(v1Components[i]) ?? 0 : 0;
      int v2Part = i < v2Components.length ? int.tryParse(v2Components[i]) ?? 0 : 0;

      if (v1Part > v2Part) return 1;
      if (v1Part < v2Part) return -1;
    }

    return 0;
  }


}
