import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CallvynLogger {
  static const MethodChannel _channel = MethodChannel('com.sonoou.callvyndialer/sim');
  static File? _logFile;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final now = DateTime.now();
      // Format: D_MMM_YY_hhmm_AM/PM (e.g., 8_Sep_26_0355_PM.txt)
      final day = now.day;
      final month = DateFormat('MMM').format(now);
      final year = DateFormat('yy').format(now);
      final timeStr = DateFormat('hhmm_a').format(now).toUpperCase();
      final fileName = '${day}_${month}_${year}_$timeStr.txt';

      final dir = Directory('/sdcard/callvyn_dialer');
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } catch (_) {}
      }

      if (await dir.exists()) {
        _logFile = File('${dir.path}/$fileName');
        if (!await _logFile!.exists()) {
          await _logFile!.create();
          _append(
            '==================================================\n'
            'CALLVYN DIALER FLUTTER SYSTEM & ERROR LOG\n'
            'Session: ${now.toIso8601String()}\n'
            '==================================================\n',
          );
        }
      }
    } catch (e) {
      debugPrint('CallvynLogger init error: $e');
    }
  }

  static void logFlutterError(FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    final stack = details.stack?.toString() ?? '';
    e('FlutterError', msg, error: details.exception, stackTrace: stack);
  }

  static void e(String tag, String message, {Object? error, Object? stackTrace}) {
    _write('ERROR', tag, message, error: error, stackTrace: stackTrace);
  }

  static void w(String tag, String message, {Object? error, Object? stackTrace}) {
    _write('WARN', tag, message, error: error, stackTrace: stackTrace);
  }

  static void i(String tag, String message) {
    _write('INFO', tag, message);
  }

  static void _write(
    String level,
    String tag,
    String message, {
    Object? error,
    Object? stackTrace,
  }) {
    final now = DateTime.now();
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(now);
    final errorPart = error != null ? '\nError: $error' : '';
    final stackPart = stackTrace != null ? '\nStackTrace:\n$stackTrace' : '';

    final logLine = '[$timeStr] [$level] [$tag]: $message$errorPart$stackPart';
    debugPrint(logLine);

    _append(logLine);

    // Also bridge to Android native file logger via MethodChannel
    try {
      _channel.invokeMethod('writeLog', {
        'level': level,
        'tag': tag,
        'message': '$message$errorPart',
        'stackTrace': stackTrace?.toString() ?? '',
      });
    } catch (_) {}
  }

  static void _append(String text) {
    if (_logFile != null) {
      try {
        _logFile!.writeAsStringSync('$text\n', mode: FileMode.append, flush: true);
      } catch (_) {}
    }
  }
}
