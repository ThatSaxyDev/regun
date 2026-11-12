import 'package:regun/services/scrap_store.dart';
import 'package:regun/desktop/web_landscape_prompt.dart';
import 'package:regun/desktop/desktop_menu_cursor.dart';
import 'package:flutter/services.dart';
import 'package:regun/desktop/desktop_bindings.dart';
import 'package:regun/desktop/desktop_controller.dart';
import 'package:regun/desktop/desktop_platform.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/player_registry.dart';
import 'package:regun/services/push/push_service.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/balance_repository.dart';
import 'package:regun/widgets/game_presentation.dart';
import 'package:regun/navigation/game_page_route.dart';

import 'dart:developer' as dev;
import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:regun/views/flame_splash_view.dart';
import 'package:regun/views/collection_view.dart';
import 'package:regun/views/leaderboard_view.dart';
import 'package:regun/views/settings_view.dart';
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
  ScrapStore.start();
  if (!kIsWeb) OnlineSession.appTokens = SecureOnlineTokens();
  OnlineSession.prepareAssets = () => RegunArt.shared.load();
  if (desktopInputAvailable) await DesktopBindings.shared.load();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  if (!desktopInputAvailable) {
    Flame.device.fullScreen();
    Flame.device.setLandscape();
  }

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
  LocalPreferences.shared.onProfileSaved = (owner, snapshot) => unawaited(
    PlayerRegistry.shared.record(
      owner,
      snapshot,
      active:
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    ),
  );
  AccountController.shared.onGuestAttached = (id) =>
      unawaited(PlayerRegistry.shared.linkGuest(id));
  unawaited(PlayerRegistry.shared.initialize());
  PushService.pushNavigatorKey = navigatorKey;
  PushService.pushScreenFor = (route) => switch (route) {
    'collection' => const CollectionView(),
    'leaderboards' => const LeaderboardView(),
    'settings' || 'account' => const SettingsView(),
    // Home, store and the online gate are part of the menu. Never push the
    // in-game overlay for them: BaseView is a live match, not the menu.
    _ => null,
  };
  final push = PushService.shared;
  push.accountId = () => AccountController.shared.session?.accountId;
  push.accessToken = () => AccountController.shared.accessToken();
  push.guestCredentials = () => PlayerRegistry.shared.publicCredentials();
  push.deferIdentityUntilHome();
  unawaited(push.initialize());
  unawaited(BalanceRepository.shared.start());
  runApp(const ProviderScope(child: GameApp()));
}

class GameApp extends StatefulWidget {
  const GameApp({super.key, this.reviewHome});
  final Widget? reviewHome;

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> with WidgetsBindingObserver {
  StreamSubscription<AudioDeviceStartFailure>? _audioFailures;
  Timer? _presence;
  bool _foreground = true;
  void _reportPresence() {
    final prefs = LocalPreferences.shared;
    if (prefs.profileReady) {
      unawaited(
        PlayerRegistry.shared.record(
          prefs.profileOwner,
          prefs.profile.toJson(),
          force: true,
          active: _foreground,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    final state = binding.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _syncAudioVolume();
    _presence = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground) _reportPresence();
    });
    _audioFailures = SoLoud.instance.audioDeviceStartFailures.listen((failure) {
      Logger('audio').warning('Audio output failed to start: $failure');
      unawaited(_resumeAudioOutput());
    });
  }

  Future<void> _resumeAudioOutput() async {
    if (!_foreground || !SoLoud.instance.isInitialized) return;
    try {
      // Restart the device without reinitializing or discarding loaded sounds.
      await SoLoud.instance.startAudioDevice();
    } catch (error) {
      Logger('audio').warning('Audio output unavailable: $error');
    }
  }

  void _syncAudioVolume() {
    final audio = SoLoud.instance;
    if (audio.isInitialized) audio.setGlobalVolume(_foreground ? 1 : 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Mute the engine itself so all routes and late-loading voices are covered.
    // Route pause states and the player's music/SFX levels are independent.
    _syncAudioVolume();
    _reportPresence();
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeAudioOutput());
      unawaited(BalanceRepository.shared.refresh());
      unawaited(PlayerRegistry.shared.refresh());
      unawaited(PushService.shared.syncIdentity());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presence?.cancel();
    unawaited(_audioFailures?.cancel());
    SoLoud.instance.deinit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final router = goRouter();
    return MaterialApp(
      title: 'Regun',
      builder: (context, child) => desktopInputAvailable
          ? ValueListenableBuilder<double>(
              valueListenable: DesktopBindings.shared.uiScale,
              child: DesktopController(
                child: DesktopMenuCursor(
                  child: kIsWeb ? WebLandscapePrompt(child: child!) : child!,
                ),
              ),
              builder: (context, scale, child) => GamePresentation(
                scale: DesktopBindings.textBaseline * scale,
                child: child!,
              ),
            )
          : GamePresentation(child: child!),
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true)
          .copyWith(pageTransitionsTheme: gamePageTransitionsTheme),
      home: widget.reviewHome ?? const FlameSplashView(),
      // home: kDebugMode ? const BaseView() : const FlameSplashView(),
    );
  }
}
