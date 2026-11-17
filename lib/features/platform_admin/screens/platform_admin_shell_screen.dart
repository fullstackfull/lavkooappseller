import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_home_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_second_factor_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_sign_in_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_state_widgets.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';

/// The root of everything the platform admin sees.
///
/// It is its own route, opened from the seller's login screen and left with its
/// back: while it is open the seller app's tabs, menus and screens are not part
/// of it, and the seller's session, if it ever has one, is not read here. Which
/// screen is shown follows the state of the platform session alone: looking for
/// the session of an earlier launch, the sign-in, its second step, or the signed-in screens. A
/// session the server ends puts the admin back at the sign-in, from wherever
/// they were.
class PlatformAdminShellScreen extends StatefulWidget {
  const PlatformAdminShellScreen({super.key});

  @override
  State<PlatformAdminShellScreen> createState() => _PlatformAdminShellScreenState();
}

class _PlatformAdminShellScreenState extends State<PlatformAdminShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Provider.of<PlatformAdminController>(context, listen: false).restoreSession(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformAdminController>(
      builder: (BuildContext context, PlatformAdminController controller, _) => switch (controller.stage) {
        PlatformAdminStage.restoring => Scaffold(
            appBar: CustomAppBarWidget(title: getTranslated('platform_admin_title', context)),
            body: const PlatformAdminLoader(),
          ),
        PlatformAdminStage.restoreFailed => Scaffold(
            appBar: CustomAppBarWidget(title: getTranslated('platform_admin_title', context)),
            body: PlatformAdminFailureView(failure: controller.restoreFailure!, onRetry: controller.restoreSession),
          ),
        PlatformAdminStage.signedOut || PlatformAdminStage.signingIn => const PlatformAdminSignInScreen(),
        PlatformAdminStage.secondFactor => const PlatformAdminSecondFactorScreen(),
        PlatformAdminStage.signedIn => const PlatformAdminHomeScreen(),
      },
    );
  }
}
