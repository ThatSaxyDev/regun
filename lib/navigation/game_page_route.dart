import 'package:flutter/material.dart';
import 'package:regun/services/local_preferences.dart';

const gamePageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: GamePageTransitionsBuilder(),
    TargetPlatform.iOS: GamePageTransitionsBuilder(),
    TargetPlatform.macOS: GamePageTransitionsBuilder(),
    TargetPlatform.windows: GamePageTransitionsBuilder(),
    TargetPlatform.linux: GamePageTransitionsBuilder(),
    TargetPlatform.fuchsia: GamePageTransitionsBuilder(),
  },
);

/// Covers the root route and any platform/library-created Material pages too.
class GamePageTransitionsBuilder extends PageTransitionsBuilder {
  const GamePageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      GameScreenTransition.build(context, animation, secondaryAnimation, child);
}

/// A short fade through the game's dark surface. Pages stay planted; no mobile
/// sheet slide, zoom or edge-swipe can drag the game out from under its controls.
class GamePageRoute<T> extends PageRouteBuilder<T> {
  GamePageRoute({required WidgetBuilder builder, super.settings})
    : super(
        pageBuilder: (context, _, _) => builder(context),
        transitionDuration: GameScreenTransition.enter,
        reverseTransitionDuration: GameScreenTransition.leave,
        transitionsBuilder: GameScreenTransition.build,
      );

  @override
  Duration get transitionDuration => GameScreenTransition.reduceMotion
      ? Duration.zero
      : GameScreenTransition.enter;
  @override
  Duration get reverseTransitionDuration => GameScreenTransition.reduceMotion
      ? Duration.zero
      : GameScreenTransition.leave;
}

class GameScreenTransition {
  static const enter = Duration(milliseconds: 240);
  static const leave = Duration(milliseconds: 180);
  static const surface = Color(0xff161B18);
  static bool get reduceMotion =>
      LocalPreferences.shared.reducedMotion ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations;

  static Widget build(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    if (reduceMotion || MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        if (value == 1) return child!;
        final cover = Curves.easeOutCubic.transform((value / .4).clamp(0, 1));
        final reveal = Curves.easeOutCubic.transform(
          ((value - .4) / .6).clamp(0, 1),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: Opacity(
                opacity: cover,
                child: const ColoredBox(color: surface),
              ),
            ),
            IgnorePointer(
              ignoring: reveal == 0,
              child: Opacity(opacity: reveal, child: child),
            ),
          ],
        );
      },
    );
  }
}
