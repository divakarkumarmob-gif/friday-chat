import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AttachmentBottomSheet extends StatelessWidget {
  const AttachmentBottomSheet({super.key});

  Widget _buildItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 20,
        alignment: WrapAlignment.center,
        children: [
          _buildItem(
            icon: Icons.insert_drive_file,
            color: const Color(0xFF5F66CD),
            label: 'Document',
            onTap: () => Navigator.pop(context),
          ),
          _buildItem(
            icon: Icons.camera_alt,
            color: const Color(0xFFE91E63),
            label: 'Camera',
            onTap: () => Navigator.pop(context),
          ),
          _buildItem(
            icon: Icons.photo,
            color: const Color(0xFFAC44CF),
            label: 'Gallery',
            onTap: () => Navigator.pop(context),
          ),
          _buildItem(
            icon: Icons.headset,
            color: const Color(0xFFFF9800),
            label: 'Audio',
            onTap: () => Navigator.pop(context),
          ),
          _buildItem(
            icon: Icons.location_on,
            color: const Color(0xFF0F9D58),
            label: 'Location',
            onTap: () => Navigator.pop(context),
          ),
          _buildItem(
            icon: Icons.person,
            color: const Color(0xFF0088CC),
            label: 'Contact',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
