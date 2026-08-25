import '../../../../core/usecase/usecase.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class SendMessage implements UseCase<ChatMessage, ChatMessage> {
  final ChatRepository repository;

  SendMessage(this.repository);

  @override
  Future<ChatMessage> call(ChatMessage params) async {
    return await repository.sendMessage(params);
  }
}
