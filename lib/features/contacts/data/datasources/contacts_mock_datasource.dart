import '../models/contact_model.dart';

abstract class ContactsDataSource {
  Future<List<ContactModel>> getContacts();
}

class ContactsMockDataSource implements ContactsDataSource {
  final List<ContactModel> _contacts = [
    const ContactModel(
      id: '1',
      name: 'Alice Johnson',
      status: 'Busy debugging the universe 🚀',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=250&q=80',
      phoneNumber: '+1 (555) 019-2834',
      isOnline: true,
    ),
    const ContactModel(
      id: '3',
      name: 'Michael Chen',
      status: 'Available',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=250&q=80',
      phoneNumber: '+1 (555) 438-9201',
      isOnline: false,
    ),
    const ContactModel(
      id: '4',
      name: 'Sarah Connor',
      status: 'No fate but what we make.',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80',
      phoneNumber: '+1 (555) 782-1923',
      isOnline: true,
    ),
    const ContactModel(
      id: '5',
      name: 'David Miller',
      status: 'At the gym 🏋️‍♂️',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=250&q=80',
      phoneNumber: '+1 (555) 671-8822',
      isOnline: false,
    ),
    const ContactModel(
      id: '6',
      name: 'Emma Watson',
      status: 'Books, tea & code ☕',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=250&q=80',
      phoneNumber: '+1 (555) 902-1144',
      isOnline: true,
    ),
    const ContactModel(
      id: '7',
      name: 'James Wilson',
      status: 'Sleeping... Do not disturb',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=250&q=80',
      phoneNumber: '+1 (555) 234-8899',
      isOnline: false,
    ),
  ];

  @override
  Future<List<ContactModel>> getContacts() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _contacts;
  }
}
