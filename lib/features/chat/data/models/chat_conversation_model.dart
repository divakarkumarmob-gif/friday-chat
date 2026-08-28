import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';

class ChatConversationModel extends ChatConversation {
  const ChatConversationModel({
    required super.id,
    required super.name,
    super.avatarUrl,
    required super.lastMessage,
    required super.lastMessageTime,
    super.unreadCount,
    super.isOnline,
    super.isGroup,
    super.isPinned,
    super.lastMessageStatus,
    super.isLastMessageMe,
  });

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) {
    return ChatConversationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      lastMessage: json['lastMessage'] as String,
      lastMessageTime: DateTime.parse(json['lastMessageTime'] as String),
      unreadCount: json['unreadCount'] as int? ?? 0,
      isOnline: json['isOnline'] as bool? ?? false,
      isGroup: json['isGroup'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      lastMessageStatus: MessageStatus.values.firstWhere(
        (e) => e.name == json['lastMessageStatus'],
        orElse: () => MessageStatus.delivered,
      ),
      isLastMessageMe: json['isLastMessageMe'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      'isGroup': isGroup,
      'isPinned': isPinned,
      'lastMessageStatus': lastMessageStatus.name,
      'isLastMessageMe': isLastMessageMe,
    };
  }

  factory ChatConversationModel.fromEntity(ChatConversation entity) {
    return ChatConversationModel(
      id: entity.id,
      name: entity.name,
      avatarUrl: entity.avatarUrl,
      lastMessage: entity.lastMessage,
      lastMessageTime: entity.lastMessageTime,
      unreadCount: entity.unreadCount,
      isOnline: entity.isOnline,
      isGroup: entity.isGroup,
      isPinned: entity.isPinned,
      lastMessageStatus: entity.lastMessageStatus,
      isLastMessageMe: entity.isLastMessageMe,
    );
  }
}
