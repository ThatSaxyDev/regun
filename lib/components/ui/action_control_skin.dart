import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/presentation/control_art.dart';

class ActionControlSkin extends PositionComponent
    with HasGameReference<RegunGame> {
  ActionControlSkin({
    required this.glyph,
    required this.label,
    this.pressed = false,
  }) : super(size: Vector2.all(112));

  final PixelGlyph glyph;
  final String label;
  final bool pressed;

  @override
  void render(Canvas canvas) {
    final active =
        pressed ||
        (glyph == PixelGlyph.reload
            ? game.gameState.reloading
            : game.boostButtonComponent.tapped);
    ControlArt.action(
      canvas,
      glyph: glyph,
      label: label,
      opacity: game.controls.opacity,
      active: active,
      cooldown: glyph == PixelGlyph.dash
          ? game.boostButtonComponent.cooldownFraction
          : 0,
    );
  }
}
