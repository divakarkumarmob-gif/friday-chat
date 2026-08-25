import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/contact.dart';

class ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback onVoiceCall;
  final VoidCallback onVideoCall;

  const ContactTile({
    super.key,
    required this.contact,
    required this.onTap,
    required this.onVoiceCall,
    required this.onVideoCall,
  });

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
              name: contact.name,
              imageUrl: contact.avatarUrl,
              radius: 24,
              showOnlineBadge: contact.isOnline,
              isOnline: contact.isOnline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.status,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 22),
              onPressed: onVoiceCall,
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined, color: AppColors.primary, size: 24),
              onPressed: onVideoCall,
            ),
          ],
        ),
      ),
    );
  }
}
