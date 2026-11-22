import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';

/// Signs out of the platform admin from a screen of the shell: over on this phone at once, whatever the server says, and
/// the shell is left afterwards if it is still the screen in front. The one place that does it, for every screen that offers it.
Future<void> signOutOfPlatformAdmin(BuildContext context, PlatformAdminController controller) async {
  final NavigatorState navigator = Navigator.of(context);
  final Route<dynamic>? shell = ModalRoute.of(context);

  await controller.signOut();

  if (shell?.isCurrent ?? false) navigator.pop();
}
