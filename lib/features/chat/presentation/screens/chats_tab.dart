import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_tile.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.isLoading && chatProvider.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (chatProvider.errorMessage != null && chatProvider.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(chatProvider.errorMessage!),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => chatProvider.loadConversations(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final conversations = chatProvider.conversations;

        if (conversations.isEmpty) {
          return const Center(
            child: Text('No conversations yet. Tap the button below to start chatting!'),
          );
        }

        return RefreshIndicator(
          onRefresh: () => chatProvider.loadConversations(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: conversations.length,
            separatorBuilder: (context, index) => const Divider(
              indent: 78,
              endIndent: 16,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return ChatTile(
                conversation: conversation,
                onTap: () {
                  context.push(
                    '/chat/${conversation.id}',
                    extra: conversation,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
