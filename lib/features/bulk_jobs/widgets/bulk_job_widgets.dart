import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_image_widget.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/models/bulk_job_models.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/helper/price_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The pieces the bulk screens are built from.

/// What became of a job, in one word and one colour.
///
/// `partial` gets its own colour rather than being folded into success or
/// failure, because it is neither: the run finished, most of it landed, and the
/// seller has a short list to deal with.
class BulkJobStatusChip extends StatelessWidget {
  final String status;
  const BulkJobStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color = colorFor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeExtraSmall),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(Dimensions.radiusPill),
      ),
      child: Text(getTranslated('bulk_status_$status', context) ?? status,
          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
    );
  }

  static Color colorFor(BuildContext context, String status) => switch (status) {
        'completed' => Colors.green.shade600,
        'partial' => Colors.orange.shade700,
        'failed' => Theme.of(context).colorScheme.error,
        _ => Theme.of(context).primaryColor,
      };
}

/// How far a job got, as a bar and as counts.
///
/// The counts are shown next to the bar rather than instead of it, because
/// "380 of 400" is the number a seller acts on and a percentage is not.
class BulkJobProgressWidget extends StatelessWidget {
  final BulkJobModel job;
  const BulkJobProgressWidget({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Dimensions.radiusPill),
        child: LinearProgressIndicator(
          value: job.total < 1 ? 1 : job.progress / 100,
          minHeight: 6,
          backgroundColor: Theme.of(context).hintColor.withValues(alpha: .15),
          valueColor: AlwaysStoppedAnimation<Color>(BulkJobStatusChip.colorFor(context, job.status)),
        ),
      ),
      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
      Row(children: [
        Text('${job.succeeded} ${getTranslated('bulk_changed', context) ?? ''}',
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall, color: Colors.green.shade700)),
        if (job.failed > 0) ...[
          Text('  ·  ', style: robotoRegular.copyWith(color: Theme.of(context).hintColor)),
          Text('${job.failed} ${getTranslated('bulk_not_changed', context) ?? ''}',
              style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).colorScheme.error)),
        ],
        const Spacer(),
        Text('${job.processed}/${job.total}',
            style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
      ]),
    ]);
  }
}

/// One product in the picker, with its current price and stock.
///
/// Both numbers are shown because both operations act on this one list: a
/// seller choosing products for a price change still wants to see the stock
/// they are about to leave alone.
class BulkProductTileWidget extends StatelessWidget {
  final Product product;
  final bool isSelected;
  final VoidCallback onTap;
  const BulkProductTileWidget({super.key, required this.product, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
        child: Row(children: [
          Checkbox(value: isSelected, onChanged: (_) => onTap()),
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            child: CustomImageWidget(
              image: product.thumbnailFullUrl?.path ?? '',
              height: 40, width: 40,
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name ?? '',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
              const SizedBox(height: 2),
              Text('${PriceConverter.convertPrice(context, product.unitPrice ?? 0)}'
                  '  ·  ${getTranslated('stock', context) ?? ''} ${product.currentStock ?? 0}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
            ]),
          ),
        ]),
      ),
    );
  }
}
