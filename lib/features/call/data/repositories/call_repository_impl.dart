import '../datasources/call_mock_datasource.dart';
import '../../domain/entities/call_log.dart';
import '../../domain/repositories/call_repository.dart';

class CallRepositoryImpl implements CallRepository {
  final CallDataSource dataSource;

  CallRepositoryImpl(this.dataSource);

  @override
  Future<List<CallLog>> getCallLogs() async {
    return await dataSource.getCallLogs();
  }
}
