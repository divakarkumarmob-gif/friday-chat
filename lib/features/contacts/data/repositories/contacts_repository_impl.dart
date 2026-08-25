import '../datasources/contacts_mock_datasource.dart';
import '../../domain/entities/contact.dart';
import '../../domain/repositories/contacts_repository.dart';

class ContactsRepositoryImpl implements ContactsRepository {
  final ContactsDataSource dataSource;

  ContactsRepositoryImpl(this.dataSource);

  @override
  Future<List<Contact>> getContacts() async {
    return await dataSource.getContacts();
  }
}
