import '../../../../core/usecase/usecase.dart';
import '../entities/call_log.dart';
import '../repositories/call_repository.dart';

class GetCallLogs implements UseCase<List<CallLog>, NoParams> {
  final CallRepository repository;

  GetCallLogs(this.repository);

  @override
  Future<List<CallLog>> call(NoParams params) async {
    return await repository.getCallLogs();
  }
}
