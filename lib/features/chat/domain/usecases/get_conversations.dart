import '../../../../core/usecase/usecase.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_repository.dart';

class GetConversations implements UseCase<List<ChatConversation>, NoParams> {
  final ChatRepository repository;

  GetConversations(this.repository);

  @override
  Future<List<ChatConversation>> call(NoParams params) async {
    return await repository.getConversations();
  }
}
