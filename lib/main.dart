import 'dart:developer' as dev;
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:regun/views/flame_splash_view.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const FlameSplashView(),
    );
  }
}
