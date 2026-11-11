import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/no_data_screen.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/controllers/bulk_job_controller.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/models/bulk_job_models.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/screens/bulk_edit_screen.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/screens/bulk_job_receipt_screen.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/widgets/bulk_job_widgets.dart';
import 'package:syriacosmeticsmanger/features/reports/widgets/report_widgets.dart';
import 'package:syriacosmeticsmanger/helper/date_converter.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Every bulk change this shop has run.
///
/// Kept as a list rather than shown once and forgotten, because the receipt is
/// what makes a partial result workable: a seller comes back to the job from a
/// week ago to see which twenty products still need attention.
class BulkJobsScreen extends StatefulWidget {
  const BulkJobsScreen({super.key});

  @override
  State<BulkJobsScreen> createState() => _BulkJobsScreenState();
}

class _BulkJobsScreenState extends State<BulkJobsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Provider.of<BulkJobController>(context, listen: false).getBulkJobs();
    });
  }

  void _startNew() {
    // Held before the push rather than read after it: the list refreshes when the
    // edit screen closes, and by then this context may be gone.
    final BulkJobController bulk = Provider.of<BulkJobController>(context, listen: false);
    bulk.clearSelection();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BulkEditScreen()))
        .then((_) => bulk.getBulkJobs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('bulk_operations', context)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNew,
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.edit_note, color: Colors.white),
        label: Text(getTranslated('bulk_new_change', context) ?? '',
            style: robotoMedium.copyWith(color: Colors.white)),
      ),
      body: Consumer<BulkJobController>(
        builder: (context, bulk, _) {
          final List<BulkJobModel> jobs = bulk.jobList?.jobs ?? const <BulkJobModel>[];

          return RefreshIndicator(
            onRefresh: () => bulk.getBulkJobs(),
            color: Theme.of(context).cardColor,
            backgroundColor: Theme.of(context).primaryColor,
            child: jobs.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * .7,
                      child: Center(child: bulk.isLoadingJobs
                          ? CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))
                          : const NoDataScreen()),
                    ),
                  ])
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault,
                        Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 80),
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Dimensions.paddingSizeSmall),
                    itemBuilder: (context, index) {
                      final BulkJobModel job = jobs[index];
                      return InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BulkJobReceiptScreen(jobId: job.id, initialJob: job),
                        )),
                        child: ReportCardWidget(children: [
                          Row(children: [
                            Expanded(
                              child: Text(getTranslated('bulk_type_${job.type}', context) ?? job.type,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault)),
                            ),
                            BulkJobStatusChip(status: job.status),
                          ]),
                          if (job.createdAt != null) ...[
                            const SizedBox(height: 2),
                            Text(DateConverter.isoStringToLocalDateOnly(job.createdAt!),
                                style: robotoRegular.copyWith(
                                    fontSize: Dimensions.fontSizeExtraSmall,
                                    color: Theme.of(context).hintColor)),
                          ],
                          const SizedBox(height: Dimensions.paddingSizeSmall),
                          BulkJobProgressWidget(job: job),
                        ]),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
