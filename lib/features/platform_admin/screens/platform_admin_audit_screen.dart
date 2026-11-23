import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_failure.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_state_widgets.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_audit_tile.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// What the platform admin API did and who asked, newest first, a page at a time.
///
/// The platform owner reads every line; a restricted viewer only their own. The
/// server decides which, and the screen draws what it was given.
class PlatformAdminAuditScreen extends StatelessWidget {
  const PlatformAdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformAdminController>(
      builder: (BuildContext context, PlatformAdminController controller, _) {
        final List<PlatformAuditLine>? lines = controller.auditLines;
        final PlatformAdminFailure? failure = controller.auditFailure;

        return RefreshIndicator(
          onRefresh: () => controller.loadAuditLog(force: true),
          color: Theme.of(context).cardColor,
          backgroundColor: Theme.of(context).primaryColor,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            children: [
              if (failure != null && lines != null) ...[
                PlatformAdminFailureBanner(failure: failure),
                const SizedBox(height: Dimensions.paddingSizeSmall),
              ],
              if (lines == null && failure != null)
                SizedBox(
                    height: 320,
                    child:
                        PlatformAdminFailureView(failure: failure, onRetry: () => controller.loadAuditLog(force: true)))
              else if (lines == null)
                const SizedBox(height: 320, child: PlatformAdminLoader())
              else if (lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                  child: Text(
                    getTranslated('platform_admin_audit_empty', context)!,
                    textAlign: TextAlign.center,
                    style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
                  ),
                )
              else ...[
                for (final PlatformAuditLine line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                    child: PlatformAuditTile(line: line, me: controller.profile?.adminId),
                  ),
                if (controller.auditHasMore)
                  Center(
                    child: controller.isLoadingMoreAudit
                        ? const Padding(
                            padding: EdgeInsets.all(Dimensions.paddingSizeDefault),
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(
                            onPressed: controller.loadMoreAuditLog,
                            child: Text(getTranslated('platform_admin_load_more', context)!)),
                  ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
              ],
            ],
          ),
        );
      },
    );
  }
}
