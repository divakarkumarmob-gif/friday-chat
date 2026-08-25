import '../entities/contact.dart';

abstract class ContactsRepository {
  Future<List<Contact>> getContacts();
}
