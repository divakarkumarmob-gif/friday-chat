import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final bool showOnlineBadge;
  final bool isOnline;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 24.0,
    this.showOnlineBadge = false,
    this.isOnline = false,
  });

  String get _initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFDFE5E7),
          backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
              ? NetworkImage(imageUrl!)
              : null,
          child: imageUrl == null || imageUrl!.isEmpty
              ? Text(
                  _initials,
                  style: TextStyle(
                    fontSize: radius * 0.75,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                  ),
                )
              : null,
        ),
        if (showOnlineBadge && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.6,
              height: radius * 0.6,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBackground : Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
