import 'package:syriacosmeticsmanger/features/finance_control/domain/repositories/finance_control_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/finance_control/domain/services/finance_control_service_interface.dart';

class FinanceControlService implements FinanceControlServiceInterface {
  final FinanceControlRepositoryInterface financeControlRepoInterface;
  FinanceControlService({required this.financeControlRepoInterface});

  @override
  Future getReconciliation({String? from, String? to}) =>
      financeControlRepoInterface.getReconciliation(from: from, to: to);

  @override
  Future simulateFee(Map<String, dynamic> query) => financeControlRepoInterface.simulateFee(query);

  @override
  Future getPriceChanges({int? productId, String? source}) =>
      financeControlRepoInterface.getPriceChanges(productId: productId, source: source);

  @override
  Future getPricingPolicy() => financeControlRepoInterface.getPricingPolicy();

  @override
  Future savePricingPolicy(Map<String, dynamic> payload) => financeControlRepoInterface.savePricingPolicy(payload);
}
