abstract class ReturnServiceInterface {
  Future getReturns({String? status, int offset = 1});

  Future getReturn(int id);

  Future markInTransit(int id, {String? carrier, String? trackingNumber});

  Future receive(int id, {required bool restock});

  Future reject(int id, {required String reason});
}
