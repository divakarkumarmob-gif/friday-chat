import '../models/call_log_model.dart';
import '../../domain/entities/call_log.dart';

abstract class CallDataSource {
  Future<List<CallLogModel>> getCallLogs();
}

class CallMockDataSource implements CallDataSource {
  final List<CallLogModel> _logs = [
    CallLogModel(
      id: 'c1',
      callerId: '1',
      callerName: 'Alice Johnson',
      callerAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=250&q=80',
      timestamp: DateTime.now().subtract(const Duration(minutes: 42)),
      direction: CallDirection.incoming,
      type: CallType.video,
      durationSeconds: 184,
    ),
    CallLogModel(
      id: 'c2',
      callerId: '3',
      callerName: 'Michael Chen',
      callerAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=250&q=80',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      direction: CallDirection.missed,
      type: CallType.audio,
    ),
    CallLogModel(
      id: 'c3',
      callerId: '4',
      callerName: 'Sarah Connor',
      callerAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      direction: CallDirection.outgoing,
      type: CallType.audio,
      durationSeconds: 430,
    ),
    CallLogModel(
      id: 'c4',
      callerId: '5',
      callerName: 'David Miller',
      callerAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=250&q=80',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      direction: CallDirection.incoming,
      type: CallType.video,
      durationSeconds: 95,
    ),
  ];

  @override
  Future<List<CallLogModel>> getCallLogs() async {
    await Future.delayed(const Duration(milliseconds: 180));
    return _logs;
  }
}
