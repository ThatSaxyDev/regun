import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/presentation/weapon_art_spec.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:flame/components.dart' show Vector2;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';

/// One mechanical presentation for every weapon, shared by the world and HUD.
void paintWeapon(
  Canvas canvas,
  WeaponType type, {
  double reload = -1,
  double recoil = 0,
  double charge = 0,
  Offset muzzleJitter = Offset.zero,
  int reloadShells = 5,
  bool tactical = false,
  bool reducedMotion = false,
}) {
  final art = RegunArt.shared;
  final spec = WeaponArtSpec.of(type);
  if (!art.contains(spec.atlas)) return;
  final body = art.rawSprite(spec.atlas, spec.body);
  final part = art.rawSprite(spec.atlas, spec.mechanism);
  final loading = reload >= 0;
  final p = reload.clamp(0.0, 1.0);
  final feel = WeaponFeel.of(type);
  final movingReload = loading && !reducedMotion;
  // Fast travel into a planted hold; cue boundaries remain at .42 and .82.
  double action(double value, double start, double end) => Curves.easeOutCubic
      .transform(((value - start) / (end - start)).clamp(0, 1));
  double pulse(double value, double start, double peak, double end) =>
      action(value, start, peak) - action(value, peak, end);
  final seatStart = tactical ? .55 : .32;
  final seatEnd = tactical ? .82 : .42;
  final swapTravel = action(p, 0, .12) - action(p, seatStart, seatEnd);
  final width = spec.width, grip = spec.grip;
  final height = spec.height;
  canvas.save();
  canvas.translate(reducedMotion ? 0 : -recoil * recoil * feel.kick, 0);
  if (!loading && !reducedMotion && type.index < 4) {
    canvas.rotate(
      -recoil * recoil * (type == WeaponType.revolver ? .10 : .035),
    );
  }
  if (movingReload) {
    canvas.rotate(
      (action(p, 0, .10) - action(p, .82, tactical ? 1 : .94)) * .12,
    );
    if (type != WeaponType.shotgun && !tactical) {
      canvas.translate(-pulse(p, .82, .85, .93) * 2, 0);
    }
  }
  body.render(
    canvas,
    position: Vector2(-width * grip, -height * .55),
    size: Vector2(width, height),
  );
  switch (type) {
    case WeaponType.shotgun:
      final shells = max(1, reloadShells);
      final duration = ShotgunReload.durationFor(shells);
      const interval = ShotgunReload.shellIntervalMs;
      final elapsed = p * duration;
      final insert = ((elapsed % interval) / (interval * .3)).clamp(0.0, 1.0);
      final finish = ((elapsed - shells * interval) / 200).clamp(0.0, 1.0);
      final pump = movingReload
          ? (tactical ? 0.0 : pulse(finish, 0, .4, 1) * 7)
          : loading || reducedMotion
          ? 0.0
          : recoil * 6;
      part.render(
        canvas,
        position: Vector2(8 - pump, -1),
        size: Vector2(19, 6),
      );
      if (movingReload && elapsed < shells * interval && insert < 1) {
        final y = 16 * (1 - Curves.easeOutCubic.transform(insert)) + 3;
        canvas.drawRect(
          Rect.fromLTWH(-3, y, 7, 4),
          Paint()..color = const Color(0xffC56E50),
        );
        canvas.drawRect(
          Rect.fromLTWH(-3, y, 2, 4),
          Paint()..color = const Color(0xffE4C27F),
        );
      }
    case WeaponType.carbine:
      final travel = movingReload
          ? (action(p, 0, tactical ? .16 : .12) -
                    action(p, tactical ? .55 : .32, tactical ? .82 : .42)) *
                20
          : 0.0;
      part.render(
        canvas,
        position: Vector2(4, 5 + travel),
        size: Vector2(6, 13),
      );
    case WeaponType.revolver:
      canvas.save();
      canvas.translate(10, -4);
      if (movingReload) {
        canvas.translate(0, swapTravel * 9);
        canvas.rotate(action(p, .12, seatStart) * pi * 2);
      }
      part.render(canvas, position: Vector2(-5, -5), size: Vector2(10, 10));
      canvas.restore();
    case WeaponType.burstRifle:
      // Measured receiver sockets: magazine well at (7, 2.5), bolt at (5, -5.4).
      final travel = movingReload
          ? (action(p, 0, tactical ? .16 : .12) -
                    action(p, tactical ? .55 : .32, tactical ? .82 : .42)) *
                18
          : 0.0;
      part.render(
        canvas,
        position: Vector2(7, 2.5 + travel),
        size: Vector2(7, 10.83),
      );
      final bolt = art.rawSprite(spec.atlas, spec.bolt!);
      final boltTravel = reducedMotion
          ? 0.0
          : loading
          ? (tactical ? 0.0 : pulse(p, .82, .86, .94) * 5)
          : recoil * 3;
      bolt.render(
        canvas,
        position: Vector2(5 - boltTravel, -5.4),
        size: Vector2(7.2, 2),
      );
    case WeaponType.railLance:
      final travel = movingReload ? swapTravel * 20 : 0.0;
      part.render(
        canvas,
        position: Vector2(2, 3 + travel),
        size: Vector2(15, 9),
      );
      art
          .rawSprite(spec.atlas, 2)
          .render(
            canvas,
            position: Vector2(5 - (reducedMotion ? 0 : charge * 5), -8),
            size: Vector2(20, 8),
          );
      if (!loading && charge > 0) {
        for (var i = 0; i < (charge * 4).ceil(); i++) {
          canvas.drawRect(
            Rect.fromLTWH(16 + i * 4, -4, 2, 3),
            Paint()..color = const Color(0xffC5C6AB),
          );
        }
      }
    case WeaponType.rivetDriver:
      part.render(
        canvas,
        position: Vector2(0, 3 + (movingReload ? swapTravel * 18 : 0)),
        size: Vector2(20, 6),
      );
      art
          .rawSprite(spec.atlas, 2)
          .render(
            canvas,
            position: Vector2(5 - (reducedMotion ? 0 : recoil * 4), -7),
            size: Vector2(17, 7),
          );
    case WeaponType.cinderHose:
      part.render(
        canvas,
        position: Vector2(0, 3 + (movingReload ? swapTravel * 18 : 0)),
        size: Vector2(16, 8),
      );
      canvas.save();
      canvas.translate(13, -1);
      if (movingReload && !tactical) canvas.rotate(action(p, .82, .94) * pi);
      art
          .rawSprite(spec.atlas, 2)
          .render(canvas, position: Vector2(-4, -4), size: Vector2(8, 8));
      canvas.restore();
    case WeaponType.reaperDisc:
      part.render(
        canvas,
        position: Vector2(0, 2 + (movingReload ? swapTravel * 18 : 0)),
        size: Vector2(20, 8),
      );
    case WeaponType.scrapMortar:
      art
          .rawSprite(spec.atlas, 2)
          .render(
            canvas,
            position: Vector2(
              -8 - (movingReload ? pulse(p, 0, .12, .82) * 8 : 0),
              -6,
            ),
            size: Vector2(10, 10),
          );
      if (movingReload && p > (tactical ? .16 : .12) && p < seatEnd) {
        part.render(
          canvas,
          position: Vector2(
            -20 + action(p, tactical ? .16 : .12, seatEnd) * 18,
            -2,
          ),
          size: Vector2(14, 7),
        );
      }
    case WeaponType.beltRepeater:
      part.render(
        canvas,
        position: Vector2(1, 2 + (movingReload ? swapTravel * 20 : 0)),
        size: Vector2(17, 12),
      );
      canvas.save();
      canvas.translate(
        spec.muzzle - 10,
        spec.muzzleSocket.dy - spec.gripSocket.dy,
      );
      if (!reducedMotion && !loading) {
        canvas.scale(1, .9 + .1 * cos(charge * pi * 8 + recoil * 5));
      }
      art
          .rawSprite(spec.atlas, 2)
          .render(canvas, position: Vector2(-4, -5), size: Vector2(14, 10));
      canvas.restore();
    case WeaponType.frostShotgun:
      final pump = movingReload
          ? (tactical ? 0.0 : pulse(p, .82, .86, .94) * 7)
          : reducedMotion
          ? 0.0
          : recoil * 6;
      part.render(
        canvas,
        position: Vector2(10 - pump, 0),
        size: Vector2(20, 5),
      );
      if (movingReload && p > (tactical ? .16 : .12) && p < seatEnd) {
        art
            .rawSprite(spec.atlas, 2)
            .render(
              canvas,
              position: Vector2(
                -2,
                12 - action(p, tactical ? .16 : .12, seatEnd) * 10,
              ),
              size: Vector2(9, 4),
            );
      }
    case WeaponType.prismCutter:
      part.render(canvas, position: Vector2(1, 2), size: Vector2(16, 6));
      art
          .rawSprite(spec.atlas, 2)
          .render(
            canvas,
            position: Vector2(
              spec.muzzle - 9,
              -6 - (movingReload ? pulse(p, 0, .12, .82) * 3 : 0),
            ),
            size: Vector2(9, 9),
          );
      if (charge > .1 && !loading) {
        canvas.drawRect(
          Rect.fromLTWH(5, 0, charge * 9, 2),
          Paint()
            ..color = Color.lerp(
              const Color(0xffBAC7B8),
              const Color(0xffC8845C),
              charge,
            )!,
        );
      }
    case WeaponType.sporeLobber:
      canvas.save();
      canvas.translate(3, 0);
      if (movingReload) canvas.rotate(action(p, .12, seatStart) * pi * 2);
      part.render(
        canvas,
        position: Vector2(-6, -6 + (movingReload ? swapTravel * 18 : 0)),
        size: Vector2(12, 12),
      );
      canvas.restore();
    case WeaponType.longwatchSniper:
      part.render(
        canvas,
        position: Vector2(0, 2 + (movingReload ? swapTravel * 18 : 0)),
        size: Vector2(7, 12),
      );
      art
          .rawSprite(spec.atlas, 2)
          .render(
            canvas,
            position: Vector2(
              1 -
                  (reducedMotion
                      ? 0
                      : loading
                      ? (tactical ? 0.0 : pulse(p, .82, .86, .94) * 6)
                      : recoil * 4),
              -4,
            ),
            size: Vector2(11, 5),
          );
    case WeaponType.arcCaster:
      final lift = movingReload ? swapTravel * 10 : 0.0;
      part.render(
        canvas,
        position: Vector2(4, -5 - lift),
        size: Vector2(13, 8),
      );
      if (movingReload && (!tactical || p < .82)) {
        for (var i = 0; i < 3; i++) {
          canvas.drawRect(
            Rect.fromLTWH(9 + i * 4, -10 - sin(p * pi * 5 + i) * 4, 2, 3),
            Paint()..color = const Color(0xffABDCC1),
          );
        }
      }
  }
  if (!type.isContinuous &&
      recoil > max(0, 1 - .045 / feel.recovery) &&
      !loading) {
    if (type.index >= 4) {
      // The released flash stays at the authoritative socket as the gun kicks.
      canvas.translate(
        reducedMotion ? 0 : recoil * recoil * feel.kick,
        spec.muzzleSocket.dy - spec.gripSocket.dy,
      );
    }
    canvas.translate(muzzleJitter.dx, muzzleJitter.dy);
    final muzzle = spec.muzzle;
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
          ..strokeWidth = 2.5,
      );
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
      canvas.drawRect(
        Rect.fromLTWH(muzzle, -2, length * .4, 4),
        Paint()..color = const Color(0xffFFF2D7),
      );
    }
  }
  canvas.restore();
}

