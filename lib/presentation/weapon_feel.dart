import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';

/// Presentation values only: never change projectile physics or damage here.
class WeaponFeel {
  const WeaponFeel(this.color, this.width, this.grip, this.kick, this.recovery,
      this.flashLength, this.flashWidth, this.trail, this.impact);
  final Color color;
  final double width,
      grip,
      kick,
      recovery,
      flashLength,
      flashWidth,
      trail,
      impact;
  double get muzzle => width * (1 - grip);
  static WeaponFeel of(WeaponType type) => switch (type) {
        WeaponType.shotgun =>
          const WeaponFeel(Color(0xffE9BC75), 64, .44, 7, .17, 30, 15, 22, 24),
        WeaponType.carbine =>
          const WeaponFeel(Color(0xffF0D6A2), 57, .45, 3, .085, 18, 6, 32, 13),
        WeaponType.revolver =>
          const WeaponFeel(Color(0xffFFC588), 44, .23, 9, .23, 36, 9, 52, 30),
        WeaponType.arcCaster =>
          const WeaponFeel(Color(0xffA6E8D4), 54, .23, 4, .2, 24, 12, 28, 34),
      };
}
