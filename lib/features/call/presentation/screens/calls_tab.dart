import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/call_log.dart';
import '../providers/call_provider.dart';
import '../widgets/call_tile.dart';

class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallProvider>().loadCallLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        if (callProvider.isLoading && callProvider.callLogs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = callProvider.callLogs;

        return RefreshIndicator(
          onRefresh: () => callProvider.loadCallLogs(),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Create Call Link section
              ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.link, color: Colors.white, size: 24),
                ),
                title: Text(
                  'Create call link',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  'Share a link for your Friday Chat call',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                onTap: () {},
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Recent',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              ...logs.map(
                (log) => CallTile(
                  log: log,
                  onTap: () {},
                  onCallPressed: () {
                    final isVideo = log.type == CallType.video;
                    context.push(
                      '/call/${log.callerId}?name=${log.callerName}&isVideo=$isVideo',
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
