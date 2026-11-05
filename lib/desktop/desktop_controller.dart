import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:regun/desktop/controller_backend.dart';

class ControllerFrame {
  const ControllerFrame(this.values);
  final List<double> values;
  double axis(int index) => values[index].clamp(-1, 1);
  double button(int index) => values[index + 4].clamp(0, 1);
  bool pressed(int index) => button(index) >= .55;
}

typedef ControllerHandler = bool Function(ControllerFrame? frame);

class DesktopController extends StatefulWidget {
  const DesktopController({super.key, required this.child});

  static final handlers = <ControllerHandler>[];
  final Widget child;

  @override
  State<DesktopController> createState() => _DesktopControllerState();
}

class _DesktopControllerState extends State<DesktopController>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  bool _reading = false;
  bool _foreground = true;
  final _menuHeld = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_poll)..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _dispatch(null);
  }

  Future<void> _poll(Duration _) async {
    if (_reading || !_foreground) return;
    _reading = true;
    try {
      final values = await readController();
      if (mounted && _foreground) {
        _dispatch(
          values != null &&
                  values.length >= 20 &&
                  values.every((value) => value.isFinite)
              ? ControllerFrame(values)
              : null,
        );
      }
    } finally {
      _reading = false;
    }
  }

  void _dispatch(ControllerFrame? frame) {
    var handled = false;
    for (final handler in DesktopController.handlers.reversed.toList()) {
      if (handler(frame)) {
        handled = true;
        break;
      }
    }
    if (frame == null) {
      _menuHeld.clear();
      return;
    }
    final next = <int>{
      for (final button in [0, 1, 12, 13, 14, 15])
        if (frame.pressed(button)) button,
      if (frame.axis(1) < -.65) 12,
      if (frame.axis(1) > .65) 13,
      if (frame.axis(0) < -.65) 14,
      if (frame.axis(0) > .65) 15,
    };
    final fresh = next.difference(_menuHeld);
    _menuHeld
      ..clear()
      ..addAll(next);
    if (handled || fresh.isEmpty) return;

    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (focus == null || context == null) return;
    if (fresh.contains(0)) {
      if (Actions.maybeFind<ActivateIntent>(context) == null) {
        focus.nextFocus();
      } else {
        Actions.maybeInvoke(context, const ActivateIntent());
      }
    } else if (fresh.contains(1)) {
      Navigator.maybeOf(context)?.maybePop();
    } else {
      for (final (button, direction) in const [
        (12, TraversalDirection.up),
        (13, TraversalDirection.down),
        (14, TraversalDirection.left),
        (15, TraversalDirection.right),
      ]) {
        if (fresh.contains(button) && !focus.focusInDirection(direction)) {
          focus.nextFocus();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }
}
