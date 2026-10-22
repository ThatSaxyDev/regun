import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/events.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/control_art.dart';
import 'package:regun/game.dart';

class GameStick extends JoystickComponent {
  GameStick() : super(knob: JoyStickKnob(), background: _JoystickRing());
  int? _pointer;
  bool _cancelling = false;
  bool get hasActivePointer => _pointer != null;

  @override
  bool containsLocalPoint(Vector2 point) {
    final regun = game as RegunGame;
    if (!regun.controls.floating) return super.containsLocalPoint(point);
    final viewportPoint = localToParent(point);
    final virtual = regun.camera.viewport.virtualSize;
    if (viewportPoint.y < virtual.y * 0.35 ||
        viewportPoint.y > virtual.y ||
        viewportPoint.x < 0 ||
        viewportPoint.x > virtual.x) {
      return false;
    }
    final movementSide = this is MovementJoystickComponent;
    final rightSide = movementSide
        ? regun.controls.leftHanded
        : !regun.controls.leftHanded;
    if ((viewportPoint.x >= virtual.x / 2) != rightSide) return false;
    for (final button in [
      regun.boostButtonComponent,
      regun.reloadButtonComponent,
      regun.grenadeButtonComponent,
    ]) {
      if (button.containsLocalPoint(button.parentToLocal(viewportPoint))) {
        return false;
      }
    }
    return true;
  }

  @override
  bool onDragStart(DragStartEvent event) {
    if (_pointer != null ||
        (game as RegunGame).gameState.gameplayState != GameplayState.playing) {
      return false;
    }
    _pointer = event.pointerId;
    final regun = game as RegunGame;
    if (regun.controls.floating) {
      position.setFrom(
        regun.camera.viewport.globalToLocal(event.canvasPosition),
      );
    }
    return super.onDragStart(event);
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    if (event.pointerId != _pointer) return false;
    return super.onDragUpdate(event);
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    if (event.pointerId != _pointer) return false;
    if (!_cancelling && this is WeaponJoystickComponent) {
      (game as RegunGame).arsenal?.releaseAim(strengthDelta);
    }
    return super.onDragEnd(event);
  }

  @override
  bool onDragCancel(DragCancelEvent event) {
    if (event.pointerId != _pointer) return false;
    if (this is WeaponJoystickComponent) {
      (game as RegunGame).arsenal?.cancelAim();
    }
    // Flame translates cancellation into virtual onDragEnd. Suppress its
    // release shot while still letting the inherited drag state clean up.
    _cancelling = true;
    try {
      return super.onDragCancel(event);
    } finally {
      _cancelling = false;
    }
  }

  @override
  void onDragStop() {
    _pointer = null;
    super.onDragStop();
    delta.setZero();
  }

  Vector2 get strengthDelta {
    final value = super.relativeDelta;
    if (value.length2 <
        (game as RegunGame).controls.deadZone *
            (game as RegunGame).controls.deadZone) {
      return Vector2.zero();
    }
    return value;
  }

  @override
  Vector2 get relativeDelta {
    final value = super.relativeDelta;
    final controls = (game as RegunGame).controls;
    if (value.length2 < controls.deadZone * controls.deadZone) {
      return Vector2.zero();
    }
    value.scale(controls.sensitivity);
    if (value.length2 > 1) value.normalize();
    return value;
  }
}

class MovementJoystickComponent extends GameStick {
  MovementJoystickComponent();
}

class WeaponJoystickComponent extends GameStick {
  WeaponJoystickComponent();
}

class _JoystickRing extends CircleComponent with HasGameReference<RegunGame> {
  _JoystickRing() : super(radius: 90);
  @override
  void render(Canvas canvas) =>
      ControlArt.stickRing(canvas, radius, game.controls.opacity);
}

class JoyStickKnob extends PositionComponent with HasGameReference<RegunGame> {
  JoyStickKnob() : super(size: Vector2.all(64), anchor: Anchor.center);
  @override
  void render(Canvas canvas) =>
      ControlArt.stickKnob(canvas, Size(size.x, size.y), game.controls.opacity);
}
