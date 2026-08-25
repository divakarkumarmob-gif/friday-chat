import 'package:flutter/foundation.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/contact.dart';
import '../../domain/usecases/get_contacts.dart';

class ContactsProvider extends ChangeNotifier {
  final GetContacts _getContacts;

  List<Contact> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;

  ContactsProvider({required GetContacts getContacts})
      : _getContacts = getContacts;

  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadContacts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _contacts = await _getContacts(const NoParams());
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
