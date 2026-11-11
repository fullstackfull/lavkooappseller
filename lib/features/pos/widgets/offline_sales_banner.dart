import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/glass/glass_container.dart';
import 'package:syriacosmeticsmanger/features/pos/controllers/offline_sales_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/theme/app_glass.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Shows how many sales are waiting to reach the server, with a manual retry.
///
/// Without it an outage is invisible to the cashier: they would have no way to
/// know whether a sale was recorded, which is exactly the uncertainty that made
/// the old crash-on-failure behaviour so costly.
class OfflineSalesBanner extends StatelessWidget {
  const OfflineSalesBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineSalesController>(
      builder: (context, offline, _) {
        if (!offline.hasPending && offline.isOnline) return const SizedBox.shrink();

        final AppGlass glass = AppGlass.of(context);
        final bool syncing = offline.isSyncing;
        final Color tone = offline.hasPending
            ? glass.warningGradient.last
            : glass.dangerGradient.last;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSize, Dimensions.paddingSizeSmall, Dimensions.paddingSize, 0),
          child: GlassContainer(
            enableBlur: false,
            elevation: GlassElevation.soft,
            tint: tone.withValues(alpha: 0.12),
            border: Border.all(color: tone.withValues(alpha: 0.35)),
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSize, vertical: Dimensions.paddingSizeSmall),
            child: Row(children: [
              Icon(
                offline.isOnline ? Icons.cloud_upload_rounded : Icons.cloud_off_rounded,
                color: tone,
                size: Dimensions.iconSizeMedium,
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: Text(
                  offline.hasPending
                      ? '${getTranslated('unsynced_sales', context)}: ${offline.pendingCount}'
                      : getTranslated('working_offline', context) ?? '',
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              if (offline.hasPending)
                syncing
                    ? SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: tone),
                      )
                    : TextButton(
                        onPressed: offline.isOnline ? () => offline.syncPending() : null,
                        style: TextButton.styleFrom(
                          foregroundColor: tone,
                          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          getTranslated('retry', context) ?? '',
                          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
                        ),
                      ),
            ]),
          ),
        );
      },
    );
  }
}
