import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:syriacosmeticsmanger/features/chat/controllers/chat_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/auth/screens/login_screen.dart';
import 'package:syriacosmeticsmanger/features/dashboard/screens/dashboard_screen.dart';
import 'package:syriacosmeticsmanger/features/maintenance/maintenance_screen.dart';
import 'package:syriacosmeticsmanger/features/product/screens/product_list_screen.dart';
import 'package:syriacosmeticsmanger/features/refund/domain/models/refund_model.dart';
import 'package:syriacosmeticsmanger/features/refund/screens/refund_details_screen.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/features/splash/domain/models/config_model.dart';
import 'package:syriacosmeticsmanger/features/wallet/screens/wallet_screen.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';
import 'package:syriacosmeticsmanger/features/chat/screens/inbox_screen.dart';
import 'package:syriacosmeticsmanger/features/notification/screens/notification_screen.dart';
import 'package:syriacosmeticsmanger/features/order_details/screens/order_details_screen.dart';

import '../firebase_options.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';

class MyNotification {

  static Future<void> initialize(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize = const AndroidInitializationSettings('notification_icon');
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationsSettings = InitializationSettings(android: androidInitialize, iOS: iOSInitialize);
    flutterLocalNotificationsPlugin.initialize(settings: initializationsSettings, onDidReceiveNotificationResponse: (NotificationResponse data) async {


      try{
        NotificationBody payload;
        if(data.payload != null && data.payload!.isNotEmpty) {
          payload = NotificationBody.fromJson(jsonDecode(data.payload!));
          if(payload.type == 'chatting'){
            Get.navigator!.push(MaterialPageRoute(builder: (context) => InboxScreen(fromNotification: true, initIndex: payload.messageKey ==  'message_from_delivery_man' ? 1 : 0)));
          } else if(payload.type == 'Theme'){
            Get.navigator!.push(MaterialPageRoute(builder: (context) => const NotificationScreen( )));
          } else if(payload.orderId != null && payload.type != 'refund'){
            Get.navigator!.push(MaterialPageRoute(builder: (context) => OrderDetailsScreen(orderId: payload.orderId, fromNotification: true)));
          } else if(payload.type  == 'wallet_withdraw'){
            Get.navigator!.push(MaterialPageRoute(builder: (context) => const WalletScreen(fromNotification: true)));
          } else if(payload.type == 'product_request_approved_message'){
            Get.navigator!.push(MaterialPageRoute(builder: (context) => const ProductListMenuScreen(fromNotification: true)));
          }else if(payload.type == 'refund'){
            Get.navigator!.push(MaterialPageRoute(builder: (context) => RefundDetailsScreen(fromNotification: true, refundModel: RefundModel(id: payload.refundId), orderDetailsId: payload.orderDetailsId)));
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
      return;
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('======================================');
      debugPrint('FCM FOREGROUND MESSAGE');
      debugPrint('Notification: ${message.notification?.toMap()}');
      debugPrint('Data: ${message.data}');
      debugPrint('======================================');

      // A chat push while the app is open now refreshes the conversation and
      // the inbox instead of only raising a banner.
      if (message.data['type'] == 'chatting') {
        final BuildContext? chatContext = Get.context;
        // The device stays registered for pushes after a sign-out, so a chat
        // arriving while the seller sits on the login screen used to fire two
        // authenticated requests with no credential — two 401s, and a session
        // wipe on top of the screen they were already looking at.
        if (chatContext != null &&
            chatContext.mounted &&
            Provider.of<AuthController>(chatContext, listen: false).isLoggedIn()) {
          final int? fromUserId = int.tryParse(message.data['customer_id']?.toString() ??
              message.data['delivery_man_id']?.toString() ?? '');
          try {
            await Provider.of<ChatController>(chatContext, listen: false)
                .onIncomingChatMessage(chatContext, fromUserId: fromUserId);
          } catch (e) {
            debugPrint('Chat refresh from push failed: $e');
          }
        }
      }

      if (message.data['type'] == 'maintenance_mode') {
        final SplashController splashProvider =
        Provider.of<SplashController>(
          Get.context!,
          listen: false,
        );

        await splashProvider.initConfig();

        final ConfigModel? config =
            splashProvider.configModel;

        final bool isMaintenanceRoute =
        splashProvider.isMaintenanceModeScreen();

        if (config?.maintenanceModeData?.maintenanceStatus == 1 &&
            config?.maintenanceModeData?.selectedMaintenanceSystem?.vendorApp == 1) {
          Navigator.of(Get.context!).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const MaintenanceScreen(),
              settings: const RouteSettings(
                name: 'MaintenanceScreen',
              ),
            ),
          );
        } else if (isMaintenanceRoute) {
          final AuthController authController =
          Provider.of<AuthController>(
            Get.context!,
            listen: false,
          );

          if (authController.isLoggedIn()) {
            Navigator.of(Get.context!).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const DashboardScreen(),
              ),
            );
          } else {
            Navigator.of(Get.context!).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              ),
            );
          }
        }

        return;
      }

