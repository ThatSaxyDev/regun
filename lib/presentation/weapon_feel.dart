import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';

/// Presentation and bounded hit response; projectile stats/damage stay in loadout.
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
  // Draw size is independent of the projectile's collision radius.
  static ({double length, double thickness, double trailWidth}) round(
          WeaponType type) =>
      switch (type) {
        WeaponType.shotgun => (length: 22, thickness: 11, trailWidth: 7),
        WeaponType.carbine => (length: 13, thickness: 5, trailWidth: 3),
        WeaponType.revolver => (length: 15, thickness: 6, trailWidth: 4),
        WeaponType.arcCaster => (length: 13, thickness: 6, trailWidth: 3),
      };

  static ({double distance, double duration}) impactMotion(WeaponType type) =>
      switch (type) {
        WeaponType.shotgun => (distance: 34, duration: .12),
        WeaponType.carbine => (distance: 5, duration: .06),
        WeaponType.revolver => (distance: 16, duration: .1),
        WeaponType.arcCaster => (distance: 8, duration: .075),
      };
  static WeaponFeel of(WeaponType type) => switch (type) {
        WeaponType.shotgun =>
          const WeaponFeel(Color(0xffE9BC75), 64, .44, 9, .14, 40, 20, 30, 42),
        WeaponType.carbine =>
          const WeaponFeel(Color(0xffF0D6A2), 57, .45, 4, .07, 23, 8, 36, 19),
        WeaponType.revolver =>
          const WeaponFeel(Color(0xffFFC588), 44, .23, 11, .19, 44, 13, 60, 40),
        WeaponType.arcCaster =>
          const WeaponFeel(Color(0xffA6E8D4), 54, .23, 9, .18, 38, 22, 54, 50),
      };
}
