import 'package:flutter/material.dart';
import '../services/video_call_manager.dart';

class VideoCallScreen extends StatefulWidget {
  final String phoneNumber;
  final String callerName;
  final bool isIncoming;
  final int subscriptionId;

  const VideoCallScreen({
    super.key,
    required this.phoneNumber,
    required this.callerName,
    this.isIncoming = false,
    this.subscriptionId = 0,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver {
  bool isMuted = false;
  bool isCameraOn = true;
  bool isFrontCamera = true;
  bool isCallConnected = false;
  String callStatus = 'Connecting...';

  // Texture IDs or direct PlatformViews
  int? localTextureId;
  int? remoteTextureId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToVideoEvents();

    if (!widget.isIncoming) {
      _placeOutgoingCall();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _placeOutgoingCall() async {
    final capable = await VideoCallManager.isVideoCapable(
      subscriptionId: widget.subscriptionId,
    );

    if (!capable) {
      if (mounted) {
        setState(() {
          callStatus = 'Video calling not supported';
        });
      }
      return;
    }

    await VideoCallManager.placeVideoCall(
      phoneNumber: widget.phoneNumber,
      subscriptionId: widget.subscriptionId,
    );
  }

  void _listenToVideoEvents() {
    VideoCallManager.onVideoEvent.listen((event) {
      final eventType = event['event'] as String? ?? '';
      final data = Map<String, dynamic>.from((event['data'] as Map?) ?? {});

      if (!mounted) return;

      setState(() {
        switch (eventType) {
          case 'callProgressing':
            callStatus = 'Ringing...';
            break;
          case 'callConnected':
            isCallConnected = true;
            callStatus = 'Connected';
            break;
          case 'callTerminated':
            callStatus = 'Call ended';
            _closeCall();
            break;
          case 'callModified':
            _updateVideoState(data['videoDirection'] as int? ?? 0);
            break;
          case 'error':
            callStatus = 'Error: ${data['message']}';
            _showError(data['message'] as String? ?? 'Video call error');
            break;
        }
      });
    });
  }

  void _updateVideoState(int direction) {
    // DIRECTION_INACTIVE = 0 (no video)
    // DIRECTION_SEND_ONLY = 1 (only sending)
    // DIRECTION_RECEIVE_ONLY = 2 (only receiving)
    // DIRECTION_SEND_RECEIVE = 3 (bidirectional)
    setState(() {
      isCameraOn = direction != 2; // Not receive-only
    });
  }

  void _closeCall() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen native Hardware Texture/PlatformView)
          Positioned.fill(
            child: isCallConnected
                ? const AndroidView(
                    viewType: 'com.sonoou.callvyndialer/remote_video_view',
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[800],
                          child: Text(
                            widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 40, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.callerName.isNotEmpty ? widget.callerName : widget.phoneNumber,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          callStatus,
                          style: const TextStyle(color: Colors.white60, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
          ),

          // Local camera preview (small PIP floating overlay)
          if (isCameraOn)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: const AndroidView(
                    viewType: 'com.sonoou.callvyndialer/local_video_view',
                  ),
                ),
              ),
            ),

          // Call controls (Bottom Bar)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ControlButton(
                  icon: isMuted ? Icons.mic_off : Icons.mic,
                  onTap: () {
                    setState(() => isMuted = !isMuted);
                    VideoCallManager.setVideoMuted(isMuted);
                  },
                ),
                _ControlButton(
                  icon: isCameraOn ? Icons.videocam : Icons.videocam_off,
                  onTap: () {
                    setState(() => isCameraOn = !isCameraOn);
                    VideoCallManager.setVideoMuted(!isCameraOn);
                  },
                ),
                _ControlButton(
                  icon: Icons.switch_camera,
                  onTap: () {
                    setState(() => isFrontCamera = !isFrontCamera);
                    VideoCallManager.toggleCamera();
                  },
                ),
                _ControlButton(
                  icon: Icons.call_end,
                  isEndCall: true,
                  onTap: () {
                    VideoCallManager.endCall();
                    _closeCall();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isEndCall;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.isEndCall = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isEndCall ? Colors.red : Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
