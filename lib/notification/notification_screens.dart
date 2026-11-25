import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/chat/screens/inbox_screen.dart';
import 'package:syriacosmeticsmanger/features/notification/screens/notification_screen.dart';
import 'package:syriacosmeticsmanger/features/order_details/screens/order_details_screen.dart';
import 'package:syriacosmeticsmanger/features/product/screens/product_list_screen.dart';
import 'package:syriacosmeticsmanger/features/refund/domain/models/refund_model.dart';
import 'package:syriacosmeticsmanger/features/refund/screens/refund_details_screen.dart';
import 'package:syriacosmeticsmanger/features/wallet/screens/wallet_screen.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';
import 'package:syriacosmeticsmanger/notification/notification_route.dart';

/// The screen a notification opens, built from the decision [NotificationRoute] made (K-11).
///
/// There were two of these and they disagreed. The opener used by a tap and by an open-from-background asked [NotificationRoute]; the splash,
/// which opens a notification that STARTED the app, had a switch of its own on the type alone. So an order notice that carries an order number
/// and no type -- which is most of them -- opened the order when the app was already running and the notification LIST when it was not, and an
/// order notice with a type and no number crashed the splash on `int.parse` of the word "null".
///
/// One list of screens, asked by both, is the only way those two stay in step: a screen added here is reached however the app was opened, and a
/// screen that cannot be reached one way cannot be reached the other.
class NotificationScreens {
  const NotificationScreens._();

  /// The screen [payload] opens, or null when it opens none -- including for a seller who is signed out, who is taken nowhere.
  static Widget? of(NotificationBody? payload, {required bool signedIn, String? legacyOrderKey}) => forTarget(
        NotificationRoute.targetOf(payload, signedIn: signedIn, legacyOrderKey: legacyOrderKey),
        payload,
        legacyOrderKey: legacyOrderKey,
      );

  /// The screen of one target. Every screen a notification can reach is named here and nowhere else.
  static Widget? forTarget(NotificationTarget target, NotificationBody? payload, {String? legacyOrderKey}) => switch (target) {
        NotificationTarget.chat => InboxScreen(fromNotification: true, initIndex: payload?.messageKey == 'message_from_delivery_man' ? 1 : 0),
        NotificationTarget.themeNotifications => const NotificationScreen(),
        NotificationTarget.order =>
          OrderDetailsScreen(orderId: NotificationRoute.orderIdOf(payload, legacyOrderKey: legacyOrderKey), fromNotification: true),
        NotificationTarget.wallet => const WalletScreen(fromNotification: true),
        NotificationTarget.productRequests => const ProductListMenuScreen(fromNotification: true),
        NotificationTarget.refund => RefundDetailsScreen(
            fromNotification: true,
            refundModel: RefundModel(id: payload?.refundId),
            orderDetailsId: payload?.orderDetailsId,
          ),
        NotificationTarget.none => null,
      };
}
