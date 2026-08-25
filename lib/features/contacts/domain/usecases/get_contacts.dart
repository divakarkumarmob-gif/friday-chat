import '../../../../core/usecase/usecase.dart';
import '../entities/contact.dart';
import '../repositories/contacts_repository.dart';

class GetContacts implements UseCase<List<Contact>, NoParams> {
  final ContactsRepository repository;

  GetContacts(this.repository);

  @override
  Future<List<Contact>> call(NoParams params) async {
    return await repository.getContacts();
  }
}
