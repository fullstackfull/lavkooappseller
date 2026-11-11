import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Application-wide handles that used to live in `main.dart`.
///
/// Keeping them here means controllers, services and repositories no longer
/// have to import the app entry point (which pulls in every feature module)
/// just to reach the navigator or show a notification.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class Get {
  const Get._();

  /// The navigator's context, or null before the first frame / after teardown.
  /// Always null-check: dereferencing this with `!` crashes whenever an async
  /// callback resolves while no navigator is mounted.
  static BuildContext? get context => navigatorKey.currentContext;

  static NavigatorState? get navigator => navigatorKey.currentState;
}
