import 'chat_message.dart';

class ChatConversation {
  final String id;
  final String name;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final bool isGroup;
  final bool isPinned;
  final MessageStatus lastMessageStatus;
  final bool isLastMessageMe;

  const ChatConversation({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isGroup = false,
    this.isPinned = false,
    this.lastMessageStatus = MessageStatus.delivered,
    this.isLastMessageMe = false,
  });

  ChatConversation copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
    bool? isGroup,
    bool? isPinned,
    MessageStatus? lastMessageStatus,
    bool? isLastMessageMe,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      isGroup: isGroup ?? this.isGroup,
      isPinned: isPinned ?? this.isPinned,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      isLastMessageMe: isLastMessageMe ?? this.isLastMessageMe,
    );
  }
}
