import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/events.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/game.dart';

class GameStick extends JoystickComponent {
  GameStick() : super(knob: JoyStickKnob(), background: _JoystickRing());
  int? _pointer;
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
    final rightSide =
        movementSide ? regun.controls.leftHanded : !regun.controls.leftHanded;
    if ((viewportPoint.x >= virtual.x / 2) != rightSide) return false;
    for (final button in [
      regun.boostButtonComponent,
      regun.reloadButtonComponent,
      regun.grenadeButtonComponent
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
      position
          .setFrom(regun.camera.viewport.globalToLocal(event.canvasPosition));
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
    return super.onDragEnd(event);
  }

  @override
  bool onDragCancel(DragCancelEvent event) {
    if (event.pointerId != _pointer) return false;
    return super.onDragCancel(event);
  }

  @override
  void onDragStop() {
    _pointer = null;
    super.onDragStop();
    delta.setZero();
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
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Color.fromRGBO(35, 29, 40, 0.15 * game.controls.opacity));
    final line = Paint()
      ..color = Color.fromRGBO(126, 114, 123, 0.4 * game.controls.opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 2, line);
    canvas.drawCircle(
        center, radius - 10, line..color = const Color(0x187E727B));
    final tick = Paint()
      ..color = const Color(0x808E827F)
      ..strokeWidth = 3;
    for (final direction in [
      const Offset(1, 0),
      const Offset(-1, 0),
      const Offset(0, 1),
      const Offset(0, -1)
    ]) {
      canvas.drawLine(center + direction * (radius - 6),
          center + direction * (radius - 16), tick);
    }
  }
}

class JoyStickKnob extends PositionComponent with HasGameReference<RegunGame> {
  JoyStickKnob() : super(size: Vector2.all(64), anchor: Anchor.center);
  @override
  void render(Canvas canvas) {
    Color tone(int value) {
      final c = Color(value);
      return c.withValues(alpha: c.a * game.controls.opacity);
    }

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawPath(controlPlate(rect), Paint()..color = tone(0xC82B252F));
    canvas.drawPath(
        controlPlate(rect.deflate(1)),
        Paint()
          ..color = tone(0xA0B1A18E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawPath(
        controlPlate(rect.deflate(7), cut: 3),
        Paint()
          ..color = tone(0x405E515D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawRect(Rect.fromCenter(center: rect.center, width: 4, height: 4),
        Paint()..color = tone(0xffB6A893));
  }
}
