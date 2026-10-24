import 'dart:math';

import 'package:flame_splash_screen/flame_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:regun/navigation/game_page_route.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/views/menu_view.dart';

class FlameSplashView extends StatefulWidget {
  const FlameSplashView({super.key});

  @override
  State<FlameSplashView> createState() => _FlameSplashViewState();
}

class _FlameSplashViewState extends State<FlameSplashView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _creator = AssetImage('assets/images/splash_image.png');
  static const _layers = [
    AssetImage('assets/layer1.png', package: 'flame_splash_screen'),
    AssetImage('assets/layer2.png', package: 'flame_splash_screen'),
    AssetImage('assets/layer3.png', package: 'flame_splash_screen'),
  ];
  // Preserve the original two 3.2-second logo beats. A cancellable ticker owns
  // their sequence, rather than the package's uncancellable delayed callbacks.
  late final AnimationController _intro =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 6400),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _openMenu();
      });
  bool _ready = false, _foreground = true, _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    // The existing startup contract stays local: no cloud request or update
    // check gates these logos. Menu retains ownership of its update flow.
    await LocalPreferences.shared.load();
    await AccountController.shared.initialize();
    if (!mounted) return;
    await Future.wait([
      precacheImage(_creator, context),
      for (final layer in _layers) precacheImage(layer, context),
    ]);
    if (!mounted) return;
    setState(() => _ready = true);
    if (_foreground) _intro.forward();
  }

  void _openMenu() {
    if (!mounted || !_ready || !_foreground || _opened) return;
    _opened = true;
    Navigator.of(context)
        .pushReplacement(GamePageRoute<void>(builder: (_) => const MenuView()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
    if (!_foreground) {
      _intro.stop(canceled: false);
    } else if (_ready) {
      if (_intro.isCompleted) {
        _openMenu();
      } else {
        _intro.forward();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced =
        LocalPreferences.shared.reducedMotion ||
        MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (_, constraints) => Center(
            child: SizedBox.square(
              dimension: min(300, constraints.biggest.shortestSide),
              child: !_ready
                  ? const SizedBox.shrink()
                  : AnimatedBuilder(
                      animation: _intro,
                      builder: (context, _) {
                        final creator = _intro.value >= .5;
                        final milliseconds = (_intro.value * 6400) % 3200;
                        final opacity = reduced
                            ? 1.0
                            : milliseconds < 750
                            ? milliseconds / 750
                            : milliseconds < 2750
                            ? 1.0
                            : (3200 - milliseconds) / 450;
                        return Semantics(
                          image: true,
                          label: creator ? 'godKiishi' : 'Flame game engine',
                          child: Opacity(
                            opacity: opacity.clamp(0, 1),
                            child: creator
                                ? const Image(
                                    key: Key('startup-godkiishi'),
                                    image: _creator,
                                    fit: BoxFit.contain,
                                    excludeFromSemantics: true,
                                  )
                                : TickerMode(
                                    enabled: _foreground && !reduced,
                                    child: reduced
                                        ? const AnimatedLogo(
                                            key: Key('startup-flame'),
                                            animation: AlwaysStoppedAnimation(
                                              1,
                                            ),
                                          )
                                        : const LogoComposite(
                                            key: Key('startup-flame'),
                                          ),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
