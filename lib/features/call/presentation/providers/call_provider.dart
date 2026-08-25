import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/call_log.dart';
import '../../domain/usecases/get_call_logs.dart';
import '../screens/calling_screen.dart';

class CallProvider extends ChangeNotifier {
  final GetCallLogs _getCallLogs;
  final WebSocketService? _wsService;
  final GlobalKey<NavigatorState>? _navigatorKey;

  List<CallLog> _callLogs = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _wsSubscription;

  // Active Call State
  bool _isInCall = false;
  String? _activePeerId;
  String? _activePeerName;
  bool _isActiveCallVideo = false;

  CallProvider({
    required GetCallLogs getCallLogs,
    WebSocketService? wsService,
    GlobalKey<NavigatorState>? navigatorKey,
  })  : _getCallLogs = getCallLogs,
        _wsService = wsService,
        _navigatorKey = navigatorKey {
    _initWebSocketListener();
  }

  List<CallLog> get callLogs => _callLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInCall => _isInCall;
  String? get activePeerId => _activePeerId;
  String? get activePeerName => _activePeerName;
  bool get isActiveCallVideo => _isActiveCallVideo;

  void _initWebSocketListener() {
    if (_wsService == null) return;

    _wsSubscription = _wsService!.messageStream.listen((data) {
      final type = data['type'] as String?;

      if (type == 'offer') {
        _handleIncomingOffer(data);
      } else if (type == 'call_hangup' || type == 'call_reject') {
        _handleCallEnded(data);
      }
    });
  }

  /// 📞 3. Trigger CallingScreen UI automatically when incoming WebRTC 'offer' payload is received
  void _handleIncomingOffer(Map<String, dynamic> data) {
    final callerId = data['from'] as String? ?? 'Unknown';
    final callerName = data['from'] as String? ?? 'Caller';
    final isVideo = data['content'] == 'video' || (data['payload']?['isVideo'] == true);

    _isInCall = true;
    _activePeerId = callerId;
    _activePeerName = callerName;
    _isActiveCallVideo = isVideo;
    notifyListeners();

    // Add to call history as incoming call
    _callLogs.insert(
      0,
      CallLog(
        id: 'call_${DateTime.now().millisecondsSinceEpoch}',
        callerId: callerId,
        callerName: callerName,
        timestamp: DateTime.now(),
        direction: CallDirection.incoming,
        type: isVideo ? CallType.video : CallType.audio,
      ),
    );

    // Trigger UI automatically via root navigator
    final nav = _navigatorKey?.currentState ?? AppRouter.rootNavigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (context) => CallingScreen(
            callId: 'call_${DateTime.now().millisecondsSinceEpoch}',
            callerName: callerName,
            isVideo: isVideo,
          ),
        ),
      );
    }
  }

  void _handleCallEnded(Map<String, dynamic> data) {
    _isInCall = false;
    _activePeerId = null;
    _activePeerName = null;
    notifyListeners();

    final nav = _navigatorKey?.currentState ?? AppRouter.rootNavigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }

  /// Initiates an outgoing WebRTC call
  void startCall({
    required BuildContext context,
    required String peerId,
    required String peerName,
    bool isVideo = false,
  }) {
    _isInCall = true;
    _activePeerId = peerId;
    _activePeerName = peerName;
    _isActiveCallVideo = isVideo;
    notifyListeners();

    // Send WebRTC offer over WebSocket
    _wsService?.sendWebRTCOffer(
      to: peerId,
      sdp: 'mock_sdp_offer_payload',
      isVideo: isVideo,
    );

    // Open Calling Screen
    context.push('/call/$peerId?name=$peerName&isVideo=$isVideo');
  }

  /// Hangs up active call
  void hangup() {
    if (_activePeerId != null) {
      _wsService?.sendCallHangup(to: _activePeerId!);
    }
    _isInCall = false;
    _activePeerId = null;
    _activePeerName = null;
    notifyListeners();
  }

  Future<void> loadCallLogs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _callLogs = await _getCallLogs(const NoParams());
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}
