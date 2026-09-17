import 'dart:async';
import 'package:flutter/services.dart';

class VideoCallManager {
  static const MethodChannel _channel = MethodChannel('com.callvyn.video');
  static const EventChannel _eventChannel = EventChannel('com.callvyn.video/events');

  static Stream<Map<String, dynamic>>? _eventStream;

  static Stream<Map<String, dynamic>> get onVideoEvent {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }

  /// Check if device + network supports ViLTE
  static Future<bool> isVideoCapable({int subscriptionId = 0}) async {
    try {
      final res = await _channel.invokeMethod<bool>('isVideoCapable', {
        'subscriptionId': subscriptionId,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Place outgoing native IMS video call
  static Future<void> placeVideoCall({
    required String phoneNumber,
    int subscriptionId = 0,
  }) async {
    try {
      await _channel.invokeMethod('placeVideoCall', {
        'phoneNumber': phoneNumber,
        'subscriptionId': subscriptionId,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Upgrade existing audio call to video (mid-call)
  static Future<void> upgradeToVideo() async {
    try {
      await _channel.invokeMethod('upgradeToVideo');
    } catch (e) {
      rethrow;
    }
  }

  /// Downgrade video call to audio-only
  static Future<void> downgradeToAudio() async {
    try {
      await _channel.invokeMethod('downgradeToAudio');
    } catch (e) {
      rethrow;
    }
  }

  /// Switch front/back camera
  static Future<void> toggleCamera() async {
    try {
      await _channel.invokeMethod('toggleCamera');
    } catch (e) {
      rethrow;
    }
  }

  /// Mute/unmute video stream
  static Future<void> setVideoMuted(bool muted) async {
    try {
      await _channel.invokeMethod('setVideoMuted', {'muted': muted});
    } catch (e) {
      rethrow;
    }
  }

  /// End video call
  static Future<void> endCall() async {
    try {
      await _channel.invokeMethod('endCall');
    } catch (e) {
      rethrow;
    }
  }

  /// Get current video state
  static Future<int> getVideoState() async {
    try {
      final res = await _channel.invokeMethod<int>('getVideoState');
      return res ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Accept incoming video upgrade request
  static Future<void> acceptVideoUpgrade() async {
    try {
      await _channel.invokeMethod('acceptVideoUpgrade');
    } catch (e) {
      rethrow;
    }
  }

  /// Decline incoming video upgrade request
  static Future<void> declineVideoUpgrade() async {
    try {
      await _channel.invokeMethod('declineVideoUpgrade');
    } catch (e) {
      rethrow;
    }
  }
}
