import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/security/key_bundle.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/usecases/get_conversations.dart';
import '../../domain/usecases/get_messages.dart';
import '../../domain/usecases/send_message.dart';

class ChatProvider extends ChangeNotifier {
  final GetConversations _getConversations;
  final GetMessages _getMessages;
  final SendMessage _sendMessage;
  final WebSocketService? _wsService;
  final SessionManager? _sessionManager;

  List<ChatConversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesByConversation = {};
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _wsSubscription;

  ChatProvider({
    required GetConversations getConversations,
    required GetMessages getMessages,
    required SendMessage sendMessage,
    WebSocketService? wsService,
    SessionManager? sessionManager,
  })  : _getConversations = getConversations,
        _getMessages = getMessages,
        _sendMessage = sendMessage,
        _wsService = wsService,
        _sessionManager = sessionManager {
    _initWebSocketListener();
  }

  List<ChatConversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _initWebSocketListener() {
    if (_wsService == null) return;

    _wsSubscription = _wsService!.messageStream.listen((data) {
      final type = data['type'] as String?;

      if (type == 'direct') {
        _handleIncomingDirectMessage(data);
      } else if (type == 'ack') {
        _handleDeliveryAck(data);
      }
    });
  }

  /// 🔓 Decrypts and processes incoming messages using Double Ratchet
  Future<void> _handleIncomingDirectMessage(Map<String, dynamic> data) async {
    final senderId = data['from'] as String? ?? 'unknown';
    String displayContent = data['content'] as String? ?? '';
    final id = data['id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = data['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
        : DateTime.now();

    // 1. Pass through Double Ratchet decryption if payload contains ciphertext
    if (data['payload'] != null && _sessionManager != null) {
      try {
        final payloadMap = data['payload'] as Map<String, dynamic>;
        if (payloadMap['isEncrypted'] == true && payloadMap['cipherText'] != null) {
          final encryptedPayload = EncryptedPayload.fromJson(payloadMap);
          final decryptedText = await _sessionManager!.decryptMessage(
            senderId: senderId,
            payload: encryptedPayload,
          );
          displayContent = decryptedText;
        }
      } catch (e) {
        debugPrint('[Double Ratchet] Decryption fallback: $e');
      }
    }

    final incomingMsg = ChatMessage(
      id: id,
      conversationId: senderId,
      senderId: senderId,
      senderName: senderId,
      content: displayContent,
      timestamp: timestamp,
      isMe: false,
      status: MessageStatus.delivered,
    );

    // 2. Append message to chat room messages list
    if (!_messagesByConversation.containsKey(senderId)) {
      _messagesByConversation[senderId] = [];
    }
    _messagesByConversation[senderId]!.add(incomingMsg);

    // 3. Update conversation snippet and badge count
    final idx = _conversations.indexWhere((c) => c.id == senderId);
    if (idx != -1) {
      final current = _conversations[idx];
      _conversations[idx] = current.copyWith(
        lastMessage: displayContent,
        lastMessageTime: timestamp,
        unreadCount: current.unreadCount + 1,
        isLastMessageMe: false,
        lastMessageStatus: MessageStatus.delivered,
      );
    } else {
      _conversations.insert(
        0,
        ChatConversation(
          id: senderId,
          name: senderId,
          lastMessage: displayContent,
          lastMessageTime: timestamp,
          unreadCount: 1,
          isOnline: true,
          isLastMessageMe: false,
          lastMessageStatus: MessageStatus.delivered,
        ),
      );
    }

    notifyListeners();
  }

  void _handleDeliveryAck(Map<String, dynamic> data) {
    final messageId = data['id'] as String?;
    if (messageId == null) return;

    for (final room in _messagesByConversation.values) {
      final msgIdx = room.indexWhere((m) => m.id == messageId);
      if (msgIdx != -1) {
        room[msgIdx] = room[msgIdx].copyWith(status: MessageStatus.delivered);
        notifyListeners();
        break;
      }
    }
  }

  List<ChatMessage> getMessagesFor(String conversationId) {
    return _messagesByConversation[conversationId] ?? [];
  }

  Future<void> loadConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _getConversations(const NoParams());
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String conversationId) async {
    try {
      final msgs = await _getMessages(GetMessagesParams(conversationId));
      _messagesByConversation[conversationId] = msgs;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// 🔒 Encrypts plain text with Double Ratchet before sending over WebSocket
  Future<void> sendTextMessage({
    required String conversationId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final newMessage = ChatMessage(
      id: msgId,
      conversationId: conversationId,
      senderId: 'me',
      senderName: 'Me',
      content: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sending,
    );

    // 1. Optimistic UI update (displays plain text to local sender)
    if (!_messagesByConversation.containsKey(conversationId)) {
      _messagesByConversation[conversationId] = [];
    }
    _messagesByConversation[conversationId]!.add(newMessage);

    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      _conversations[idx] = _conversations[idx].copyWith(
        lastMessage: text.trim(),
        lastMessageTime: newMessage.timestamp,
        isLastMessageMe: true,
        lastMessageStatus: MessageStatus.sending,
      );
    }
    notifyListeners();

    // 2. Encrypt text using Double Ratchet session
    Map<String, dynamic>? encryptedPayloadJson;
    if (_sessionManager != null) {
      try {
        final encryptedPayload = await _sessionManager!.encryptMessage(
          recipientId: conversationId,
          serverUrl: AppConstants.defaultServerUrl,
          plainText: text.trim(),
        );
        encryptedPayloadJson = encryptedPayload.toJson();
      } catch (e) {
        debugPrint('[Double Ratchet] Encryption error: $e');
      }
    }

    // 3. Send over real-time WebSocket connection
    bool sentOverSocket = false;
    if (_wsService != null && _wsService!.isConnected) {
      sentOverSocket = _wsService!.sendDirectMessage(
        id: msgId,
        to: conversationId,
        content: text.trim(),
        payload: encryptedPayloadJson,
      );
    }

    if (sentOverSocket) {
      final room = _messagesByConversation[conversationId];
      if (room != null) {
        final pos = room.indexWhere((m) => m.id == msgId);
        if (pos != -1) {
          room[pos] = room[pos].copyWith(status: MessageStatus.sent);
          notifyListeners();
        }
      }
    } else {
      try {
        await _sendMessage(newMessage);
      } catch (e) {
        _errorMessage = e.toString();
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}
