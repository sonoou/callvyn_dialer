import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/dialer_provider.dart';
import 'theme/miui_theme.dart';
import 'utils/callvyn_logger.dart';
import 'views/home_screen.dart';
import 'views/in_call_screen.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      CallvynLogger.logFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      CallvynLogger.e('PlatformDispatcherError', error.toString(), error: error, stackTrace: stack);
      return true;
    };

    // Initialize logger and orientation asynchronously in background without blocking runApp
    CallvynLogger.init();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    runApp(
      ChangeNotifierProvider(
        create: (_) => DialerProvider(),
        child: const CallvynDialerApp(),
      ),
    );
  }, (error, stack) {
    CallvynLogger.e('ZonedGuardedError', error.toString(), error: error, stackTrace: stack);
  });
}

class CallvynDialerApp extends StatelessWidget {
  const CallvynDialerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dialerProvider = Provider.of<DialerProvider>(context);

    return MaterialApp(
      title: 'Callvyn Dialer',
      debugShowCheckedModeBanner: false,
      themeMode: dialerProvider.themeMode,
      theme: MiuiTheme.lightTheme,
      darkTheme: MiuiTheme.darkTheme,
      home: dialerProvider.inCall ? const InCallScreen() : const HomeScreen(),
    );
  }
}
