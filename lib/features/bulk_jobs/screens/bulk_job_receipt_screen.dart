import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/controllers/bulk_job_controller.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/models/bulk_job_models.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/widgets/bulk_job_widgets.dart';
import 'package:syriacosmeticsmanger/features/reports/widgets/report_widgets.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// What the bulk change actually did.
///
/// The refused rows are the reason this screen exists. A seller who is told
/// "done" and finds out from a customer that a price never changed has been
/// misled by their own tools, so every row the job would not change is listed
/// with its reason, and the whole list downloads as a file for a catalogue too
/// large to work through on a phone.
class BulkJobReceiptScreen extends StatefulWidget {
  final int jobId;

  /// The job as it was already known, so the screen has something to show
  /// immediately instead of a spinner over a result the caller already has.
  final BulkJobModel? initialJob;

  const BulkJobReceiptScreen({super.key, required this.jobId, this.initialJob});

  @override
  State<BulkJobReceiptScreen> createState() => _BulkJobReceiptScreenState();
}

class _BulkJobReceiptScreenState extends State<BulkJobReceiptScreen> {
  @override
  void initState() {
    super.initState();
    // Always re-read: the caller's copy may predate the last rows, and the
    // failure list only comes back on the single-job endpoint.
    Provider.of<BulkJobController>(context, listen: false).getBulkJob(widget.jobId);
  }

  Future<void> _download(BulkJobController bulk) async {
    final String? path = await bulk.downloadFailures(widget.jobId);
    if (!mounted) return;

    showCustomSnackBarWidget(
      path != null
          ? '${getTranslated('saved_to', context) ?? ''} $path'
          : getTranslated('download_failed', context),
      context,
      sanckBarType: path != null ? SnackBarType.success : SnackBarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('bulk_result', context)),
      body: Consumer<BulkJobController>(
        builder: (context, bulk, _) {
          final BulkJobModel? job = bulk.job ?? widget.initialJob;

          if (job == null) {
            return Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)));
          }

          return RefreshIndicator(
            onRefresh: () => bulk.getBulkJob(widget.jobId).then((_) {}),
            color: Theme.of(context).cardColor,
            backgroundColor: Theme.of(context).primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                ReportCardWidget(children: [
                  Row(children: [
                    Expanded(
                      child: Text(getTranslated('bulk_type_${job.type}', context) ?? job.type,
                          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
                    ),
                    BulkJobStatusChip(status: job.status),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  BulkJobProgressWidget(job: job),
                  if (job.error != null && job.error!.isNotEmpty) ...[
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Text(getTranslated(job.error!, context) ?? job.error!,
                        style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ]),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                Row(children: [
                  ReportMetricWidget(title: 'bulk_selected', value: '${job.total}'),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  ReportMetricWidget(
                      title: 'bulk_changed', value: '${job.succeeded}',
                      valueColor: job.succeeded > 0 ? Colors.green.shade700 : null),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  ReportMetricWidget(
                      title: 'bulk_not_changed', value: '${job.failed}',
                      valueColor: job.failed > 0 ? Theme.of(context).colorScheme.error : null),
                ]),

                if (job.isRunning) ...[
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  Text(getTranslated('bulk_still_running', context) ?? '',
                      style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
                ],

                if (job.failures.isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  Row(children: [
                    Expanded(
                      child: Text(getTranslated('bulk_products_not_changed', context) ?? '',
                          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
                    ),
                    TextButton.icon(
                      onPressed: bulk.isExporting ? null : () => _download(bulk),
                      icon: bulk.isExporting
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.download_outlined, size: 18),
                      label: Text(getTranslated('download_csv', context) ?? ''),
                    ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  ...job.failures.map((failure) => ReportCardWidget(
                        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                        children: [
                          Text(failure.name ?? '#${failure.productId}',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                          const SizedBox(height: 2),
                          Text(failure.message,
                              style: robotoRegular.copyWith(
                                  fontSize: Dimensions.fontSizeExtraSmall,
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                      )).expand((widget) => [widget, const SizedBox(height: Dimensions.paddingSizeExtraSmall)]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
