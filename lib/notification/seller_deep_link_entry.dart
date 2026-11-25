import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';
import 'package:syriacosmeticsmanger/notification/seller_deep_link.dart';

/// Where a `lavkooseller://` link comes in (K-11).
///
/// This is transport and nothing else: the operating system hands over a [Uri], [SellerDeepLink] says what payload it stands for, and the
/// opener the app already uses for a push opens it. Every decision worth testing lives in those two, which is why this file holds no `if`
/// about where a link should go.
///
/// **A cold start takes the link only when no push was tapped.** A push that opened the app was tapped a moment ago by the person holding the
/// phone, and a link that was waiting may have been followed long before; the thing the seller just did wins. That rule is in `main`, where
/// both are read.
///
/// Both entry points take the link source as an argument -- a `Future` and a `Stream` of plain [Uri]s rather than the plugin -- so the
/// plumbing can be driven by a test with no platform behind it. Left out, they come from the plugin, which is what the app does.
///
/// Everything here is best effort. The plugin reaches platform code, and on a platform that has none -- a test, a desktop build -- asking for
/// the initial link throws. A link that cannot be read must cost the app nothing: the seller opened their shop, and a failure here would be a
/// cold start that ends in a crash report instead of the dashboard.
class SellerDeepLinkEntry {
  const SellerDeepLinkEntry._();

  static StreamSubscription<Uri>? _subscription;

  /// The payload of the link that started the app, or null when none did, none was ours, or the link could not be read at all.
  static Future<NotificationBody?> initialPayload({Future<Uri?>? link}) async {
    try {
      return SellerDeepLink.payloadOf(await (link ?? AppLinks().getInitialLink()));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Initial deep link error: $error');
      }

      return null;
    }
  }

  /// Watches for a link that arrives while the app is running and opens what it names.
  ///
  /// [onPayload] is the opener -- `MyNotification.open` in the app -- passed in rather than imported, so the one decision about where a
  /// notification opens stays in one place and this file can be read on its own.
  static void listen({required void Function(NotificationBody payload) onPayload, Stream<Uri>? links}) {
    stopListening();

    try {
      _subscription = (links ?? AppLinks().uriLinkStream).listen(
        (Uri link) {
          final NotificationBody? payload = SellerDeepLink.payloadOf(link);

          if (payload != null) {
            onPayload(payload);
          }
        },
        // A stream that fails must not take the app down with it: the seller is working, and a malformed link is not their problem.
        onError: (Object error) {
          if (kDebugMode) {
            debugPrint('Deep link stream error: $error');
          }
        },
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Deep link listen error: $error');
      }
    }
  }

  /// Stops watching. Called before taking up a new source, so two subscriptions can never open one link twice.
  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
