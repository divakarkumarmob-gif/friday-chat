import '../entities/call_log.dart';

abstract class CallRepository {
  Future<List<CallLog>> getCallLogs();
}
