import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatConversation>> getConversations();
  Future<List<ChatMessage>> getMessages(String conversationId);
  Future<ChatMessage> sendMessage(ChatMessage message);
}
