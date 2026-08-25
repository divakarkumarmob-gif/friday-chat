import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../chat/presentation/screens/chats_tab.dart';
import '../../call/presentation/screens/calls_tab.dart';
import '../../contacts/presentation/screens/contacts_tab.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  const DashboardScreen({
    super.key,
    this.onToggleTheme,
    this.isDarkMode = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildFAB() {
    switch (_tabController.index) {
      case 0:
        return FloatingActionButton(
          heroTag: 'fab_chat',
          onPressed: () {
            _tabController.animateTo(2); // Jump to contacts tab
          },
          child: const Icon(Icons.message),
        );
      case 1:
        return FloatingActionButton(
          heroTag: 'fab_call',
          onPressed: () {
            _tabController.animateTo(2);
          },
          child: const Icon(Icons.add_call),
        );
      case 2:
        return FloatingActionButton(
          heroTag: 'fab_contact',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add New Contact')),
            );
          },
          child: const Icon(Icons.person_add_alt_1),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              tooltip: 'Toggle Theme',
            ),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Camera',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Selected: $value')),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'New group', child: Text('New group')),
              const PopupMenuItem(value: 'New broadcast', child: Text('New broadcast')),
              const PopupMenuItem(value: 'Linked devices', child: Text('Linked devices')),
              const PopupMenuItem(value: 'Starred messages', child: Text('Starred messages')),
              const PopupMenuItem(value: 'Settings', child: Text('Settings')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3.5,
          tabs: const [
            Tab(text: AppConstants.chatsTabTitle),
            Tab(text: AppConstants.callsTabTitle),
            Tab(text: AppConstants.contactsTabTitle),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ChatsTab(),
          CallsTab(),
          ContactsTab(),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }
}
