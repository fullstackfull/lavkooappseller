import 'package:syriacosmeticsmanger/features/statement/domain/repositories/statement_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/statement/domain/services/statement_service_interface.dart';

class StatementService implements StatementServiceInterface {
  final StatementRepositoryInterface statementRepoInterface;
  StatementService({required this.statementRepoInterface});

  @override
  Future getStatement({String? entryType, String? status, String? from, String? to, int offset = 1}) =>
      statementRepoInterface.getStatement(entryType: entryType, status: status, from: from, to: to, offset: offset);

  @override
  Future exportStatement({String? entryType, String? status, String? from, String? to}) =>
      statementRepoInterface.exportStatement(entryType: entryType, status: status, from: from, to: to);
}
