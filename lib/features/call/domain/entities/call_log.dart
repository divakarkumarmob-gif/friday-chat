enum CallDirection {
  incoming,
  outgoing,
  missed,
}

enum CallType {
  audio,
  video,
}

class CallLog {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final DateTime timestamp;
  final CallDirection direction;
  final CallType type;
  final int durationSeconds;

  const CallLog({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.timestamp,
    required this.direction,
    required this.type,
    this.durationSeconds = 0,
  });
}
