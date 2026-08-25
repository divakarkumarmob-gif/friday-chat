enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
}

enum MessageType {
  text,
  image,
  audio,
  document,
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final MessageStatus status;
  final bool isMe;
  final String? mediaUrl;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    required this.isMe,
    this.mediaUrl,
  });

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    MessageType? type,
    MessageStatus? status,
    bool? isMe,
    String? mediaUrl,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      status: status ?? this.status,
      isMe: isMe ?? this.isMe,
      mediaUrl: mediaUrl ?? this.mediaUrl,
    );
  }
}
