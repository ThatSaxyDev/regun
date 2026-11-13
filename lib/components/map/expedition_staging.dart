import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/expedition_floor_art.dart';
import 'package:regun/utils/constants.dart';

/// The staging floor and interaction anchors use the same world coordinates.
abstract final class ExpeditionStaging {
  static const size = Size(1700, 1080);
  static const arrival = Offset(0, 285);
  static const armory = Offset(-440, 165);
  static const gate = Offset(0, -350);
  static const target = Offset(460, -115);
  static const range = 145.0;
}

class ExpeditionStagingArt extends PositionComponent {
  ExpeditionStagingArt() : super(priority: -36);

  @override
  void render(Canvas canvas) {
    final paint = Paint()..isAntiAlias = false;
    void block(double x, double y, double w, double h, int color) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint..color = Color(color));
    }

    ExpeditionFloorArt.deployment(canvas, const Offset(0, -267));
    ExpeditionFloorArt.chevron(canvas, const Offset(0, 108), 0, scale: .8);
    ExpeditionFloorArt.chevron(
      canvas,
      const Offset(-305, 174),
      -math.pi / 2,
      scale: .72,
    );
    block(-144, -486, 288, 105, 0xff131a18);
    block(-137, -480, 274, 17, 0xff64573d);
    block(-111, -461, 222, 64, 0xff2a3931);
    for (final x in [-139.0, 115.0]) {
      block(x, -470, 24, 79, 0xff30382e);
      block(x + 6, -450, 12, 43, 0xff7dd7ab);
    }
    for (var x = -102.0; x < 103; x += 28) {
      block(x, -399, 17, 8, 0xffb5a370);
    }

    const rangeCorners = [
      Offset(331, -158),
      Offset(589, -158),
      Offset(589, 91),
      Offset(331, 91),
    ];
    for (final (index, at) in rangeCorners.indexed) {
      ExpeditionFloorArt.corner(canvas, at, index * math.pi / 2, range: true);
    }
    block(337, -224, 247, 24, 0xff413c31);
    for (var x = 342.0; x < 575; x += 24) {
      block(x, -221, 12, 13, 0xff8b704a);
    }
    // Match the door and bench iron. The lettering belongs to each fixture.
    void nameplate(TextPainter label, Offset center, double width) {
      block(center.dx - width / 2, center.dy - 16, width, 32, 0xff222722);
      block(
        center.dx - width / 2 + 3,
        center.dy - 15,
        width - 6,
        2,
        0xff837458,
      );
      block(
        center.dx - width / 2 + 3,
        center.dy + 12,
        width - 6,
        3,
        0xff111713,
      );
      for (final x in [center.dx - width / 2 + 7, center.dx + width / 2 - 10]) {
        block(x, center.dy - 2, 3, 3, 0xffa09678);
      }
      label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
    }

    nameplate(_gate, const Offset(0, -468), 264);
    nameplate(_armory, const Offset(-440, 153), 218);
  }

  final _gate = _sign('DEPLOYMENT');
  final _armory = _sign('LOADOUT');

  static TextPainter _sign(String text) => TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: FontFam.pressStart,
        fontSize: 18,
        color: Color(0xffddc494),
        shadows: [Shadow(color: Color(0xff171a16), offset: Offset(0, 2))],
      ),
    ),
  )..layout();

  @override
  void onRemove() {
    _gate.dispose();
    _armory.dispose();
    super.onRemove();
  }
}

/// A real combat target with normal weapon contact and no death or kill payout.
class ExpeditionRangeTarget extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  ExpeditionRangeTarget()
    : super(
        position: Vector2(
          ExpeditionStaging.target.dx,
          ExpeditionStaging.target.dy,
        ),
        size: Vector2.all(110),
        anchor: Anchor.center,
        priority: 9885,
      );

  static const double damageStreakTimeout = 2;
  static const double _hitFlashDuration = .1;

  double _streakDamage = 0;
  double _timeSinceHit = damageStreakTimeout;

  double get streakDamage => _streakDamage;

  @override
  double get impactResponse => 0;

  @override
  void onLoad() => initializeHealth(100);

  @override
  bool takeDamage(double amount) {
    if (!amount.isFinite || amount <= 0) return false;
    _streakDamage += amount;
    _timeSinceHit = 0;
    return true;
  }

  @override
  void onCombatDeath() {}

  @override
  void update(double dt) {
    super.update(dt);
    if (_streakDamage == 0) return;
    _timeSinceHit += dt;
    if (_timeSinceHit >= damageStreakTimeout) _streakDamage = 0;
  }

  @override
  void render(Canvas canvas) {
    final ink = Paint()..isAntiAlias = false;
    void part(double x, double y, double w, double h, int color) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), ink..color = Color(color));
    }

    final flash = _timeSinceHit < _hitFlashDuration;
    part(17, 76, 76, 26, 0x990c100e);
    part(31, 70, 48, 22, 0xff515046);
    part(48, 51, 14, 31, 0xff9a8f68);
    part(28, 23, 54, 49, 0xff332b23);
    part(34, 26, 42, 39, flash ? 0xfff8d99c : 0xff89613d);
    part(43, 32, 24, 24, 0xffb99a61);
    part(49, 38, 12, 12, 0xff493027);
    part(43, 7, 24, 17, flash ? 0xfff8d99c : 0xffbda273);
    final label = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: _streakDamage > 0
            ? '${_streakDamage.toStringAsFixed(2)} TOTAL DMG'
            : 'TARGET',
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 14,
          color: Color(0xffffcf88),
          shadows: [Shadow(color: Color(0xff17130c), blurRadius: 5)],
        ),
      ),
    )..layout();
    label.paint(canvas, Offset((size.x - label.width) / 2, -23));
    label.dispose();
  }
}