      // Show notification when app is OPEN
      await showNotification(
        message,
        flutterLocalNotificationsPlugin,
        false,
      );
    });


    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message)  async {
      if (kDebugMode) {
        debugPrint("onOpenApp: ${message.notification!.title}/${message.toMap()}/${message.notification!.titleLocKey}");
      }
      NotificationBody? payload;
      if(message.data.isNotEmpty) {
        payload = NotificationBody.fromJson(message.data);
      }
      if(message.notification!.title!.contains('chatting')) {
        Get.navigator!.push(MaterialPageRoute(builder: (context) => InboxScreen(fromNotification: true, initIndex: payload?.messageKey ==  'message_from_delivery_man' ? 1 : 0)));

      } else if(message.notification!.title!.contains('Theme')){
        Get.navigator!.push(MaterialPageRoute(builder: (context) => const NotificationScreen( )));
      } else if (message.notification!.title!.contains('Order') && payload != null && payload.orderId != null && payload.type != 'refund') {
        Get.navigator!.push(
          MaterialPageRoute(builder: (context) => OrderDetailsScreen(orderId: int.parse(payload!.orderId.toString()), fromNotification: true)));
      } else if(payload?.type == 'wallet_withdraw'){
        Get.navigator!.push(MaterialPageRoute(builder: (context) => const WalletScreen(fromNotification: true)));
      } else if(payload?.type == 'product_request_approved_message'){
        Get.navigator!.push(MaterialPageRoute(builder: (context) => const ProductListMenuScreen(fromNotification: true)));
      }else if(payload?.type == 'refund'){
        Get.navigator!.push(MaterialPageRoute(builder: (context) => RefundDetailsScreen(fromNotification: true, refundModel: RefundModel(id: payload?.refundId), orderDetailsId: payload?.orderDetailsId)));
      }
      try{
        if(message.notification!.titleLocKey != null && message.notification!.titleLocKey!.isNotEmpty) {
          Get.navigator!.push(
              MaterialPageRoute(builder: (context) => OrderDetailsScreen(orderId: int.parse(message.notification!.titleLocKey!), fromNotification: true,)));
        }
      }catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }


      if(message.data['type'] == 'maintenance_mode') {
        final SplashController splashProvider = Provider.of<SplashController>(Get.context!,listen: false);
        await splashProvider.initConfig();

        ConfigModel? config = Provider.of<SplashController>(Get.context!,listen: false).configModel;

        bool isMaintenanceRoute = Provider.of<SplashController>(Get.context!,listen: false).isMaintenanceModeScreen();

        debugPrint("--------(NOTIFICATION HELPER)-----------${Provider.of<SplashController>(Get.context!, listen: false).isMaintenanceModeScreen()}-------");

        if(config?.maintenanceModeData?.maintenanceStatus == 1 && (config?.maintenanceModeData?.selectedMaintenanceSystem?.vendorApp == 1)) {
          Navigator.of(Get.context!).pushReplacement(MaterialPageRoute(
            builder: (_) => const MaintenanceScreen(),
            settings: const RouteSettings(name: 'MaintenanceScreen'),
          ));
        }else if (isMaintenanceRoute) {
          final AuthController authController = Provider.of<AuthController>(Get.context!, listen: false);
          if(authController.isLoggedIn()) {
            Navigator.of(Get.context!).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
          } else {
            Navigator.of(Get.context!).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
          }
        }
      }

    });
  }

  static Future<void> showNotification(
      RemoteMessage message,
      FlutterLocalNotificationsPlugin fln,
      bool data,
      ) async {
    try {
      final String title =
          message.notification?.title ??
              message.data['title']?.toString() ??
              '';

      final String body =
          message.notification?.body ??
              message.data['body']?.toString() ??
              '';

      debugPrint('Notification title: $title');
      debugPrint('Notification body: $body');

      if (title.isEmpty && body.isEmpty) {
        debugPrint('FCM: notification has no title or body');
        return;
      }

      final dynamic imageValue = message.data['image'];

      final String? image =
      imageValue != null &&
          imageValue.toString().isNotEmpty
          ? (imageValue.toString().startsWith('http')
          ? imageValue.toString()
          : '${AppConstants.baseUrl}/storage/app/public/notification/$imageValue')
          : null;

      if (image != null && image.isNotEmpty) {
        try {
          await showBigPictureNotificationHiddenLargeIcon(
            title,
            body,
            message.data,
            image,
            fln,
          );
          return;
        } catch (e) {
          debugPrint('Notification image error: $e');
        }
      }

      await showBigTextNotification(
        title,
        body,
        message.data,
        fln,
      );
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }


  static Future<void> showBigTextNotification(String? title, String body, Map<String, dynamic> data, FlutterLocalNotificationsPlugin fln) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body, htmlFormatBigText: true,
      contentTitle: title, htmlFormatContentTitle: true,
    );
    AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'notifications',
        'Notifications', importance: Importance.max,
      styleInformation: bigTextStyleInformation, priority: Priority.max, playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification'),
    );
    NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show( id: 0, title: title, body: body, notificationDetails: platformChannelSpecifics, payload: jsonEncode(data));
  }

  static Future<void> showBigPictureNotificationHiddenLargeIcon(String? title, String? body, Map<String, dynamic> data, String image, FlutterLocalNotificationsPlugin fln) async {
    final String largeIconPath = await _downloadAndSaveFile(image, 'largeIcon');
    final String bigPicturePath = await _downloadAndSaveFile(image, 'bigPicture');
    final BigPictureStyleInformation bigPictureStyleInformation = BigPictureStyleInformation(
      FilePathAndroidBitmap(bigPicturePath), hideExpandedLargeIcon: true,
      contentTitle: title, htmlFormatContentTitle: true,
      summaryText: body, htmlFormatSummaryText: true,
    );
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'notifications',
      'Notifications',
      largeIcon: FilePathAndroidBitmap(largeIconPath), priority: Priority.max, playSound: true,
      styleInformation: bigPictureStyleInformation, importance: Importance.max,
      sound: const RawResourceAndroidNotificationSound('notification'),
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(id: 0, title: title, body: body, notificationDetails: platformChannelSpecifics, payload: jsonEncode(data));
  }

  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final Response response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
    final File file = File(filePath);
    await file.writeAsBytes(response.data);
    return filePath;
  }

}
@pragma('vm:entry-point')
Future<void> myBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    'FCM BACKGROUND: '
        '${message.notification?.title} / '
        '${message.notification?.body} / '
        '${message.data}',
  );
}
