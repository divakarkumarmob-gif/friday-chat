import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatRoomScreen extends StatefulWidget {
  final String conversationId;
  final ChatConversation? conversation;

  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadMessages(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.getMessagesFor(widget.conversationId);

    final title = widget.conversation?.name ?? 'Chat';
    final avatarUrl = widget.conversation?.avatarUrl;
    final isOnline = widget.conversation?.isOnline ?? true;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkChatBackground : AppColors.lightChatBackground,
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 70,
        leading: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => context.pop(),
          child: Row(
            children: [
              const SizedBox(width: 4),
              const Icon(Icons.arrow_back, size: 24),
              const SizedBox(width: 2),
              UserAvatar(
                name: title,
                imageUrl: avatarUrl,
                radius: 18,
              ),
            ],
          ),
        ),
        title: InkWell(
          onTap: () {
            // Profile details screen placeholder
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isOnline ? 'online' : 'offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Video call',
            onPressed: () {
              context.push(
                '/call/${widget.conversationId}?name=$title&isVideo=true',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Voice call',
            onPressed: () {
              context.push(
                '/call/${widget.conversationId}?name=$title&isVideo=false',
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {},
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view_contact', child: Text('View contact')),
              const PopupMenuItem(value: 'media', child: Text('Media, links, and docs')),
              const PopupMenuItem(value: 'search', child: Text('Search')),
              const PopupMenuItem(value: 'mute', child: Text('Mute notifications')),
              const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper')),
              const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkSurface : Colors.white).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🔒 Messages and calls are end-to-end encrypted.',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return MessageBubble(message: message);
                    },
                  ),
          ),
          ChatInputBar(
            onSend: (text) {
              chatProvider.sendTextMessage(
                conversationId: widget.conversationId,
                text: text,
              );
              Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
            },
          ),
        ],
      ),
    );
  }
}
