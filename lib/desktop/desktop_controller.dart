import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/desktop/controller_backend.dart';
import 'package:regun/desktop/controller_device.dart';
import 'package:regun/desktop/controller_menu.dart';
import 'package:regun/desktop/desktop_bindings.dart';
import 'package:regun/desktop/desktop_platform.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/game_notice.dart';

class ControllerFrame {
  const ControllerFrame(this.values);
  final List<double> values;
  double axis(int index) => values[index].clamp(-1, 1);
  double button(int index) => values[index + 4].clamp(0, 1);
  bool pressed(int index) => button(index) >= .55;

  bool get neutral {
    final deadZone = DesktopBindings.shared.deadZone;
    return Offset(axis(0), axis(1)).distance <= deadZone &&
        Offset(axis(2), axis(3)).distance <= deadZone &&
        !Iterable<int>.generate(16).any((i) => button(i) >= .4);
  }
}

typedef ControllerHandler = bool Function(
  ControllerFrame? frame, {
  bool disconnected,
});

class DesktopController extends ConsumerStatefulWidget {
  const DesktopController({super.key, required this.child, this.readDevices});

  static final handlers = <ControllerHandler>[];
  final Widget child;
  final Future<List<ControllerDevice>?> Function()? readDevices;

  @override
  ConsumerState<DesktopController> createState() => _DesktopControllerState();
}

