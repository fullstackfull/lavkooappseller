import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_snackbar_widget.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';

/// Turns an on-screen report into a CSV file the owner can hand to an
/// accountant. Before this the transaction list, VAT report and wallet history
/// were screen-only: the only way to get numbers out was to retype them.
class ReportExportHelper {
  ReportExportHelper._();

  /// Excel opens UTF-8 CSV correctly only when the file starts with a BOM;
  /// without it Arabic column headers arrive as mojibake.
  static const String _bom = '﻿';

  static String _escape(Object? value) {
    final String text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String buildCsv({
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final StringBuffer buffer = StringBuffer(_bom);
    buffer.writeln(headers.map(_escape).join(','));
    for (final List<Object?> row in rows) {
      buffer.writeln(row.map(_escape).join(','));
    }
    return buffer.toString();
  }

  /// Writes the CSV to a temporary file and opens the system share sheet, which
  /// covers saving to Files/Drive, sending over WhatsApp, or emailing it.
  static Future<void> shareCsv({
    required BuildContext context,
    required String fileNamePrefix,
    required List<String> headers,
    required List<List<Object?>> rows,
    String? shareText,
  }) async {
    try {
      final String csv = buildCsv(headers: headers, rows: rows);
      final Directory dir = await getTemporaryDirectory();
      final String stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final File file = File('${dir.path}/${fileNamePrefix}_$stamp.csv');
      await file.writeAsString(csv);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'text/csv')],
          text: shareText,
        ),
      );

      if (context.mounted) {
        showCustomSnackBarWidget(
          getTranslated('exported_successfully', context),
          context,
          isError: false,
          sanckBarType: SnackBarType.success,
        );
      }
    } catch (e) {
      debugPrint('CSV export failed: $e');
      if (context.mounted) {
        showCustomSnackBarWidget(
          getTranslated('export_failed', context),
          context,
          sanckBarType: SnackBarType.error,
        );
      }
    }
  }
}
