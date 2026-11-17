import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_confirmation_dialog_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_state_widgets.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_session_tile.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The devices this admin is signed in on, and the way out of each.
///
/// Level 1 changes no business data: ending a session and signing out are the
/// only two things on the platform shell that are not a read.
class PlatformAdminSessionsScreen extends StatelessWidget {
  const PlatformAdminSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformAdminController>(
      builder: (BuildContext context, PlatformAdminController controller, _) {
        final List<PlatformSessionModel>? sessions = controller.sessions;
        final PlatformAdminFailure? failure = controller.sessionsFailure;

        return RefreshIndicator(
          onRefresh: () => controller.loadSessions(force: true),
          color: Theme.of(context).cardColor,
          backgroundColor: Theme.of(context).primaryColor,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            children: [
              _SignedInAs(name: controller.profile?.name ?? ''),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              if (failure != null && sessions != null) ...[
                PlatformAdminFailureBanner(failure: failure),
                const SizedBox(height: Dimensions.paddingSizeSmall),
              ],
              if (sessions == null && failure != null)
                SizedBox(
                  height: 280,
                  child:
                      PlatformAdminFailureView(failure: failure, onRetry: () => controller.loadSessions(force: true)),
                )
              else if (sessions == null)
                const SizedBox(height: 280, child: PlatformAdminLoader())
              else if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                  child: Text(
                    getTranslated('platform_admin_no_sessions', context)!,
                    textAlign: TextAlign.center,
                    style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
                  ),
                )
              else
                ...sessions.map(
                  (PlatformSessionModel session) => Padding(
                    padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                    child: PlatformSessionTile(
                      session: session,
                      isEnding: controller.endingSessionId == session.id,
                      onEnd:
                          controller.endingSessionId == null ? () => _confirmEnd(context, controller, session) : null,
                    ),
                  ),
                ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              CustomButtonWidget(
                borderRadius: 16,
                backgroundColor: Theme.of(context).colorScheme.error,
                btnTxt: getTranslated('logout', context),
                onTap: () => _signOut(context, controller),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(
                getTranslated('platform_admin_sign_out_here', context)!,
                textAlign: TextAlign.center,
                style:
                    robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmEnd(
      BuildContext context, PlatformAdminController controller, PlatformSessionModel session) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => CustomConfirmationDialogWidget(
        title: getTranslated('platform_admin_end_session', dialogContext)!,
        description: getTranslated('platform_admin_end_session_question', dialogContext)!,
        yesButtonText: getTranslated('confirm', dialogContext)!,
        noButtonText: getTranslated('cancel', dialogContext)!,
        onYesPressed: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final PlatformAdminFailure? failure = await controller.endSession(session.id);
    if (failure == null || !context.mounted) return;

    final bool alreadyOver = failure.kind == PlatformAdminFailureKind.sessionNotFound;
    showCustomSnackBarWidget(
      alreadyOver
          ? getTranslated('platform_admin_session_already_ended', context)
          : PlatformAdminTexts.failureTitle(context, failure),
      context,
      sanckBarType: alreadyOver ? SnackBarType.warning : SnackBarType.error,
    );
  }

  /// Over on this phone at once. The shell is left afterwards, if it is still the screen in front.
  Future<void> _signOut(BuildContext context, PlatformAdminController controller) async {
    final NavigatorState navigator = Navigator.of(context);
    final Route<dynamic>? shell = ModalRoute.of(context);

    await controller.signOut();

    if (shell?.isCurrent ?? false) navigator.pop();
  }
}

class _SignedInAs extends StatelessWidget {
  final String name;

  const _SignedInAs({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.verified_user_outlined, size: Dimensions.iconSizeMedium, color: Theme.of(context).primaryColor),
      const SizedBox(width: Dimensions.paddingSizeSmall),
      Expanded(
        child: Text(
          '${getTranslated('platform_admin_signed_in_as', context)!} $name',
          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault),
        ),
      ),
    ]);
  }
}
