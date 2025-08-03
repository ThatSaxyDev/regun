import 'dart:developer' as dev;
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/flame_splash_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // await Supabase.initialize(
  //   url: 'https://izjbjeuciaxnfzrgslro.supabase.co',
  //   anonKey:
  //       'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6amJqZXVjaWF4bmZ6cmdzbHJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjUzOTIxNDgsImV4cCI6MjA0MDk2ODE0OH0.TndAMEU2RIog9J62KYFmtrb02M4KUERpe_xQ3APUD1w',
  //   realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 70),
  // );
  Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;
  Logger.root.onRecord.listen((record) {
    dev.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      zone: record.zone,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
  WidgetsFlutterBinding.ensureInitialized();
  Flame.device.fullScreen();
  Flame.device.setLandscape();

  /// Initialize the player
  await SoLoud.instance.init().then(
    (_) {
      Logger('main').info('Soloud player started');
      SoLoud.instance.setVisualizationEnabled(true);
      SoLoud.instance.setGlobalVolume(0.17);
      SoLoud.instance.setMaxActiveVoiceCount(32);
    },
    onError: (Object e) {
      Logger('main').severe('Soloud player starting error: $e');
    },
  );
  runApp(
    const ProviderScope(child: GameApp()),
  );
}

class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  @override
  void dispose() {
    SoLoud.instance.deinit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final router = goRouter();
    return MaterialApp(
      title: 'Regun',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const FlameSplashView(),
      // home: kDebugMode ? const BaseView() : const FlameSplashView(),
    );
  }
}
