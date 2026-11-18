import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/platform_admin_config.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_shell_screen.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The one way into the platform admin shell: a discreet text button on the
/// seller's login screen, there only in a build that has the shell switched on.
///
/// Switched off it is nothing: no widget, no route and no controller, so the
/// login screen is exactly what it was.
class PlatformAdminEntryButton extends StatelessWidget {
  final bool enabled;

  /// Makes the controller of one opening of the shell.
  final PlatformAdminController Function() createController;

  const PlatformAdminEntryButton({
    super.key,
    this.enabled = PlatformAdminConfig.enabled,
    this.createController = _controllerFromLocator,
  });

  static PlatformAdminController _controllerFromLocator() => GetIt.instance<PlatformAdminController>();

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    return Center(
      child: TextButton(
        onPressed: () => _open(context),
        child: Text(
          getTranslated('platform_admin_sign_in_entry', context)!,
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<PlatformAdminController>(
          create: (_) => createController(),
          child: const PlatformAdminShellScreen(),
        ),
      ),
    );
  }
}
