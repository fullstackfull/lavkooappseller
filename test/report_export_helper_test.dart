import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/helper/report_export_helper.dart';

void main() {
  group('ReportExportHelper.buildCsv', () {
    test('writes a UTF-8 BOM so Excel renders Arabic headers correctly', () {
      final String csv = ReportExportHelper.buildCsv(
        headers: <String>['المبلغ'],
        rows: <List<Object?>>[<Object?>[100]],
      );
      expect(csv.codeUnitAt(0), 0xFEFF);
    });

    test('quotes fields containing commas, quotes or newlines', () {
      final String csv = ReportExportHelper.buildCsv(
        headers: <String>['note'],
        rows: <List<Object?>>[
          <Object?>['a,b'],
          <Object?>['say "hi"'],
          <Object?>['line1\nline2'],
        ],
      );
      expect(csv, contains('"a,b"'));
      expect(csv, contains('"say ""hi"""'));
      expect(csv, contains('"line1\nline2"'));
    });

    test('renders null cells as empty, not the string "null"', () {
      final String csv = ReportExportHelper.buildCsv(
        headers: <String>['a', 'b'],
        rows: <List<Object?>>[<Object?>[null, 1]],
      );
      expect(csv, contains('\n,1'));
      expect(csv, isNot(contains('null')));
    });
  });
}
