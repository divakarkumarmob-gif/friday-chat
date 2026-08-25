import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';

class ChatTile extends StatelessWidget {
  final ChatConversation conversation;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat.jm().format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(dateTime);
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 14, color: AppColors.lightTextSecondary);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 15, color: AppColors.lightTextSecondary);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 15, color: AppColors.lightTextSecondary);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 15, color: AppColors.accent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Row(
          children: [
            UserAvatar(
              name: conversation.name,
              imageUrl: conversation.avatarUrl,
              radius: 26,
              showOnlineBadge: conversation.isOnline,
              isOnline: conversation.isOnline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conversation.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(conversation.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: conversation.unreadCount > 0
                              ? AppColors.primary
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          fontWeight: conversation.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (conversation.isLastMessageMe) ...[
                        _buildStatusIcon(conversation.lastMessageStatus),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.push_pin,
                          size: 15,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ],
                      if (conversation.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        UnreadCountBadge(count: conversation.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
