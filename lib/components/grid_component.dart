import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GridComponent extends PositionComponent {
  final double gridSize;
  final Paint gridPaint;

  GridComponent({
    required this.gridSize,
    Color gridColor = Colors.grey,
    required super.size,
  }) : gridPaint = Paint()
          ..color = gridColor
          ..style = PaintingStyle.stroke;

  @override
  void render(Canvas canvas) {
    // Draw horizontal lines
    for (double y = 0; y < size.y; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.x, y),
        gridPaint,
      );
    }

    // Draw vertical lines
    for (double x = 0; x < size.x; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.y),
        gridPaint,
      );
    }
  }
}
