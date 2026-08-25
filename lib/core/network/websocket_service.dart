import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/app_constants.dart';

enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
}

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  String? _currentUserId;
  String? _currentUserName;
  String _baseUrl = AppConstants.defaultWsUrl;

  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  WebSocketConnectionState get state => _state;
  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  bool get isConnected => _state == WebSocketConnectionState.connected;
  String? get currentUserId => _currentUserId;

  void configure({required String baseUrl}) {
    _baseUrl = baseUrl;
  }

  /// Connects to the Go WebSocket server with User ID and Display Name
  Future<void> connect({required String userId, required String userName}) async {
    _currentUserId = userId;
    _currentUserName = userName;

    if (_state == WebSocketConnectionState.connected) {
      return;
    }

    _setState(WebSocketConnectionState.connecting);

    final uri = Uri.parse('$_baseUrl?userId=$userId&userName=${Uri.encodeComponent(userName)}');
    dev.log('[WebSocket] Connecting to $uri...', name: 'WebSocketService');

    try {
      _channel = WebSocketChannel.connect(uri);

      // Listen to inbound messages from the Go Hub
      _subscription = _channel!.stream.listen(
        (data) {
          _onDataReceived(data);
        },
        onError: (error) {
          dev.log('[WebSocket] Error: $error', name: 'WebSocketService');
          _handleDisconnect();
        },
        onDone: () {
          dev.log('[WebSocket] Connection closed', name: 'WebSocketService');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      _setState(WebSocketConnectionState.connected);
      _reconnectTimer?.cancel();
    } catch (e) {
      dev.log('[WebSocket] Connection failure: $e', name: 'WebSocketService');
      _handleDisconnect();
    }
  }

  void _onDataReceived(dynamic raw) {
    try {
      final Map<String, dynamic> data = jsonDecode(raw as String);
      dev.log('[WebSocket] Received payload: $data', name: 'WebSocketService');
      _messageStreamController.add(data);
    } catch (e) {
      dev.log('[WebSocket] Failed to parse JSON message: $e', name: 'WebSocketService');
    }
  }

  void _handleDisconnect() {
    _cleanupChannel();
    _setState(WebSocketConnectionState.disconnected);

    // Auto-reconnect after 3 seconds if user was previously connected
    if (_currentUserId != null && (_reconnectTimer == null || !_reconnectTimer!.isActive)) {
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (_currentUserId != null && _state == WebSocketConnectionState.disconnected) {
          dev.log('[WebSocket] Attempting auto-reconnect...', name: 'WebSocketService');
          connect(userId: _currentUserId!, userName: _currentUserName ?? 'User');
        }
      });
    }
  }

  void _cleanupChannel() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _setState(WebSocketConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// Sends a raw JSON object over the active WebSocket channel
  bool sendRaw(Map<String, dynamic> payload) {
    if (_channel == null || _state != WebSocketConnectionState.connected) {
      dev.log('[WebSocket] Cannot send message: socket is not connected', name: 'WebSocketService');
      return false;
    }

    try {
      final jsonString = jsonEncode(payload);
      _channel!.sink.add(jsonString);
      dev.log('[WebSocket] Sent: $jsonString', name: 'WebSocketService');
      return true;
    } catch (e) {
      dev.log('[WebSocket] Failed to send payload: $e', name: 'WebSocketService');
      return false;
    }
  }

  /// 💬 1. Send typed chat message to a specific recipient (with optional E2EE Double Ratchet payload)
  bool sendDirectMessage({
    required String id,
    required String to,
    required String content,
    Map<String, dynamic>? payload,
  }) {
    return sendRaw({
      'type': 'direct',
      'id': id,
      'to': to,
      'content': content,
      if (payload != null) 'payload': payload,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 📞 2. Send WebRTC SDP Offer to initiate peer call
  bool sendWebRTCOffer({
    required String to,
    required dynamic sdp,
    bool isVideo = false,
  }) {
    return sendRaw({
      'type': 'offer',
      'to': to,
      'content': isVideo ? 'video' : 'audio',
      'payload': {
        'sdp': sdp,
        'isVideo': isVideo,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 📞 3. Send WebRTC SDP Answer to accept call
  bool sendWebRTCAnswer({
    required String to,
    required dynamic sdp,
  }) {
    return sendRaw({
      'type': 'answer',
      'to': to,
      'payload': {
        'sdp': sdp,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 📞 4. Send ICE Candidate for NAT traversal
  bool sendIceCandidate({
    required String to,
    required Map<String, dynamic> candidate,
  }) {
    return sendRaw({
      'type': 'ice-candidate',
      'to': to,
      'payload': candidate,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 📞 5. Send Call Hangup
  bool sendCallHangup({required String to}) {
    return sendRaw({
      'type': 'call_hangup',
      'to': to,
      'content': 'Call ended',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 📞 6. Send Call Reject
  bool sendCallReject({required String to, String reason = 'Declined'}) {
    return sendRaw({
      'type': 'call_reject',
      'to': to,
      'content': reason,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// ✍️ 7. Send Typing Indicator
  bool sendTyping({required String to}) {
    return sendRaw({
      'type': 'typing',
      'to': to,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Disconnects from WebSocket cleanly
  void disconnect() {
    _currentUserId = null;
    _currentUserName = null;
    _reconnectTimer?.cancel();
    _cleanupChannel();
    _setState(WebSocketConnectionState.disconnected);
  }

  @override
  void dispose() {
    disconnect();
    _messageStreamController.close();
    super.dispose();
  }
}
