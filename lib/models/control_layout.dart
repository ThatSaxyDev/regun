import 'package:regun/presentation/game_layout.dart';

import 'dart:math';
import 'dart:ui';

/// Physical logical-pixel controls, independent of the arena's world resolution.
class ControlLayout {
  const ControlLayout({
    this.inset = 84,
    this.bottom = 76,
    this.size = 96,
    this.opacity = 0.8,
    this.leftHanded = false,
    this.floating = false,
    this.sensitivity = 1,
    this.deadZone = 0.06,
    this.positions = const {},
  });
  final double inset, bottom, size, opacity;
  final bool leftHanded, floating;
  final double sensitivity, deadZone;
  final Map<String, List<double>> positions;
  // Keep the original 56px action buttons at the default 96px stick size.
  double get buttonSize => 56 * size / 96;

  ControlLayout copyWith({
    double? inset,
    double? bottom,
    double? size,
    double? opacity,
    bool? leftHanded,
    bool? floating,
    double? sensitivity,
    double? deadZone,
    Map<String, List<double>>? positions,
  }) => ControlLayout(
    inset: inset ?? this.inset,
    bottom: bottom ?? this.bottom,
    size: size ?? this.size,
    opacity: opacity ?? this.opacity,
    leftHanded: leftHanded ?? this.leftHanded,
    floating: floating ?? this.floating,
    sensitivity: sensitivity ?? this.sensitivity,
    deadZone: deadZone ?? this.deadZone,
    positions: positions ?? this.positions,
  );

  Map<String, dynamic> toJson() => {
    'inset': inset,
    'bottom': bottom,
    'size': size,
    'opacity': opacity,
    'floating': floating,
    'sensitivity': sensitivity,
    'deadZone': deadZone,
    'positions': positions,
    'leftHanded': leftHanded,
  };

  factory ControlLayout.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback, double low, double high) {
      final value = json[key];
      return value is num && value.isFinite
          ? value.toDouble().clamp(low, high)
          : fallback;
    }

    final positions = <String, List<double>>{};
    if (json['positions'] is Map) {
      for (final entry in (json['positions'] as Map).entries) {
        final value = entry.value;
        if (['move', 'aim', 'dash', 'reload', 'grenade'].contains(entry.key) &&
            value is List &&
            value.length == 2 &&
            value.every((v) => v is num && v.isFinite)) {
          positions[entry.key as String] = value
              .map((v) => (v as num).toDouble().clamp(0.0, 1.0))
              .toList();
        }
      }
    }
    return ControlLayout(
      floating: json['floating'] == true,
      sensitivity: number('sensitivity', 1, 0.6, 1.5),
      deadZone: number('deadZone', 0.06, 0.04, 0.25),
      positions: Map.unmodifiable(positions),
      inset: number('inset', 84, 64, 160),
      bottom: number('bottom', 76, 60, 140),
      size: number('size', 96, 88, 112),
      opacity: number('opacity', 0.8, 0.25, 1),
      leftHanded: json['leftHanded'] == true,
    );
  }

  double displaySize(Size viewport) => size * GameLayout.uiScale(viewport);
  double displayButtonSize(Size viewport) =>
      buttonSize * GameLayout.uiScale(viewport);

  ControlGeometry geometry(Size viewport) {
    final presentation = GameLayout.uiScale(viewport);
    final size = this.size * presentation;
    final buttonSize = this.buttonSize * presentation;
    final inset = this.inset * presentation;
    final bottom = this.bottom * presentation;
    final radius = size / 2;
    final buttonRadius = buttonSize / 2;
    final minReloadY = max(40.0, buttonRadius + 8);
    final x = inset.clamp(
      radius + 8,
      max(radius + 8, viewport.width / 2 - 110),
    );
    final y =
        (viewport.height -
                bottom.clamp(
                  radius + 8,
                  max(radius + 8, viewport.height - 110),
                ))
            .clamp(
              min(
                minReloadY + radius + buttonRadius + 8,
                viewport.height - radius - 8,
              ),
              viewport.height - radius - 8,
            )
            .toDouble();
    final left = Offset(x.toDouble(), y);
    final right = Offset(viewport.width - x, y);
    final reach = max(76.0, radius + buttonRadius + 4);
    final defaults = {
      'move': left,
      'aim': right,
      'dash': right + Offset(-reach, -48 * size / 96),
      'grenade': right + Offset(-reach, 40 * size / 96),
      'reload': Offset(
        right.dx - 8 * size / 96,
        max(minReloadY, y - 106 * size / 96),
      ),
    };
    Offset point(String id) {
      final custom = positions[id];
      final raw = custom == null
          ? defaults[id]!
          : Offset(custom[0] * viewport.width, custom[1] * viewport.height);
      final r = id == 'move' || id == 'aim' ? radius : buttonRadius;
      final logicalX = raw.dx.clamp(
        id == 'move' ? r + 8 : viewport.width / 2 + r,
        id == 'move' ? viewport.width / 2 - r : viewport.width - r - 8,
      );
      return Offset(
        leftHanded ? viewport.width - logicalX : logicalX,
        raw.dy.clamp(r + 8, viewport.height - r - 8),
      );
    }

    var geometry = ControlGeometry(
      movement: point('move'),
      aim: point('aim'),
      dash: point('dash'),
      reload: point('reload'),
      grenade: point('grenade'),
    );
    if (!geometry.separate(radius, buttonRadius: buttonRadius) &&
        positions.isNotEmpty) {
      geometry = copyWith(positions: const {}).geometry(viewport);
    }
    return geometry;
  }
}

class ControlGeometry {
  const ControlGeometry({
    required this.movement,
    required this.aim,
    required this.dash,
    required this.reload,
    required this.grenade,
  });
  final Offset movement, aim, dash, reload, grenade;
  bool separate(double radius, {double buttonRadius = 28}) =>
      (movement - aim).distance >= radius * 2 + 8 &&
      (dash - aim).distance >= radius + buttonRadius + 2 &&
      (reload - aim).distance >= radius + buttonRadius + 2 &&
      (dash - reload).distance >= buttonRadius * 2 + 4 &&
      (movement - dash).distance >= radius + buttonRadius + 2 &&
      (movement - reload).distance >= radius + buttonRadius + 2 &&
      (grenade - aim).distance >= radius + buttonRadius + 2 &&
      (grenade - movement).distance >= radius + buttonRadius + 2 &&
      (grenade - dash).distance >= buttonRadius * 2 + 4 &&
      (grenade - reload).distance >= buttonRadius * 2 + 4;
}
