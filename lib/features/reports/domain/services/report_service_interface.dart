abstract class ReportServiceInterface {
  Future<dynamic> getOrderReport({String? dateType, String? from, String? to, String? search, int offset});

  Future<dynamic> getProductReport({String? dateType, String? from, String? to, String? search, int offset});

  Future<dynamic> getStockReport({String? search, String? sort, int? categoryId, int offset});

  Future<dynamic> downloadExport(String uri, Map<String, dynamic> queryParameters);
}
