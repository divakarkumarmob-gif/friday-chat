import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/chat/domain/entities/chat_conversation.dart';
import '../../features/chat/presentation/screens/chat_room_screen.dart';
import '../../features/call/presentation/screens/calling_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root_nav');

  static GoRouter createRouter({
    required VoidCallback onToggleTheme,
    required bool isDarkMode,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return GoRouter(
      navigatorKey: navigatorKey ?? rootNavigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'dashboard',
          builder: (context, state) => DashboardScreen(
            onToggleTheme: onToggleTheme,
            isDarkMode: isDarkMode,
          ),
        ),
        GoRoute(
          path: '/chat/:id',
          name: 'chat_room',
          pageBuilder: (context, state) {
            final conversationId = state.pathParameters['id'] ?? '';
            final conversation = state.extra as ChatConversation?;
            return CustomTransitionPage(
              key: state.pageKey,
              child: ChatRoomScreen(
                conversationId: conversationId,
                conversation: conversation,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/call/:id',
          name: 'calling_screen',
          pageBuilder: (context, state) {
            final callId = state.pathParameters['id'] ?? '';
            final name = state.uri.queryParameters['name'] ?? 'Contact';
            final isVideo = state.uri.queryParameters['isVideo'] == 'true';
            final avatarUrl = state.uri.queryParameters['avatar'];

            return CustomTransitionPage(
              key: state.pageKey,
              child: CallingScreen(
                callId: callId,
                callerName: name,
                avatarUrl: avatarUrl,
                isVideo: isVideo,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            );
          },
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Route not found: ${state.uri}'),
        ),
      ),
    );
  }
}
