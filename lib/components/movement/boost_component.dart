import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';

import 'package:flutter/material.dart';

class BoostButtonComponent extends HudButtonComponent {
  bool tapped;
  BoostButtonComponent({
    super.onPressed,
    this.tapped = false,
  }) : super(
          button: Buttonn(radius: 35),
          size: Vector2.all(70),
          position: Vector2(620, 320),
          anchor: Anchor.center,
        );

  @override
  void onMount() {
    // debugMode = true;
    super.onMount();
  }

  @override
  void onTapDown(TapDownEvent event) async {
    tapped = true;
    await Future.delayed(const Duration(milliseconds: 150)).whenComplete(() {
      tapped = false;
    });
    super.onTapDown(event);
  }

  @override
  void onTapUp(TapUpEvent event) {
    // tapped = false;
    super.onTapUp(event);
  }
}

class Buttonn extends PositionComponent {
  Buttonn({
    required double radius,
    Paint? paint,
    super.position,
  })  : _radius = radius,
        _paint = paint ?? Paint()
          ..color = const Color(0xFF80C080),
        super(
          priority: 30,
          size: Vector2.all(2 * radius),
          // anchor: Anchor.center,
        );

  final double _radius;
  final Paint _paint;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(Offset(_radius, _radius), _radius, _paint);
    // Draw the arrow (caret facing right)
    final arrowPaint = Paint()..color = Colors.black; // Set the arrow color

    // Adjust these values to increase the size of the arrow
    final arrowHeight = _radius / 2; // Height of the arrow
    final arrowWidth = _radius / 2.5; // Width of the arrow

    final arrowPath = Path()
      ..moveTo(_radius + arrowWidth, _radius) // Right point
      ..lineTo(_radius - arrowWidth / 2, _radius - arrowHeight / 2) // Top left
      ..lineTo(
          _radius - arrowWidth / 2, _radius + arrowHeight / 2) // Bottom left
      ..close(); // Connect back to the starting point

    canvas.drawPath(arrowPath, arrowPaint);
  }
}
