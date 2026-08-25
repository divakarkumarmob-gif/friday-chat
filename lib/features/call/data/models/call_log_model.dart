import '../entities/call_log.dart';

class CallLogModel extends CallLog {
  const CallLogModel({
    required super.id,
    required super.callerId,
    required super.callerName,
    super.callerAvatar,
    required super.timestamp,
    required super.direction,
    required super.type,
    super.durationSeconds,
  });

  factory CallLogModel.fromJson(Map<String, dynamic> json) {
    return CallLogModel(
      id: json['id'] as String,
      callerId: json['callerId'] as String,
      callerName: json['callerName'] as String,
      callerAvatar: json['callerAvatar'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      direction: CallDirection.values.firstWhere(
        (e) => e.name == json['direction'],
        orElse: () => CallDirection.incoming,
      ),
      type: CallType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CallType.audio,
      ),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'timestamp': timestamp.toIso8601String(),
      'direction': direction.name,
      'type': type.name,
      'durationSeconds': durationSeconds,
    };
  }
}
