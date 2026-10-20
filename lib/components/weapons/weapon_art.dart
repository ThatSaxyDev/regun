import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:flame/components.dart' show Vector2;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';

/// One mechanical presentation for every weapon, shared by the world and HUD.
void paintWeapon(Canvas canvas, WeaponType type,
    {double reload = -1,
    double recoil = 0,
    int reloadShells = 5,
    bool reducedMotion = false}) {
  final art = RegunArt.shared;
  if (!art.contains('weapons/arsenal')) return;
  final index = type.index;
  final body = art.rawSprite('weapons/arsenal', index);
  final part = art.rawSprite('weapons/arsenal', 4 + index);
  final loading = reload >= 0;
  final p = reload.clamp(0.0, 1.0);
  final feel = WeaponFeel.of(type);
  final movingReload = loading && !reducedMotion;
  // Fast travel into a planted hold; cue boundaries remain at .42 and .82.
  double action(double value, double start, double end) =>
      Curves.easeOutCubic.transform(((value - start) / (end - start)).clamp(0, 1));
  double pulse(double value, double start, double peak, double end) =>
      action(value, start, peak) - action(value, peak, end);
  final width = feel.width, grip = feel.grip;
  final height = type == WeaponType.shotgun ? 22.0 : 26.0;
  canvas.save();
  canvas.translate(reducedMotion ? 0 : -recoil * recoil * feel.kick, 0);
  if (!loading && !reducedMotion) {
    canvas
        .rotate(-recoil * recoil * (type == WeaponType.revolver ? .10 : .035));
  }
  if (movingReload) {
    canvas.rotate((action(p, 0, .10) - action(p, .82, .94)) * .12);
    if (type != WeaponType.shotgun) {
      canvas.translate(-pulse(p, .82, .85, .93) * 2, 0);
    }
  }
  body.render(canvas,
      position: Vector2(-width * grip, -height * .55),
      size: Vector2(width, height));
  switch (type) {
    case WeaponType.shotgun:
      final shells = max(1, reloadShells);
      final duration = 900 + 700 * (shells - 1);
      final elapsed = p * duration;
      final insert = ((elapsed % 700) / 210).clamp(0.0, 1.0);
      final finish = ((elapsed - shells * 700) / 200).clamp(0.0, 1.0);
      final pump = movingReload
          ? pulse(finish, 0, .4, 1) * 7
          : loading || reducedMotion ? 0.0 : recoil * 6;
      part.render(canvas,
          position: Vector2(8 - pump, -1), size: Vector2(19, 6));
      if (movingReload && elapsed < shells * 700 && insert < 1) {
        final y = 16 * (1 - Curves.easeOutCubic.transform(insert)) + 3;
        canvas.drawRect(Rect.fromLTWH(-3, y, 7, 4),
            Paint()..color = const Color(0xffC56E50));
        canvas.drawRect(Rect.fromLTWH(-3, y, 2, 4),
            Paint()..color = const Color(0xffE4C27F));
      }
    case WeaponType.carbine:
      final travel = movingReload
          ? (action(p, 0, .12) - action(p, .32, .42)) * 20
          : 0.0;
      part.render(canvas,
          position: Vector2(4, 5 + travel), size: Vector2(6, 13));
    case WeaponType.revolver:
      canvas.save();
      canvas.translate(10, -4);
      if (movingReload) {
        canvas.translate(0, (action(p, 0, .12) - action(p, .72, .82)) * 9);
        canvas.rotate(action(p, .42, .58) * pi * 2);
      }
      part.render(canvas, position: Vector2(-5, -5), size: Vector2(10, 10));
      canvas.restore();
    case WeaponType.arcCaster:
      final lift = movingReload
          ? (action(p, 0, .12) - action(p, .72, .82)) * 10
          : 0.0;
      part.render(canvas,
          position: Vector2(4, -5 - lift), size: Vector2(13, 8));
      if (movingReload) {
        for (var i = 0; i < 3; i++) {
          canvas.drawRect(
              Rect.fromLTWH(9 + i * 4, -10 - sin(p * pi * 5 + i) * 4, 2, 3),
              Paint()..color = const Color(0xffABDCC1));
        }
      }
  }
  if (recoil > max(0, 1 - .045 / feel.recovery) && !loading) {
    final muzzle = feel.muzzle;
    final length = feel.flashLength * (reducedMotion ? .65 : 1);
    final wide = feel.flashWidth;
    final ink = Paint()..color = feel.color;
    if (type == WeaponType.arcCaster) {
      final arc = Path()
        ..moveTo(muzzle - 5, -7)
        ..lineTo(muzzle + length * .3, -2)
        ..lineTo(muzzle + length * .6, -8)
        ..lineTo(muzzle + length, 0)
        ..lineTo(muzzle + length * .5, 5)
        ..lineTo(muzzle - 5, 7);
      canvas.drawPath(
          arc,
          ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    } else {
      final flash = Path()
        ..moveTo(muzzle, -2)
        ..lineTo(muzzle + length * .3, -wide)
        ..lineTo(muzzle + length * .5, -3)
        ..lineTo(muzzle + length, 0)
        ..lineTo(muzzle + length * .45, 4)
        ..lineTo(muzzle + length * .25, wide)
        ..lineTo(muzzle, 3)
        ..close();
      canvas.drawPath(flash, ink);
      canvas.drawRect(Rect.fromLTWH(muzzle, -2, length * .4, 4),
          Paint()..color = const Color(0xffFFF2D7));
    }
  }
  canvas.restore();
}

class WeaponReloadDisplay extends StatelessWidget {
  const WeaponReloadDisplay(
      {super.key,
      required this.weapon,
      required this.progress,
      this.shells = 5,
      this.reducedMotion = false});
  final WeaponType weapon;
  final double progress;
  final int shells;
  final bool reducedMotion;
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: const Size(150, 80),
      painter: _ReloadPainter(weapon, progress, shells, reducedMotion));
}

class _ReloadPainter extends CustomPainter {
  const _ReloadPainter(
      this.weapon, this.progress, this.shells, this.reducedMotion);
  final WeaponType weapon;
  final double progress;
  final int shells;
  final bool reducedMotion;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final title = TextPainter(
        text: TextSpan(
            text: weapon.title.toUpperCase(),
            style: const TextStyle(
                fontFamily: FontFam.pressStart,
                fontSize: 8,
                color: Color(0xffE5DDD1))),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: size.width);
    title.paint(canvas, Offset((size.width - title.width) / 2, 0));
    canvas.translate(size.width / 2, 38);
    canvas.scale(1.5);
    paintWeapon(canvas, weapon,
        reload: progress, reloadShells: shells, reducedMotion: reducedMotion);
    canvas.restore();
    canvas.drawRect(const Rect.fromLTWH(24, 74, 102, 3),
        Paint()..color = const Color(0xff4F404D));
    canvas.drawRect(Rect.fromLTWH(24, 74, 102 * progress, 3),
        Paint()..color = const Color(0xffE1BA78));
  }

  @override
  bool shouldRepaint(_ReloadPainter oldDelegate) =>
      oldDelegate.weapon != weapon ||
      oldDelegate.progress != progress ||
      oldDelegate.shells != shells ||
      oldDelegate.reducedMotion != reducedMotion;
}
