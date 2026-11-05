import 'package:regun/desktop/desktop_menu_cursor.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:regun/desktop/desktop_bindings.dart';
import 'package:regun/desktop/desktop_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regun/desktop/desktop_combat_input.dart';
import 'package:regun/game.dart';

class DesktopCombatSurface extends StatefulWidget {
  const DesktopCombatSurface({
    super.key,
    required this.game,
    required this.playing,

    required this.child,
  });

  final RegunGame game;
  final bool playing;
  final Widget child;

  @override
  State<DesktopCombatSurface> createState() => _DesktopCombatSurfaceState();
}

class _DesktopCombatSurfaceState extends State<DesktopCombatSurface> {
  final _focus = FocusNode(debugLabel: 'Desktop combat');
  final _pointer = ValueNotifier<Offset?>(null);
  final _keys = <PhysicalKeyboardKey>{};
  int? _firePointer, _grenadePointer;
  int _epoch = -1;
  bool _controllerActive = false;
  bool _controllerArmed = false;
  final _controllerHeld = <ControllerAction>{};
  late final ControllerHandler _controllerHandler = _controller;
  DesktopBindings get _bindings => DesktopBindings.shared;

  @override
  void initState() {
    super.initState();
    DesktopController.handlers.add(_controllerHandler);
  }

  bool _controller(ControllerFrame? frame) {
    _sync();
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        !game.acceptsDesktopInput) {
      _controllerArmed = false;
      return false;
    }
    if (frame == null) {
      if (_controllerActive) {
        _controllerActive = false;
        _cancel();
      }
      _controllerArmed = false;
      return false;
    }
    final held = {
      for (final action in ControllerAction.values)
        if (frame.button(_bindings.button(action)) >=
            (_controllerHeld.contains(action) ? .4 : .55))
          action,
    };
    Vector2 stick(int index) {
      final value = Vector2(frame.axis(index), frame.axis(index + 1));
      final length = value.length;
      if (length <= _bindings.deadZone) return Vector2.zero();
      return value /
          length *
          ((length - _bindings.deadZone) / (1 - _bindings.deadZone)).clamp(
            0,
            1,
          );
    }

