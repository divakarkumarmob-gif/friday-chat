import '../../../../core/usecase/usecase.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class GetMessagesParams {
  final String conversationId;
  const GetMessagesParams(this.conversationId);
}

class GetMessages implements UseCase<List<ChatMessage>, GetMessagesParams> {
  final ChatRepository repository;

  GetMessages(this.repository);

  @override
  Future<List<ChatMessage>> call(GetMessagesParams params) async {
    return await repository.getMessages(params.conversationId);
  }
}
