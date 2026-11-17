import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// One line of what the platform admin API did, and who asked.
///
/// What it shows is what the server wrote and the app can say without guessing:
/// the action, when, who, the market it was about, the status it was answered
/// with, the name of the device that signed in, and the address and the program
/// the request came from.
class PlatformAuditTile extends StatelessWidget {
  final PlatformAuditLine line;

  /// The signed-in admin's id, to tell their own lines from another admin's.
  final int? me;

  const PlatformAuditTile({super.key, required this.line, required this.me});

  @override
  Widget build(BuildContext context) {
    final DateTime? createdAt = line.createdAt;
    final String? market = line.market;
    final int? status = line.statusCode;
    final String? device = line.deviceName;
    final String? ip = line.ip;
    final String? userAgent = line.userAgent;
    final List<String> origin = <String>[if (ip != null) ip, if (userAgent != null) userAgent];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: .15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(PlatformAdminTexts.auditAction(context, line.action),
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
        const SizedBox(height: 2),
        Text(
          [
            if (createdAt != null) PlatformAdminTexts.moment(createdAt),
            PlatformAdminTexts.auditActor(context, line, me: me)
          ].join(' · '),
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
        ),
        if (market != null || status != null) ...[
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Wrap(spacing: Dimensions.paddingSizeExtraSmall, runSpacing: Dimensions.paddingSizeExtraSmall, children: [
            if (market != null)
              _tag(context, PlatformAdminTexts.marketName(context, market), Theme.of(context).primaryColor),
            if (status != null)
              _tag(context, '${getTranslated('platform_admin_audit_status', context)!} $status',
                  _statusColor(context, status)),
          ]),
        ],
        if (device != null) _detail(context, '${getTranslated('platform_admin_audit_device', context)!}: $device'),
        if (origin.isNotEmpty) _detail(context, origin.join(' · ')),
      ]),
    );
  }

  /// A refusal is told from an answer by its colour and by the number beside it.
  Color _statusColor(BuildContext context, int status) =>
      status >= 400 ? Theme.of(context).colorScheme.error : Colors.green.shade700;

  Widget _detail(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(text,
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
      );

  Widget _tag(BuildContext context, String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeOrder),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(Dimensions.radiusPill)),
        child: Text(label, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
      );
}
