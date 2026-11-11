import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart' show OpenFile;
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/features/reports/controllers/report_controller.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// One export the current report can be downloaded as.
class ReportExportOption {
  final String uri;
  final String fileName;
  final String label;
  final IconData icon;
  final Map<String, dynamic>? queryParameters;

  const ReportExportOption({
    required this.uri,
    required this.fileName,
    required this.label,
    required this.icon,
    this.queryParameters,
  });
}

/// The download control on a report page.
///
/// The file is rendered by the same exporters the vendor panel uses, so what a
/// seller downloads from their phone is the document their accountant already
/// knows. Saving it is reported either way: a download that silently does
/// nothing is indistinguishable from one that failed.
class ReportExportButtonWidget extends StatelessWidget {
  final List<ReportExportOption> options;
  const ReportExportButtonWidget({super.key, required this.options});

  Future<void> _download(BuildContext context, ReportExportOption option) async {
    final ReportController reports = Provider.of<ReportController>(context, listen: false);

    final String? savedPath = await reports.downloadExport(
      uri: option.uri,
      fileName: option.fileName,
      queryParameters: option.queryParameters,
    );

    if (!context.mounted) {
      return;
    }

    if (savedPath == null) {
      showCustomSnackBarWidget(
        getTranslated('export_failed', context), context, sanckBarType: SnackBarType.error,
      );
      return;
    }

    showCustomSnackBarWidget(
      getTranslated('export_downloaded', context), context, sanckBarType: SnackBarType.success,
    );
    await OpenFile.open(savedPath);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportController>(
      builder: (context, reports, _) {
        if (reports.isExporting) {
          return const Padding(
            padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
            child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        // One export needs no menu to choose from.
        if (options.length == 1) {
          return IconButton(
            tooltip: getTranslated(options.first.label, context),
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _download(context, options.first),
          );
        }

        return PopupMenuButton<ReportExportOption>(
          tooltip: getTranslated('download', context) ?? '',
          icon: const Icon(Icons.download_rounded),
          onSelected: (option) => _download(context, option),
          itemBuilder: (context) => options
              .map((option) => PopupMenuItem<ReportExportOption>(
                    value: option,
                    child: Row(children: [
                      Icon(option.icon, size: Dimensions.iconSizeSmall,
                          color: Theme.of(context).hintColor),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Text(getTranslated(option.label, context) ?? option.label,
                          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                    ]),
                  ))
              .toList(),
        );
      },
    );
  }
}