class WeaponReloadDisplay extends StatelessWidget {
  const WeaponReloadDisplay({
    super.key,
    required this.weapon,
    required this.progress,
    this.shells = 5,
    this.tactical = false,
    this.reducedMotion = false,
  });
  final WeaponType weapon;
  final double progress;
  final int shells;
  final bool reducedMotion, tactical;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(150, 80),
    painter: _ReloadPainter(weapon, progress, shells, reducedMotion, tactical),
  );
}

class _ReloadPainter extends CustomPainter {
  const _ReloadPainter(
    this.weapon,
    this.progress,
    this.shells,
    this.reducedMotion,
    this.tactical,
  );
  final WeaponType weapon;
  final double progress;
  final int shells;
  final bool reducedMotion, tactical;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final title = TextPainter(
      text: TextSpan(
        text: weapon == WeaponType.prismCutter
            ? 'VENTING'
            : weapon.title.toUpperCase(),
        style: const TextStyle(
          fontFamily: FontFam.pressStart,
          fontSize: 8,
          color: Color(0xffE5DDD1),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    title.paint(canvas, Offset((size.width - title.width) / 2, 0));
    final spec = WeaponArtSpec.of(weapon);
    final scale = min(1.5, (size.width - 12) / spec.width);
    canvas.translate(
      size.width / 2 + scale * spec.width * (spec.grip - .5),
      38,
    );
    canvas.scale(scale);
    paintWeapon(
      canvas,
      weapon,
      reload: progress,
      reloadShells: shells,
      tactical: tactical,
      reducedMotion: reducedMotion,
    );
    canvas.restore();
    canvas.drawRect(
      const Rect.fromLTWH(24, 74, 102, 3),
      Paint()..color = const Color(0xff4F404D),
    );
    canvas.drawRect(
      Rect.fromLTWH(24, 74, 102 * progress, 3),
      Paint()..color = const Color(0xffE1BA78),
    );
  }

  @override
  bool shouldRepaint(_ReloadPainter oldDelegate) =>
      oldDelegate.weapon != weapon ||
      oldDelegate.progress != progress ||
      oldDelegate.shells != shells ||
      oldDelegate.tactical != tactical ||
      oldDelegate.reducedMotion != reducedMotion;
}