class _DesktopControllerState extends ConsumerState<DesktopController>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  StreamSubscription<void>? _connections;
  bool _reading = false, _foreground = true, _armed = false;
  int _lifecycle = 0;
  final _controllerMode = ValueNotifier(false);
  final _notice = ValueNotifier<String?>(null);
  final _notices = <({String id, String text})>[];
  String? _noticeId;
  Timer? _noticeTimer;
  Map<String, ControllerDevice> _devices = {};
  String? _activeId;
  final _menuHeld = <int>{};
  TraversalDirection? _heldDirection;
  Duration? _repeatAt;
  FocusScopeNode? _menuScope;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
    FocusManager.instance.addListener(_focusChanged);
    HardwareKeyboard.instance.addHandler(_keyboard);
    _ticker = createTicker((elapsed) {
      _elapsed = elapsed;
      unawaited(_poll(elapsed));
    })..start();
    unawaited(ref.read(soloudPlayProvider).warmControllerMenu());
    if (widget.readDevices == null && !nativeIosController) {
      _connections = controllerConnectionChanges().listen(
        (_) => _poll(_elapsed),
        onError: (Object _) {},
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    _lifecycle++;
    if (!foreground) _interrupt();
  }

  Future<void> _poll(Duration now) async {
    if (_reading || !_foreground) return;
    _reading = true;
    final lifecycle = _lifecycle;
    try {
      final devices = await (widget.readDevices ?? readControllerDevices)();
      if (!mounted || !_foreground || lifecycle != _lifecycle) return;
      if (devices == null) {
        if (_armed) _interrupt();
        return;
      }
      final next = {for (final device in devices) device.id: device};
      final disconnected = _activeId != null && !next.containsKey(_activeId);
      if (disconnected) {
        _interrupt(disconnected: true);
        _activeId = null;
        _setMode(false);
      }
      for (final device in _devices.values) {
        if (!next.containsKey(device.id)) _announce(device, connected: false);
      }
      for (final device in next.values) {
        if (!_devices.containsKey(device.id)) {
          _announce(device, connected: true);
        }
      }
      _devices = next;
      _activeId ??= devices.firstOrNull?.id;
      final values = next[_activeId]?.values;
      if (values == null) return;
      if (values.length < 20 || !values.every((value) => value.isFinite)) {
        if (_armed) _interrupt();
        return;
      }
      final frame = ControllerFrame(values);
      if (!_armed) {
        _armed = frame.neutral;
        if (!_armed) return;
      }
      _dispatch(frame, now);
    } finally {
      _reading = false;
    }
  }

  void _announce(ControllerDevice device, {required bool connected}) {
    final name = device.name
        .trim()
        .split(
          RegExp(
            r'\s*\(.*(?:STANDARD GAMEPAD|Vendor:).*',
            caseSensitive: false,
          ),
        )
        .first
        .trim();
    final status = connected
        ? 'Controller connected'
        : 'Controller disconnected';
    final notice = (
      id: device.id,
      text: name.isEmpty ? status : '$status · $name',
    );
    _notices.removeWhere((queued) => queued.id == device.id);
    if (_noticeId == device.id) {
      _noticeTimer?.cancel();
      _notices.insert(0, notice);
      _showNotice();
    } else {
      _notices.add(notice);
      if (_noticeTimer == null) _showNotice();
    }
  }

  void _showNotice() {
    _noticeTimer = null;
    final next = _notices.isEmpty ? null : _notices.removeAt(0);
    _noticeId = next?.id;
    _notice.value = next?.text;
    if (_notice.value != null) {
      _noticeTimer = Timer(const Duration(milliseconds: 2300), _showNotice);
    }
  }

  void _interrupt({bool disconnected = false}) {
    _armed = false;
    _menuHeld.clear();
    _heldDirection = null;
    _repeatAt = null;
    _menuScope = null;
    for (final handler in DesktopController.handlers.reversed.toList()) {
      handler(null, disconnected: disconnected);
    }
  }

  void _setMode(bool active) {
    if (_controllerMode.value == active) return;
    _controllerMode.value = active;
    if (!active) _repeatAt = null;
    FocusManager.instance.highlightStrategy = active
        ? FocusHighlightStrategy.alwaysTraditional
        : FocusHighlightStrategy.automatic;
  }

  bool _keyboard(KeyEvent event) {
    if (event is KeyDownEvent) _setMode(false);
    return false;
  }

  void _focusChanged() {
    if (!_controllerMode.value) return;
    final focus = FocusManager.instance.primaryFocus;
    if (focus is FocusScopeNode && focus.context != null) focus.nextFocus();
  }

  TraversalDirection? _direction(ControllerFrame frame) {
    for (final (button, direction) in const [
      (12, TraversalDirection.up),
      (13, TraversalDirection.down),
      (14, TraversalDirection.left),
      (15, TraversalDirection.right),
    ]) {
      if (frame.pressed(button)) return direction;
    }
    final x = frame.axis(0), y = frame.axis(1);
    final threshold = _heldDirection == null ? .65 : .5;
    if (x.abs() >= y.abs() && x.abs() >= threshold) {
      return x < 0 ? TraversalDirection.left : TraversalDirection.right;
    }
    if (y.abs() >= threshold) {
      return y < 0 ? TraversalDirection.up : TraversalDirection.down;
    }
    return null;
  }

  void _dispatch(ControllerFrame frame, Duration now) {
    final held = {
      for (final button in [0, 1, 9])
        if (frame.pressed(button)) button,
    };
    final fresh = held.difference(_menuHeld);
    _menuHeld
      ..clear()
      ..addAll(held);
    final direction = _direction(frame);
    final changed = direction != _heldDirection;
    _heldDirection = direction;

    for (final handler in DesktopController.handlers.reversed.toList()) {
      if (handler(frame)) {
        if (!frame.neutral) _setMode(true);
        _repeatAt = null;
        return;
      }
    }

    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (focus == null ||
        context == null ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final scope = focus is FocusScopeNode ? focus : focus.enclosingScope;
    final scopeChanged = scope != _menuScope;
    _menuScope = scope;
    if (scopeChanged) _repeatAt = null;
    final move =
        direction != null &&
        (changed || (_repeatAt != null && now >= _repeatAt!));
    if (fresh.isEmpty && !move) return;
    _setMode(true);
    if (fresh.contains(1)) {
      unawaited(_back(context, focus));
      return;
    }
    if (focus is FocusScopeNode) {
      focus.nextFocus();
      return;
    }
    if (fresh.contains(0)) {
      Actions.maybeInvoke(context, const ActivateIntent());
    } else if (fresh.contains(9)) {
      if (Actions.maybeInvoke(context, const ControllerResumeIntent()) ==
          true) {
        _cue('menu_back.wav');
      }
    } else if (move) {
      _repeatAt = now + Duration(milliseconds: changed ? 320 : 120);
      final horizontal =
          direction == TraversalDirection.left ||
          direction == TraversalDirection.right;
      if (horizontal &&
          Actions.maybeFind<ControllerAdjustIntent>(context) != null) {
        final step = direction == TraversalDirection.left ? -1 : 1;
        if (Actions.maybeInvoke(context, ControllerAdjustIntent(step)) ==
            true) {
          _cue('menu_move.wav');
        }
      } else if (focus.focusInDirection(direction)) {
        _cue('menu_move.wav');
      }
    }
  }

  Future<void> _back(BuildContext context, FocusNode focus) async {
    if (context.findAncestorWidgetOfExactType<EditableText>() != null) {
      if (focus.nextFocus()) _cue('menu_back.wav');
      return;
    }
    if (Actions.maybeFind<ControllerBackIntent>(context) != null) {
      if (Actions.maybeInvoke(context, const ControllerBackIntent()) == true) {
        _cue('menu_back.wav');
      }
      return;
    }
    if (ModalRoute.of(context)?.popDisposition == RoutePopDisposition.pop &&
        await (Navigator.maybeOf(context)?.maybePop() ?? Future.value(false)) &&
        mounted) {
      _cue('menu_back.wav');
    }
  }

  void _cue(String asset) =>
      unawaited(ref.read(soloudPlayProvider).play(asset));

  @override
  Widget build(BuildContext context) => ControllerMenuMode(
    active: _controllerMode,
    child: Listener(
      onPointerDown: (_) => _setMode(false),
      onPointerHover: (event) {
        if (event.kind == PointerDeviceKind.mouse &&
            event.delta.distance >= 2) {
          _setMode(false);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            top: 14,
            right: 18,
            child: IgnorePointer(
              child: SafeArea(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _notice,
                  builder: (context, notice, _) => notice == null
                      ? const SizedBox.shrink()
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: (MediaQuery.sizeOf(context).width - 36)
                                .clamp(0, 360),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: GameNoticeStrip(message: notice),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_focusChanged);
    HardwareKeyboard.instance.removeHandler(_keyboard);
    if (_controllerMode.value) {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    }
    _ticker.dispose();
    unawaited(_connections?.cancel());
    _noticeTimer?.cancel();
    _notice.dispose();
    _controllerMode.dispose();
    super.dispose();
  }
}
