import '../models/chat_conversation_model.dart';
import '../models/chat_message_model.dart';
import '../../domain/entities/chat_message.dart';

abstract class ChatDataSource {
  Future<List<ChatConversationModel>> getConversations();
  Future<List<ChatMessageModel>> getMessages(String conversationId);
  Future<ChatMessageModel> sendMessage(ChatMessageModel message);
}

class ChatMockDataSource implements ChatDataSource {
  final List<ChatConversationModel> _conversations = [
    ChatConversationModel(
      id: '1',
      name: 'Alice Johnson',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=250&q=80',
      lastMessage: 'Hey, are we still meeting today at 4?',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 8)),
      unreadCount: 2,
      isOnline: true,
      isPinned: true,
      lastMessageStatus: MessageStatus.delivered,
      isLastMessageMe: false,
    ),
    ChatConversationModel(
      id: '2',
      name: 'Flutter Devs Squad',
      avatarUrl: 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=250&q=80',
      lastMessage: 'David: Check out the new Clean Architecture layout!',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 35)),
      unreadCount: 5,
      isGroup: true,
      isPinned: true,
      lastMessageStatus: MessageStatus.read,
      isLastMessageMe: false,
    ),
    ChatConversationModel(
      id: '3',
      name: 'Michael Chen',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=250&q=80',
      lastMessage: 'Sounds great! Sent you the design files.',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 0,
      isOnline: false,
      lastMessageStatus: MessageStatus.read,
      isLastMessageMe: true,
    ),
    ChatConversationModel(
      id: '4',
      name: 'Sarah Connor',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80',
      lastMessage: 'Photo',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 5)),
      unreadCount: 0,
      isOnline: true,
      lastMessageStatus: MessageStatus.delivered,
      isLastMessageMe: false,
    ),
    ChatConversationModel(
      id: '5',
      name: 'David Miller',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=250&q=80',
      lastMessage: 'Can you review the PR when free?',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      isOnline: false,
      lastMessageStatus: MessageStatus.read,
      isLastMessageMe: false,
    ),
  ];

  final Map<String, List<ChatMessageModel>> _messages = {
    '1': [
      ChatMessageModel(
        id: 'm1',
        conversationId: '1',
        senderId: '1',
        senderName: 'Alice Johnson',
        content: 'Hi there! Did you get a chance to check the project requirements?',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
        isMe: false,
        status: MessageStatus.read,
      ),
      ChatMessageModel(
        id: 'm2',
        conversationId: '1',
        senderId: 'me',
        senderName: 'Me',
        content: 'Yes, looking through the Clean Architecture specs now. It looks super clean and organized!',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
        isMe: true,
        status: MessageStatus.read,
      ),
      ChatMessageModel(
        id: 'm3',
        conversationId: '1',
        senderId: '1',
        senderName: 'Alice Johnson',
        content: 'Awesome! We have the design tokens, GoRouter navigation, and the calling screen ready.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        isMe: false,
        status: MessageStatus.read,
      ),
      ChatMessageModel(
        id: 'm4',
        conversationId: '1',
        senderId: '1',
        senderName: 'Alice Johnson',
        content: 'Hey, are we still meeting today at 4?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
        isMe: false,
        status: MessageStatus.delivered,
      ),
    ],
  };

  @override
  Future<List<ChatConversationModel>> getConversations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _conversations;
  }

  @override
  Future<List<ChatMessageModel>> getMessages(String conversationId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (_messages.containsKey(conversationId)) {
      return List.from(_messages[conversationId]!);
    }
    // Generate default greeting conversation if none exists
    return [
      ChatMessageModel(
        id: 'm_def_1',
        conversationId: conversationId,
        senderId: conversationId,
        senderName: 'Contact',
        content: 'Hello! Welcome to Friday Chat.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        isMe: false,
        status: MessageStatus.read,
      ),
    ];
  }

  @override
  Future<ChatMessageModel> sendMessage(ChatMessageModel message) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_messages.containsKey(message.conversationId)) {
      _messages[message.conversationId] = [];
    }
    _messages[message.conversationId]!.add(message);

    // Update conversation last message
    final index = _conversations.indexWhere((c) => c.id == message.conversationId);
    if (index != -1) {
      final updated = _conversations[index].copyWith(
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
        isLastMessageMe: true,
        lastMessageStatus: MessageStatus.sent,
      );
      _conversations[index] = ChatConversationModel.fromEntity(updated);
    }

    return message;
  }
}
