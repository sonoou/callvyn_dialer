import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/contact.dart';
import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';
import 'text_viewer_screen.dart';

class InCallScreen extends StatefulWidget {
  const InCallScreen({super.key});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> with SingleTickerProviderStateMixin {
  bool _showKeypad = false;
  bool _showNoteField = false;
  bool _cameraClosed = false;
  bool _isBackCamera = false;
  final TextEditingController _noteController = TextEditingController();
  String _dtmfInput = '';
  late final AnimationController _incomingAnimController;
  late final Animation<double> _redButtonAnimation;
  late final Animation<double> _greenButtonAnimation;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _noteController.addListener(() {
      if (mounted && _showNoteField) setState(() {});
    });

    _incomingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      value: 0.0,
    );

    // Red button: 1st flow: bottom to top slide animation to length of 10dp from current position
    _redButtonAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -10.0).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -10.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_incomingAnimController);

    // Green button: 1st flow: bottom to top slide 80dp, then 2nd flow: top to bottom drop effect like tennis ball with 3 reducing dips
    _greenButtonAnimation = TweenSequence<double>([
      // 1st flow: Slide up 80dp
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -80.0).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      // 2nd flow: Drop down 80dp (tennis ball drop)
      TweenSequenceItem(
        tween: Tween<double>(begin: -80.0, end: 0.0).chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 18,
      ),
      // Dip 1: bounce up ~40dp and drop
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -40.0).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -40.0, end: 0.0).chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 14,
      ),
      // Dip 2: bounce up ~18dp and drop
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -18.0).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -18.0, end: 0.0).chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 10,
      ),
      // Dip 3: bounce up ~7dp and drop
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -7.0).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 6,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -7.0, end: 0.0).chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 6,
      ),
    ]).animate(_incomingAnimController);

    // Edge-to-edge full screen with transparent status bar and nav bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<DialerProvider>(context, listen: false);
      if (provider.callStatus == ActiveCallStatus.incoming) {
        // Start animation ONLY AFTER the incoming call UI is fully presented and painted on screen
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && provider.callStatus == ActiveCallStatus.incoming && !_incomingAnimController.isAnimating) {
            _incomingAnimController.repeat();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _incomingAnimController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatTimer(int totalSecs) {
    final mins = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSecs % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _onDtmfKey(String key, DialerProvider provider) {
    setState(() {
      _dtmfInput += key;
    });
    provider.sendInCallDtmf(key);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context);

    final Contact? contact = provider.findContactByNumber(provider.activeCallNumber);

    final bool isSaved = contact != null || (provider.activeCallName != null && provider.activeCallName!.isNotEmpty);
    final String contactName = contact?.name ?? provider.activeCallName ?? '';
    final String displayName = isSaved ? contactName : provider.activeCallNumber;
    final String displayPhone = provider.activeCallNumber;

    final isIncoming = provider.callStatus == ActiveCallStatus.incoming;
    final isRinging = provider.callStatus == ActiveCallStatus.outgoing;
    final isAnswered = provider.callStatus == ActiveCallStatus.active;
    final isEnded = provider.callStatus == ActiveCallStatus.ended;

    if (!isIncoming && _incomingAnimController.isAnimating) {
      _incomingAnimController.stop();
      _incomingAnimController.value = 0.0;
    } else if (isIncoming && !_incomingAnimController.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.callStatus == ActiveCallStatus.incoming && !_incomingAnimController.isAnimating) {
          _incomingAnimController.repeat();
        }
      });
    }

    final String callStatusText = isEnded
        ? 'Call Ended'
        : (isIncoming
            ? (provider.isVideoCall ? 'Incoming video call' : 'Incoming call')
            : (isRinging
                ? (provider.isVideoCall ? 'DIALLING VIDEO...' : 'DIALLING')
                : _formatTimer(provider.callDurationSeconds)));

    final String simIcon = provider.activeSimSlot == 1
        ? 'resources/bh_ic_sim_one.png'
        : 'resources/bh_ic_sim_two.png';

    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.black, // Full screen edge-to-edge AMOLED Black
          body: Stack(
          fit: StackFit.expand,
          children: [
            // Background Layer: Pure AMOLED Black
            Container(color: Colors.black),

            // Remote Video Stream (Full Screen)
            if (provider.isVideoCall && (isAnswered || isRinging))
              const Positioned.fill(
                child: AndroidView(
                  viewType: 'com.sonoou.callvyndialer/remote_video_view',
                ),
              ),

            // Image overlay layer: Subtle readability gradient for video calls
            if (provider.isVideoCall)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: isAnswered ? 0.35 : 0.55),
                      Colors.transparent,
                      Colors.black.withValues(alpha: isAnswered ? 0.55 : 0.70),
                    ],
                    stops: const [0.0, 0.40, 1.0],
                  ),
                ),
              ),

            // In-Call Content Column (Full-screen, no SafeArea wrapping)
            Padding(
              padding: EdgeInsets.only(
                top: topPadding + (isAnswered && provider.isVideoCall ? 12 : 28),
                bottom: bottomPadding + 45,
                left: 24,
                right: 24,
              ),
              child: Column(
                children: [
                  if (isAnswered && provider.isVideoCall) ...[
                    // ---------------------------------------------------------
                    // ACTIVE VIDEO CALL TOP BAR:
                    // Left: Compact Caller Name & Timer, Right: Space for Floating PIP
                    // ---------------------------------------------------------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName.isNotEmpty ? displayName : 'Unknown contact',
                                style: const TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (provider.isDualSim) ...[
                                    Image.asset(
                                      simIcon,
                                      width: 12,
                                      height: 14,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    callStatusText,
                                    style: const TextStyle(
                                      fontFamily: MiuiTheme.fontFamily,
                                      fontSize: 14,
                                      color: Color(0xFF34C759),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0C84FF).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'HD',
                                      style: TextStyle(
                                        fontFamily: MiuiTheme.fontFamily,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0C84FF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Margin for the Floating PIP box on top-right
                        const SizedBox(width: 115),
                      ],
                    ),
                  ] else ...[
                    // ---------------------------------------------------------
                    // VOICE CALL OR INCOMING VIDEO CALL HEADER
                    // ---------------------------------------------------------
                    Center(
                      child: Image.asset(
                        'resources/contact_detail_circle_photo_night.png',
                        width: 88,
                        height: 88,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Center(
                      child: Text(
                        displayName.isNotEmpty ? displayName : 'Unknown contact',
                        style: const TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 28,
                          fontWeight: FontWeight.normal,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (provider.isDualSim) ...[
                          Image.asset(
                            simIcon,
                            width: 14,
                            height: 16,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          displayPhone,
                          style: const TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 16,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    Center(
                      child: Text(
                        callStatusText,
                        style: const TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ),

                    if (provider.isVideoCall) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C84FF).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0C84FF).withValues(alpha: 0.6), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam_rounded, color: Color(0xFF0C84FF), size: 14),
                            SizedBox(width: 5),
                            Text(
                              'HD Video Call',
                              style: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0C84FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // ---------------------------------------------------------
                  // INCOMING CALL UI vs ACTIVE/OUTGOING IN-CALL UI
                  // ---------------------------------------------------------
                  if (isIncoming || (provider.isIncomingSession && !isAnswered)) ...[
                    // 5TH ROW: Gap / Spacer
                    const Spacer(),

                    // 6TH ROW: Incoming Call Action Buttons (Red Reject & Green Accept)
                    if (isIncoming)
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _incomingAnimController,
                          builder: (context, child) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 1st column: Red Hang Up / Reject Button
                                Transform.translate(
                                  offset: Offset(0, _redButtonAnimation.value),
                                  child: _DraggableCallButton(
                                    onTriggered: () => provider.endCall(),
                                    child: Container(
                                      width: 66,
                                      height: 66,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF3B30),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black45,
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Transform.rotate(
                                        angle: -45 * 3.141592653589793 / 180, // 45 deg anti-clockwise
                                        child: Image.asset(
                                          'resources/call_hang_up.webp',
                                          width: 34,
                                          height: 34,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Gap between red and green buttons
                                const SizedBox(width: 80),

                                 // 2nd column: Green Accept / Pick Up Button
                                Transform.translate(
                                  offset: Offset(0, _greenButtonAnimation.value),
                                  child: _DraggableCallButton(
                                    onTriggered: () {
                                      provider.answerCall(asVideo: provider.isVideoCall);
                                    },
                                    child: Container(
                                      width: 66,
                                      height: 66,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF25D366),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black45,
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: provider.isVideoCall
                                          ? const Icon(
                                              Icons.videocam_rounded,
                                              color: Colors.white,
                                              size: 34,
                                            )
                                          : Image.asset(
                                              'resources/contact_details_dialer_btn_call.webp',
                                              width: 34,
                                              height: 34,
                                              fit: BoxFit.contain,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      const SizedBox(height: 66),
                  ] else if (isAnswered || isRinging || (isEnded && !provider.isIncomingSession)) ...[
                    // In-Call Keypad Overlay OR (Note field + Action rows)
                    if (_showKeypad)
                      Expanded(
                        child: _buildInCallKeypad(context, provider),
                      )
                    else ...[
                      // Space between "DIALLING" (Row 4) and Row 6 (Last 3rd row)
                      if (_showNoteField)
                        Expanded(
                          child: _buildInCallNoteField(context, provider, displayName, displayPhone),
                        )
                      else ...[
                        const SizedBox(height: 60),
                        const Spacer(),
                      ],

                      if (provider.isVideoCall) ...[
                        // ---------------------------------------------------------
                        // VIDEO CALL ROWS (from outgoing_video_call.txt):
                        // 6th row: Hold (call-hold.svg), Add call (plus.svg), Mute (mic-mute.svg)
                        // ---------------------------------------------------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCallActionButton(
                              iconPath: 'resources/call-hold.svg',
                              label: 'Hold',
                              isEnabled: !isRinging,
                              isActive: provider.isOnHold,
                              onTap: () {
                                if (!isRinging) provider.toggleHold();
                              },
                            ),
                            _buildCallActionButton(
                              iconPath: 'resources/plus.svg',
                              label: 'Add call',
                              isEnabled: !isRinging,
                              isActive: false,
                              onTap: () {
                                if (!isRinging) {
                                  setState(() {
                                    _showKeypad = true;
                                    _showNoteField = false;
                                  });
                                }
                              },
                            ),
                            _buildCallActionButton(
                              iconPath: 'resources/mic-mute.svg',
                              label: 'Mute',
                              isEnabled: !isRinging,
                              isActive: provider.isMuted,
                              onTap: () {
                                if (!isRinging) provider.toggleMute();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 35),

                        // ---------------------------------------------------------
                        // 7th row: Voice call (call-circle-border.svg), Close (camera-close.svg), Switch (camera-switch.svg)
                        // ---------------------------------------------------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCallActionButton(
                              iconPath: 'resources/call-circle-border.svg',
                              label: 'Voice call',
                              isEnabled: !isRinging,
                              isActive: false,
                              onTap: () {
                                if (!isRinging) {
                                  provider.switchToVoiceCall();
                                }
                              },
                            ),
                            _buildCallActionButton(
                              iconPath: 'resources/camera-close.svg',
                              label: 'Close',
                              isEnabled: !isRinging,
                              isActive: _cameraClosed,
                              onTap: () {
                                if (!isRinging) {
                                  setState(() => _cameraClosed = !_cameraClosed);
                                }
                              },
                            ),
                            _buildCallActionButton(
                              iconPath: 'resources/camera-switch.svg',
                              label: 'Switch',
                              isEnabled: !isRinging,
                              isActive: _isBackCamera,
                              onTap: () {
                                if (!isRinging) {
                                  setState(() => _isBackCamera = !_isBackCamera);
                                  provider.switchCamera(useBack: _isBackCamera);
                                }
                              },
                            ),
                          ],
                        ),

                        // 8th row: Gap 15dp
                        const SizedBox(height: 15),
                      ] else ...[
                        // ---------------------------------------------------------
                        // VOICE CALL ROWS:
                        // 6TH ROW: Video call, Add call, Note
                        // ---------------------------------------------------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCallActionButton(
                              iconPath: 'resources/video-icon.svg',
                              label: 'Video call',
                              isEnabled: !isRinging,
                              isActive: false,
                              onTap: () {
                                if (!isRinging && provider.activeCallNumber.isNotEmpty) {
                                  provider.placeVideoCall(provider.activeCallNumber);
                                }
                              },
                            ),
                            _buildCallActionButton(
                              iconPath: 'resources/plus.svg',
                              label: 'Add call',
                              isEnabled: !isRinging,
                              isActive: false,
                              onTap: () {
                                if (!isRinging) {
                                  setState(() {
                                    _showKeypad = true;
                                    _showNoteField = false;
                                  });
                                }
                              },
                            ),
                            _buildCallActionButton(
                              iconPath: 'resources/edit.svg',
                              label: 'Note',
                              isEnabled: true,
                              isActive: _showNoteField,
                              onTap: () {
                                setState(() {
                                  _showNoteField = !_showNoteField;
                                  if (_showNoteField) _showKeypad = false;
                                });
                              },
                            ),
                          ],
                        ),

                        // Gap increased by 5dp: 30 -> 35
                        const SizedBox(height: 35),

                        // ---------------------------------------------------------
                        // 7TH ROW: Mute, Hold, Record
                        // ---------------------------------------------------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCallActionButton(
                              iconPath: 'resources/mic-mute.svg',
                              label: 'Mute',
                              isEnabled: !isRinging,
                              isActive: provider.isMuted,
                              onTap: () {
                                if (!isRinging) {
                                  provider.toggleMute();
                                }
                              },
                            ),
                            _buildCallActionButton(
                              iconPath: 'resources/call-hold.svg',
                              label: 'Hold',
                              isEnabled: !isRinging,
                              isActive: provider.isOnHold,
                              onTap: () {
                                if (!isRinging) {
                                  provider.toggleHold();
                                }
                              },
                            ),
                            _buildCallActionButton(
                              iconPath: 'resources/call-record.svg',
                              label: provider.isRecording
                                  ? _formatTimer(provider.recordingSeconds)
                                  : 'Record',
                              isEnabled: isAnswered,
                              isActive: provider.isRecording,
                              onTap: () {
                                if (isAnswered) {
                                  provider.toggleRecording(
                                    contactName: displayName,
                                    contactNumber: displayPhone,
                                    context: context,
                                  );
                                }
                              },
                            ),
                          ],
                        ),

                        // ---------------------------------------------------------
                        // 8TH ROW: Gap 58dp
                        // ---------------------------------------------------------
                        const SizedBox(height: 58),
                      ],
                    ],

                    // ---------------------------------------------------------
                    // 9TH ROW: (Background color: none)
                    // 1st col: Speaker (speaker.svg, blue on active)
                    // 2nd col: Hang Up (call_hang_up.webp rotated 50 deg anti-clockwise, red circle 66x66)
                    // 3rd col: Keypad (dots-nine.svg, blue when open)
                    // ---------------------------------------------------------
                    Container(
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1st column: Speaker Button
                          _buildBottomIconButton(
                            iconPath: 'resources/speaker.svg',
                            isActive: provider.isSpeaker,
                            onTap: () => provider.toggleSpeaker(),
                          ),

                          // 2nd column: Red Hang Up Button (66x66 circular)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => provider.endCall(),
                            child: Container(
                              width: 66,
                              height: 66,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF3B30),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Transform.rotate(
                                angle: -45 * 3.141592653589793 / 180, // 45 deg anti-clockwise
                                child: Image.asset(
                                  'resources/call_hang_up.webp',
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),

                          // 3rd column: Keypad Button
                          _buildBottomIconButton(
                            iconPath: 'resources/dots-nine.svg',
                            isActive: _showKeypad,
                            onTap: () {
                              setState(() {
                                _showKeypad = !_showKeypad;
                                if (_showKeypad) _showNoteField = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Floating Local Video Preview (Picture-in-Picture) for Active/Dialing Video Call
            if ((isAnswered || isRinging) && provider.isVideoCall && !_cameraClosed)
              Positioned(
                top: topPadding + 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isBackCamera = !_isBackCamera);
                    provider.switchCamera(useBack: _isBackCamera);
                  },
                  child: Container(
                    width: 105,
                    height: 155,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const AndroidView(
                          viewType: 'com.sonoou.callvyndialer/local_video_view',
                        ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flip_camera_android_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Floating Video Call Upgrade Request Modal / Notification Banner
            if (provider.hasIncomingVideoUpgradeRequest)
              Positioned(
                top: topPadding + 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E22).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF0C84FF).withValues(alpha: 0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C84FF).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.videocam_rounded, color: Color(0xFF0C84FF), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Video Call Request',
                                  style: TextStyle(
                                    fontFamily: MiuiTheme.fontFamily,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${displayName.isNotEmpty ? displayName : "Caller"} requested to switch to video',
                                  style: const TextStyle(
                                    fontFamily: MiuiTheme.fontFamily,
                                    fontSize: 13,
                                    color: Color(0xFF8E8E93),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => provider.declineVideoUpgrade(),
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                'Decline',
                                style: TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF3B30),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => provider.acceptVideoUpgrade(),
                              icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                'Accept',
                                style: TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  // Action Button Widget (6th & 7th Row - Icon size 33x33)
  Widget _buildCallActionButton({
    required String iconPath,
    required String label,
    required bool isEnabled,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final Color iconColor = isActive
        ? const Color(0xFF0C84FF)
        : (isEnabled ? Colors.white : const Color(0xFF555555));

    final Color textColor = isActive
        ? const Color(0xFF0C84FF)
        : (isEnabled ? Colors.white70 : const Color(0xFF555555));

    return SizedBox(
      width: 83, // Increased by 5dp (78 -> 83)
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath,
              width: 33,
              height: 33,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: MiuiTheme.fontFamily,
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Bottom Icon Button (Speaker & Keypad)
  Widget _buildBottomIconButton({
    required String iconPath,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final Color color = isActive ? const Color(0xFF0C84FF) : Colors.white;

    return SizedBox(
      width: 66,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: SvgPicture.asset(
            iconPath,
            width: 30,
            height: 30,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  // In-Call DTMF Keypad View (no background on numbers, reduced row gap)
  Widget _buildInCallKeypad(BuildContext context, DialerProvider provider) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Top Digit Input Display
        Container(
          height: 36,
          alignment: Alignment.center,
          child: Text(
            _dtmfInput.isEmpty ? '' : _dtmfInput,
            style: const TextStyle(
              fontFamily: MiuiTheme.fontFamily,
              fontSize: 26,
              fontWeight: FontWeight.normal,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 10),
        // 3x4 Keypad Grid
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: keys.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4), // Reduced row gap
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((k) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onDtmfKey(k, provider),
                    child: Container(
                      width: 68,
                      height: 52,
                      color: Colors.transparent, // Background removed
                      alignment: Alignment.center,
                      child: Text(
                        k,
                        style: const TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 28,
                          fontWeight: FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // In-Call Full-space Note Field View (Max 100 chars with countdown)
  Widget _buildInCallNoteField(
    BuildContext context,
    DialerProvider provider,
    String displayName,
    String displayPhone,
  ) {
    final remainingChars = (100 - _noteController.text.length).clamp(0, 100);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Stack(
        children: [
          TextField(
            controller: _noteController,
            maxLines: null,
            expands: true,
            maxLength: 100,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            autofocus: true,
            style: const TextStyle(
              fontFamily: MiuiTheme.fontFamily,
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.normal,
            ),
            cursorColor: const Color(0xFF0C84FF),
            decoration: const InputDecoration(
              hintText: 'Type your note here...',
              hintStyle: TextStyle(
                fontFamily: MiuiTheme.fontFamily,
                color: Colors.white38,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(bottom: 34),
            ),
          ),
          // Bottom-left Remaining Characters Countdown
          Positioned(
            bottom: 2,
            left: 2,
            child: Text(
              '$remainingChars',
              style: TextStyle(
                fontFamily: MiuiTheme.fontFamily,
                fontSize: 12,
                color: remainingChars < 10 ? const Color(0xFFFF3B30) : const Color(0xFF8E8E93),
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          // Bottom-right Checkmark save button (with no background)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _saveNoteToFile(context, provider, displayName, displayPhone),
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.all(4),
                child: SvgPicture.asset(
                  'resources/checkmark.svg',
                  width: 26,
                  height: 26,
                  colorFilter: const ColorFilter.mode(Color(0xFF25D366), BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNoteToFile(
    BuildContext context,
    DialerProvider provider,
    String displayName,
    String displayPhone,
  ) async {
    final text = _noteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please write a note before saving'),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final nameSafe = (displayName.isNotEmpty ? displayName : 'Unknown')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
    final phoneSafe = displayPhone.replaceAll(' ', '').trim();
    final now = DateTime.now();
    final dateFormatted = DateFormat('ddMMyy_hhmm a').format(now).replaceAll(' ', '');
    final fileName = '$nameSafe($phoneSafe)_$dateFormatted.txt';

    final savedPath = await provider.saveNoteFile(fileName, text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $fileName'),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: const Color(0xFF0C84FF),
            onPressed: () {
              if (savedPath != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TextViewerScreen(filePath: savedPath),
                  ),
                );
              }
            },
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      setState(() {
        _showNoteField = false;
      });
    }
  }

}


class _DraggableCallButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTriggered;

  const _DraggableCallButton({
    required this.child,
    required this.onTriggered,
  });

  @override
  State<_DraggableCallButton> createState() => _DraggableCallButtonState();
}

class _DraggableCallButtonState extends State<_DraggableCallButton> with SingleTickerProviderStateMixin {
  double _dragOffsetY = 0.0;
  double _dragOffsetX = 0.0;
  bool _triggered = false;
  late AnimationController _springController;
  late Animation<Offset> _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _springController.addListener(() {
      if (mounted) {
        setState(() {
          _dragOffsetX = _springAnimation.value.dx;
          _dragOffsetY = _springAnimation.value.dy;
        });
      }
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _trigger() {
    if (_triggered) return;
    _triggered = true;
    HapticFeedback.mediumImpact();
    widget.onTriggered();
  }

  void _animateBack() {
    if (_triggered) return;
    _springAnimation = Tween<Offset>(
      begin: Offset(_dragOffsetX, _dragOffsetY),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic));
    _springController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // No tap trigger: Strictly require completing the full 120dp upward drag to pick/reject
      onPanStart: (_) {
        _springController.stop();
        _triggered = false;
      },
      onPanUpdate: (details) {
        if (_triggered) return;
        setState(() {
          // Strictly allow upward drag (0.0 down to -140.0 max)
          _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(-140.0, 0.0);
          _dragOffsetX = 0.0;
        });
        // Strictly trigger only when dragging upward by at least 120dp
        if (_dragOffsetY <= -120.0) {
          _trigger();
        }
      },
      onPanEnd: (details) {
        if (!_triggered) {
          // If released before reaching full 120dp upward drag, animate back
          _animateBack();
        }
      },
      onPanCancel: () {
        if (!_triggered) {
          _animateBack();
        }
      },
      child: Transform.translate(
        offset: Offset(0.0, _dragOffsetY),
        child: widget.child,
      ),
    );
  }
}
