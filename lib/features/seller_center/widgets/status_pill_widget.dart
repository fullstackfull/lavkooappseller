import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// A KYC or payout status as a coloured pill, so the same state always reads
/// the same colour wherever it appears.
class StatusPillWidget extends StatelessWidget {
  final String status;
  const StatusPillWidget({super.key, required this.status});

  static Color colorOf(BuildContext context, String status) {
    switch (status) {
      case 'verified':
      case 'approved':
      case 'paid':
      case 'not_required':
        return Theme.of(context).colorScheme.onTertiaryContainer;
      case 'pending':
      case 'requested':
      case 'under_review':
      case 'processing':
        return Theme.of(context).colorScheme.tertiary;
      case 'rejected':
      case 'failed':
      case 'expired':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).hintColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = colorOf(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(Dimensions.radiusPill),
        border: Border.all(color: color.withValues(alpha: .5), width: .8),
      ),
      child: Text(getTranslated(status, context) ?? status,
          style: robotoMedium.copyWith(color: color, fontSize: Dimensions.fontSizeSmall)),
    );
  }
}
