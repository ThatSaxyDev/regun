import 'package:flutter/material.dart';
import 'package:regun/navigation/game_page_route.dart';

/// Allowlisted tap destinations. Anything unknown opens nothing, and no route
/// can start a run: a notification may only surface a read-only screen.
abstract final class PushRoute {
  static const home = 'home';
  static const collection = 'collection';
  static const leaderboards = 'leaderboards';
  static const settings = 'settings';
  static const store = 'store';
  static const account = 'account';
  static const online = 'online';

  static const all = {
    home,
    collection,
    leaderboards,
    settings,
    store,
    account,
    online,
  };
}

/// Resolves a push payload to a screen without interrupting an active run.
/// The screen mapping is injected so this file never imports the view tree.
class PushRouter {
  PushRouter(this.navigatorKey, this.screenFor);
  final GlobalKey<NavigatorState>? navigatorKey;
  final Widget Function(String route)? screenFor;
  Map<String, dynamic>? _pending;

  void handle(Map<String, dynamic>? data) {
    if (data == null) return;
    final route = data['route'];
    if (route is! String || !PushRoute.all.contains(route)) return;
    final param = data['routeParam'];
    if (param != null && (param is! String || param.length > 64)) return;
    final navigator = navigatorKey?.currentState;
    if (navigator == null) {
      // Cold start: the tap can arrive before the first frame.
      _pending = data;
      return;
    }
    if (navigator.canPop()) return; // Mid-run or mid-flow; do not interrupt.
    final screen = screenFor?.call(route);
    if (screen == null) return;
    navigator.push(GamePageRoute(builder: (_) => screen));
  }

  /// Called after the first frame so a cold-start tap is not lost.
  void flush() {
    final pending = _pending;
    _pending = null;
    if (pending != null) handle(pending);
  }
}
