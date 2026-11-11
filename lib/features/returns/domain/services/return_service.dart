import 'package:syriacosmeticsmanger/features/returns/domain/repositories/return_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/returns/domain/services/return_service_interface.dart';

class ReturnService implements ReturnServiceInterface {
  final ReturnRepositoryInterface returnRepoInterface;
  ReturnService({required this.returnRepoInterface});

  @override
  Future getReturns({String? status, int offset = 1}) =>
      returnRepoInterface.getReturns(status: status, offset: offset);

  @override
  Future getReturn(int id) => returnRepoInterface.getReturn(id);

  @override
  Future markInTransit(int id, {String? carrier, String? trackingNumber}) =>
      returnRepoInterface.markInTransit(id, carrier: carrier, trackingNumber: trackingNumber);

  @override
  Future receive(int id, {required bool restock}) => returnRepoInterface.receive(id, restock: restock);

  @override
  Future reject(int id, {required String reason}) => returnRepoInterface.reject(id, reason: reason);
}
