import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/call_log.dart';

class CallTile extends StatelessWidget {
  final CallLog log;
  final VoidCallback onTap;
  final VoidCallback onCallPressed;

  const CallTile({
    super.key,
    required this.log,
    required this.onTap,
    required this.onCallPressed,
  });

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat.jm().format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat.jm().format(dateTime)}';
    } else {
      return DateFormat('dd/MM/yy, hh:mm a').format(dateTime);
    }
  }

  Widget _buildDirectionIcon() {
    switch (log.direction) {
      case CallDirection.incoming:
        return const Icon(Icons.call_received, size: 16, color: AppColors.callIncoming);
      case CallDirection.outgoing:
        return const Icon(Icons.call_made, size: 16, color: AppColors.callOutgoing);
      case CallDirection.missed:
        return const Icon(Icons.call_received, size: 16, color: AppColors.callMissed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Row(
          children: [
            UserAvatar(
              name: log.callerName,
              imageUrl: log.callerAvatar,
              radius: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.callerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: log.direction == CallDirection.missed
                          ? AppColors.callMissed
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildDirectionIcon(),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(log.timestamp),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                log.type == CallType.video ? Icons.videocam : Icons.call,
                color: AppColors.primary,
              ),
              onPressed: onCallPressed,
            ),
          ],
        ),
      ),
    );
  }
}
