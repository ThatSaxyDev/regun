import 'package:regun/widgets/game_presentation.dart';

import 'dart:developer' as dev;
import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:regun/views/flame_splash_view.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/multiplayer/secure_online_tokens.dart';

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
  if (!kIsWeb) OnlineSession.appTokens = SecureOnlineTokens();
  OnlineSession.prepareAssets = () => RegunArt.shared.load();
  Flame.device.fullScreen();
  Flame.device.setLandscape();

  try {
    await SoLoud.instance.init();
    SoLoud.instance.setVisualizationEnabled(false);
    SoLoud.instance.setGlobalVolume(1);
    SoLoud.instance.setMaxActiveVoiceCount(32);
    await SoLoud.instance.startAudioDevice();
    Logger('main').info('Soloud player and audio output started');
  } catch (error) {
    Logger('main').severe('Soloud player starting error: $error');
  }
  runApp(const ProviderScope(child: GameApp()));
}

class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> with WidgetsBindingObserver {
  StreamSubscription<AudioDeviceStartFailure>? _audioFailures;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioFailures = SoLoud.instance.audioDeviceStartFailures.listen((failure) {
      Logger('audio').warning('Audio output failed to start: $failure');
      unawaited(_resumeAudioOutput());
    });
  }

  Future<void> _resumeAudioOutput() async {
    if (!SoLoud.instance.isInitialized) return;
    try {
      // Restart the device without reinitializing or discarding loaded sounds.
      await SoLoud.instance.startAudioDevice();
    } catch (error) {
      Logger('audio').warning('Audio output unavailable: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_resumeAudioOutput());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_audioFailures?.cancel());
    SoLoud.instance.deinit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final router = goRouter();
    return MaterialApp(
      title: 'Regun',
      builder: (context, child) => GamePresentation(child: child!),
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const FlameSplashView(),
      // home: kDebugMode ? const BaseView() : const FlameSplashView(),
    );
  }
}
