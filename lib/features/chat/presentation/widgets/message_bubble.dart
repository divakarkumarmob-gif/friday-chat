import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: AppColors.lightTextSecondary);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 13, color: AppColors.lightTextSecondary);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 13, color: AppColors.lightTextSecondary);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 13, color: AppColors.accent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = message.isMe;

    final bubbleColor = isMe
        ? (isDark ? AppColors.darkMyMessage : AppColors.lightMyMessage)
        : (isDark ? AppColors.darkOtherMessage : AppColors.lightOtherMessage);

    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final timeColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 50.0 : 12.0,
          right: isMe ? 12.0 : 50.0,
          top: 3.0,
          bottom: 3.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6.0, bottom: 2.0),
              child: Text(
                message.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.jm().format(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: timeColor,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  _buildStatusIcon(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
