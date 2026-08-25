import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../widgets/call_action_button.dart';

class CallingScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String? avatarUrl;
  final bool isVideo;

  const CallingScreen({
    super.key,
    required this.callId,
    required this.callerName,
    this.avatarUrl,
    this.isVideo = false,
  });

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen>
    with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoEnabled = false;
  bool _isFrontCamera = true;
  String _callStatus = 'Calling...';
  int _secondsElapsed = 0;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _isVideoEnabled = widget.isVideo;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Simulate call connection after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _callStatus = 'Connected';
        });
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _secondsElapsed > 0 ? _formatDuration(_secondsElapsed) : _callStatus;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1E1C),
      body: Stack(
        children: [
          // Background Gradient / Video Simulation
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E3A34),
                    Color(0xFF0F1E1C),
                    Color(0xFF071110),
                  ],
                ),
              ),
              child: _isVideoEnabled
                  ? Center(
                      child: Icon(
                        Icons.videocam,
                        size: 100,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    )
                  : null,
            ),
          ),

          // Header with lock icon and end-to-end encrypted tag
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                          onPressed: () => context.pop(),
                        ),
                        Row(
                          children: const [
                            Icon(Icons.lock, size: 14, color: AppColors.primaryLight),
                            SizedBox(width: 4),
                            Text(
                              'End-to-end encrypted',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_add_outlined, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Center Avatar with pulsating ring animation
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: EdgeInsets.all(12 + (_pulseController.value * 10)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.12 - (_pulseController.value * 0.08)),
                  ),
                  child: UserAvatar(
                    name: widget.callerName,
                    imageUrl: widget.avatarUrl,
                    radius: 65,
                  ),
                );
              },
            ),
          ),

          // Floating mini self-view if video enabled
          if (_isVideoEnabled)
            Positioned(
              top: 130,
              right: 16,
              child: Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3942),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white54, size: 40),
                ),
              ),
            ),

          // In-call Control Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              decoration: const BoxDecoration(
                color: Color(0xAA121B22),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CallActionButton(
                          icon: _isSpeaker ? Icons.volume_up : Icons.volume_off,
                          label: 'Speaker',
                          isActive: _isSpeaker,
                          onTap: () {
                            setState(() {
                              _isSpeaker = !_isSpeaker;
                            });
                          },
                        ),
                        CallActionButton(
                          icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                          label: 'Video',
                          isActive: _isVideoEnabled,
                          onTap: () {
                            setState(() {
                              _isVideoEnabled = !_isVideoEnabled;
                            });
                          },
                        ),
                        CallActionButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          label: 'Mute',
                          isActive: _isMuted,
                          onTap: () {
                            setState(() {
                              _isMuted = !_isMuted;
                            });
                          },
                        ),
                        if (_isVideoEnabled)
                          CallActionButton(
                            icon: Icons.flip_camera_ios,
                            label: 'Flip',
                            onTap: () {
                              setState(() {
                                _isFrontCamera = !_isFrontCamera;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // End Call button
                    FloatingActionButton.large(
                      heroTag: 'end_call_btn',
                      backgroundColor: const Color(0xFFEA4335),
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      onPressed: () {
                        context.pop();
                      },
                      child: const Icon(Icons.call_end, size: 36),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
