abstract class StatementServiceInterface {
  Future getStatement({String? entryType, String? status, String? from, String? to, int offset = 1});

  Future exportStatement({String? entryType, String? status, String? from, String? to});
}