    final move = stick(_bindings.swapSticks ? 2 : 0);
    final aim = stick(_bindings.swapSticks ? 0 : 2);
    if (!_controllerArmed) {
      _controllerArmed = held.isEmpty && move.length2 == 0 && aim.length2 == 0;
      return _controllerActive;
    }
    if (!_controllerActive &&
        held.isEmpty &&
        move.length2 == 0 &&
        aim.length2 == 0) {
      return false;
    }
    if (!_controllerActive) {
      _cancel();
      _controllerActive = true;
      _controllerArmed = true;
      game.setDesktopInputActive(true);
      input.pointer = null;
      _pointer.value = null;
    }
    final fresh = held.difference(_controllerHeld);
    final previousGrenade = _controllerHeld.contains(ControllerAction.grenade);
    input.controller = true;
    _controllerHeld
      ..clear()
      ..addAll(held);
    input.movement.setFrom(move);
    if (aim.length2 > 0) {
      final heading = aim.normalized();
      if (input.stickAim.length2 == 0) {
        input.stickAim.setFrom(heading);
      } else {
        input.stickAim.setFrom(
          (input.stickAim * (1 - _bindings.sensitivity.clamp(0.5, 1)) +
                  heading * _bindings.sensitivity)
              .normalized(),
        );
      }
    } else if (input.stickAim.length2 == 0) {
      input.stickAim.setFrom(game.myPlayer.aimDirection);
    }
    if (fresh.contains(ControllerAction.pause)) {
      _cancel();
      game.pauseGame();
      return true;
    }
    if (fresh.contains(ControllerAction.dash)) game.requestDash();
    if (fresh.contains(ControllerAction.reload)) game.requestReload();
    final projected = game.camera.localToGlobal(
      game.myPlayer.position + input.stickAim * 150,
    );
    final target = Offset(projected.x, projected.y);
    _pointer.value = game.controlCanvasRect.contains(target) ? target : null;
    input.fire = held.contains(ControllerAction.fire);
    input.grenade = held.contains(ControllerAction.grenade);
    if (previousGrenade && !input.grenade) {
      game.throwGrenade(aim: game.desktopGrenadeDirection);
    }
    return true;
  }

  void _useMouseKeyboard() {
    input.controller = false;
    if (_controllerActive) {
      _controllerActive = false;
      _cancel();
    }
    game.setDesktopInputActive(true);
    _sync();
  }

  RegunGame get game => widget.game;
  DesktopCombatInput get input => game.desktopInput!;

  void _sync() {
    if (_epoch == input.epoch) return;
    _epoch = input.epoch;
    _keys.clear();
    _controllerHeld.clear();
    _controllerArmed = false;
    _firePointer = _grenadePointer = null;
  }

  void _releaseCursor() {
    if (DesktopMenuCursor.combatPointer.value == this) {
      DesktopMenuCursor.combatPointer.value = null;
    }
  }

  void _cancel() {
    _releaseCursor();
    game.arsenal?.cancelIntent();
    input.reset();
    _pointer.value = null;
    _sync();
  }

  @override
  void didUpdateWidget(DesktopCombatSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing && !widget.playing) {
      _cancel();
      input.pointer = null;
      _pointer.value = null;
    }
    if (!oldWidget.playing && widget.playing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.playing) _focus.requestFocus();
      });
    }
  }

  bool _inside(Offset point) =>
      game.acceptsDesktopInput && game.controlCanvasRect.contains(point);

  void _aim(Offset point) {
    final target = _inside(point) ? point : null;
    if (target == null && input.pointer != null) _cancelPointer();
    if (target != null) DesktopMenuCursor.combatPointer.value = this;
    input.pointer = target;
    _pointer.value = target;
  }

  void _cancelPointer() {
    _releaseCursor();
    if (_controllerActive) return;
    if (_firePointer != null) {
      game.arsenal?.cancelAim();
      input.cancelFire();
    }
    if (_grenadePointer != null) input.grenade = false;
    _firePointer = _grenadePointer = null;
    input.pointer = null;
    _pointer.value = null;
    _fire();
  }

  void _fire() {
    input.fire =
        _firePointer != null || _bindings.held(DesktopAction.fire, _keys);
  }

  void _grenade() {
    final wasHeld = input.grenade;
    input.grenade =
        _grenadePointer != null || _bindings.held(DesktopAction.grenade, _keys);
    if (wasHeld && !input.grenade && game.acceptsDesktopInput) {
      game.throwGrenade(aim: game.desktopGrenadeDirection);
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    _sync();
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        game.acceptsDesktopInput) {
      _cancel();
      game.pauseGame();
      return KeyEventResult.handled;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.physicalKey;
    if (!DesktopAction.values.any(
          (action) => _bindings.matchesKey(action, key),
        ) ||
        !game.acceptsDesktopInput) {
      return KeyEventResult.ignored;
    }
    _useMouseKeyboard();
    if (event is KeyDownEvent) _keys.add(key);
    if (event is KeyUpEvent) _keys.remove(key);
    int pressed(DesktopAction action) => _bindings.held(action, _keys) ? 1 : 0;
    input.movement.setValues(
      (pressed(DesktopAction.right) - pressed(DesktopAction.left)).toDouble(),
      (pressed(DesktopAction.down) - pressed(DesktopAction.up)).toDouble(),
    );
    if (input.movement.length2 > 1) input.movement.normalize();
    if (event is KeyDownEvent) {
      if (_bindings.matchesKey(DesktopAction.dash, key)) game.requestDash();
      if (_bindings.matchesKey(DesktopAction.reload, key)) game.requestReload();
    }
    _fire();
    _grenade();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    autofocus: widget.playing,
    descendantsAreFocusable: false,
    canRequestFocus: widget.playing,
    onFocusChange: (focused) {
      if (!focused) _cancel();
    },
    onKeyEvent: _key,
    child: MouseRegion(
      onHover: (event) {
        if (_controllerActive && event.delta.distance < 2) return;
        _useMouseKeyboard();
        _aim(event.localPosition);
      },
      onExit: (_) => _cancelPointer(),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.touch) {
            game.setDesktopInputActive(false);
            _pointer.value = null;
            return;
          }
          _sync();
          if (!_inside(event.localPosition)) return;
          _useMouseKeyboard();
          _focus.requestFocus();
          _aim(event.localPosition);
          if (event.buttons & _bindings.mouseFire != 0) {
            _firePointer = event.pointer;
          }
          if (event.buttons & _bindings.mouseGrenade != 0) {
            _grenadePointer = event.pointer;
          }
          _fire();
          _grenade();
        },
        onPointerMove: (event) {
          if (event.kind == PointerDeviceKind.mouse) _aim(event.localPosition);
        },
        onPointerUp: (event) {
          _sync();
          if (event.pointer != _firePointer &&
              event.pointer != _grenadePointer) {
            return;
          }
          _aim(event.localPosition);
          if (_firePointer == event.pointer) _firePointer = null;
          if (_grenadePointer == event.pointer) _grenadePointer = null;
          _fire();
          _grenade();
        },
        onPointerCancel: (_) => _cancel(),
        child: ValueListenableBuilder<Offset?>(
          valueListenable: _pointer,
          builder: (context, point, child) => Stack(
            fit: StackFit.expand,
            children: [
              MouseRegion(
                cursor: point == null || !widget.playing
                    ? MouseCursor.defer
                    : SystemMouseCursors.none,
                child: child,
              ),
              if (point != null && widget.playing)
                IgnorePointer(
                  child: CustomPaint(
                    painter: DesktopCrosshair(
                      point,
                      _bindings.crosshairScale,
                      _bindings.highContrast,
                    ),
                  ),
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _releaseCursor();
    DesktopController.handlers.remove(_controllerHandler);
    _focus.dispose();
    _pointer.dispose();
    super.dispose();
  }
}

class DesktopCrosshair extends CustomPainter {
  const DesktopCrosshair(this.point, this.scale, this.highContrast);

  final Offset point;
  final double scale;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.scale(scale);
    final silhouette = Path();
    final brackets = Path();
    for (final x in [-1.0, 1.0]) {
      for (final y in [-1.0, 1.0]) {
        brackets
          ..moveTo(7 * x, 11 * y)
          ..lineTo(11 * x, 11 * y)
          ..lineTo(11 * x, 7 * y);
      }
    }
    for (final axis in const [Offset(1, 0), Offset(0, 1)]) {
      for (final side in [-1, 1]) {
        final inner = axis * (7 * side.toDouble());
        final outer = axis * (17 * side.toDouble());
        silhouette
          ..moveTo(inner.dx, inner.dy)
          ..lineTo(outer.dx, outer.dy);
      }
    }
    final paint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xff171317);
    canvas.drawPath(silhouette, paint);
    canvas.drawPath(brackets, paint..strokeWidth = 4);
    canvas.drawPath(
      silhouette,
      paint
        ..strokeWidth = 2
        ..color = highContrast ? Colors.white : const Color(0xffffe1a6),
    );
    canvas.drawPath(
      brackets,
      paint
        ..strokeWidth = 1.5
        ..color = highContrast ? Colors.white : const Color(0xffdd9e59),
    );
    paint.style = PaintingStyle.fill;
    canvas.drawRect(
      const Rect.fromLTWH(-2.5, -2.5, 5, 5),
      paint..color = const Color(0xff171317),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-1, -1, 2, 2),
      paint..color = highContrast ? Colors.white : const Color(0xffffe1a6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DesktopCrosshair oldDelegate) =>
      oldDelegate.point != point ||
      oldDelegate.scale != scale ||
      oldDelegate.highContrast != highContrast;
}
