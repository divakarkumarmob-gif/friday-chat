import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../chat/domain/entities/chat_conversation.dart';
import '../providers/contacts_provider.dart';
import '../widgets/contact_tile.dart';

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactsProvider>().loadContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ContactsProvider>(
      builder: (context, contactsProvider, child) {
        if (contactsProvider.isLoading && contactsProvider.contacts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final contacts = contactsProvider.contacts;

        return RefreshIndicator(
          onRefresh: () => contactsProvider.loadContacts(),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // New Group / New Contact shortcuts
              ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.group_add, color: Colors.white, size: 22),
                ),
                title: Text(
                  'New group',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                onTap: () {},
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.person_add, color: Colors.white, size: 22),
                ),
                title: Text(
                  'New contact',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                trailing: const Icon(Icons.qr_code, size: 20),
                onTap: () {},
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Contacts on Friday Chat (${contacts.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              ...contacts.map(
                (contact) => ContactTile(
                  contact: contact,
                  onTap: () {
                    final conversation = ChatConversation(
                      id: contact.id,
                      name: contact.name,
                      avatarUrl: contact.avatarUrl,
                      lastMessage: 'Tap to start conversation',
                      lastMessageTime: DateTime.now(),
                      isOnline: contact.isOnline,
                    );
                    context.push(
                      '/chat/${contact.id}',
                      extra: conversation,
                    );
                  },
                  onVoiceCall: () {
                    context.push(
                      '/call/${contact.id}?name=${contact.name}&isVideo=false',
                    );
                  },
                  onVideoCall: () {
                    context.push(
                      '/call/${contact.id}?name=${contact.name}&isVideo=true',
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
