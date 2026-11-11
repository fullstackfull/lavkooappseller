import 'package:syriacosmeticsmanger/features/reports/domain/repositories/report_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/reports/domain/services/report_service_interface.dart';

class ReportService implements ReportServiceInterface {
  final ReportRepositoryInterface reportRepoInterface;
  ReportService({required this.reportRepoInterface});

  @override
  Future getOrderReport({String? dateType, String? from, String? to, String? search, int offset = 1}) =>
      reportRepoInterface.getOrderReport(dateType: dateType, from: from, to: to, search: search, offset: offset);

  @override
  Future getProductReport({String? dateType, String? from, String? to, String? search, int offset = 1}) =>
      reportRepoInterface.getProductReport(dateType: dateType, from: from, to: to, search: search, offset: offset);

  @override
  Future getStockReport({String? search, String? sort, int? categoryId, int offset = 1}) =>
      reportRepoInterface.getStockReport(search: search, sort: sort, categoryId: categoryId, offset: offset);

  @override
  Future downloadExport(String uri, Map<String, dynamic> queryParameters) =>
      reportRepoInterface.downloadExport(uri, queryParameters);
}
