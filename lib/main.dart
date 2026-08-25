import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/network/websocket_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/security/session_manager.dart';
import 'core/security/signal_crypto_service.dart';
import 'core/theme/app_theme.dart';
import 'features/chat/data/datasources/chat_mock_datasource.dart';
import 'features/chat/data/repositories/chat_repository_impl.dart';
import 'features/chat/domain/usecases/get_conversations.dart';
import 'features/chat/domain/usecases/get_messages.dart';
import 'features/chat/domain/usecases/send_message.dart';
import 'features/chat/presentation/providers/chat_provider.dart';
import 'features/call/data/datasources/call_mock_datasource.dart';
import 'features/call/data/repositories/call_repository_impl.dart';
import 'features/call/domain/usecases/get_call_logs.dart';
import 'features/call/presentation/providers/call_provider.dart';
import 'features/contacts/data/datasources/contacts_mock_datasource.dart';
import 'features/contacts/data/repositories/contacts_repository_impl.dart';
import 'features/contacts/domain/usecases/get_contacts.dart';
import 'features/contacts/presentation/providers/contacts_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase Core & Background Messaging Handler
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('[Firebase] Initialization deferred or local mock mode: $e');
  }

  // 2. Initialize Notification Service
  try {
    await NotificationService().initialize(
      onTokenRefreshCallback: (token) {
        debugPrint('[FCM Token Refresh] New Token: $token');
      },
      onNotificationTap: (data) {
        debugPrint('[FCM Notification Tap] Data: $data');
        final conversationId = data['conversationId'] ?? data['senderId'];
        if (conversationId != null) {
          AppRouter.rootNavigatorKey.currentState?.pushNamed(
            '/chat/$conversationId',
          );
        }
      },
    );
  } catch (e) {
    debugPrint('[NotificationService] Local setup notice: $e');
  }

  runApp(const FridayChatApp());
}

class FridayChatApp extends StatefulWidget {
  const FridayChatApp({super.key});

  @override
  State<FridayChatApp> createState() => _FridayChatAppState();
}

class _FridayChatAppState extends State<FridayChatApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late final WebSocketService _wsService;
  late final SignalCryptoService _cryptoService;
  late final SessionManager _sessionManager;

  @override
  void initState() {
    super.initState();
    _wsService = WebSocketService();
    _cryptoService = SignalCryptoService();
    _sessionManager = SessionManager(cryptoService: _cryptoService);

    // 1. Initialize real-time WebSocket connection to the Go backend
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      const currentUserId = 'user_1';
      const currentUserName = 'Alice Johnson';

      _wsService.connect(
        userId: currentUserId,
        userName: currentUserName,
      );

      // 2. Automatically generate Signal Protocol E2EE Keys and upload PreKey bundle to backend
      try {
        await _cryptoService.generateAndRegisterKeys(
          userId: currentUserId,
          serverUrl: AppConstants.defaultServerUrl,
        );
      } catch (e) {
        debugPrint('[E2EE] Key registration deferred: $e');
      }
    });
  }

  @override
  void dispose() {
    _wsService.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        final isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
        _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Clean Architecture Data Sources
    final chatDataSource = ChatMockDataSource();
    final callDataSource = CallMockDataSource();
    final contactsDataSource = ContactsMockDataSource();

    // 2. Clean Architecture Repositories
    final chatRepository = ChatRepositoryImpl(chatDataSource);
    final callRepository = CallRepositoryImpl(callDataSource);
    final contactsRepository = ContactsRepositoryImpl(contactsDataSource);

    // 3. Clean Architecture Use Cases
    final getConversations = GetConversations(chatRepository);
    final getMessages = GetMessages(chatRepository);
    final sendMessage = SendMessage(chatRepository);
    final getCallLogs = GetCallLogs(callRepository);
    final getContacts = GetContacts(contactsRepository);

    final isDarkMode = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

    final router = AppRouter.createRouter(
      onToggleTheme: _toggleTheme,
      isDarkMode: isDarkMode,
      navigatorKey: AppRouter.rootNavigatorKey,
    );

    return MultiProvider(
      providers: [
        Provider<SignalCryptoService>.value(
          value: _cryptoService,
        ),
        Provider<SessionManager>.value(
          value: _sessionManager,
        ),
        ChangeNotifierProvider<WebSocketService>.value(
          value: _wsService,
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(
            getConversations: getConversations,
            getMessages: getMessages,
            sendMessage: sendMessage,
            wsService: _wsService,
            sessionManager: _sessionManager,
          ),
        ),
        ChangeNotifierProvider<CallProvider>(
          create: (_) => CallProvider(
            getCallLogs: getCallLogs,
            wsService: _wsService,
            navigatorKey: AppRouter.rootNavigatorKey,
          ),
        ),
        ChangeNotifierProvider<ContactsProvider>(
          create: (_) => ContactsProvider(
            getContacts: getContacts,
          ),
        ),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        routerConfig: router,
      ),
    );
  }
}
