import '../datasources/chat_mock_datasource.dart';
import '../models/chat_message_model.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatDataSource dataSource;

  ChatRepositoryImpl(this.dataSource);

  @override
  Future<List<ChatConversation>> getConversations() async {
    return await dataSource.getConversations();
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    return await dataSource.getMessages(conversationId);
  }

  @override
  Future<ChatMessage> sendMessage(ChatMessage message) async {
    final messageModel = ChatMessageModel.fromEntity(message);
    return await dataSource.sendMessage(messageModel);
  }
}
