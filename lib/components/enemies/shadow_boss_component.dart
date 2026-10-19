import 'package:regun/components/weapons/weapon_impact.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/components/enemies/boss_encounter.dart';
import 'package:regun/data/enemies.dart';
import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/shadow_projectile.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

enum ShadowPhase {
  arrival,
  pursuit,
  fanWarning,
  fan,
  dashWarning,
  dash,
  strikeWarning,
  strike,
  recovery
}

class ShadowBossComponent extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy
    implements BossEncounter {
  ShadowBossComponent({super.position, this.maximumHealth = 140})
      : super(size: Vector2.all(160), anchor: Anchor.center, priority: 5);

  @override
  BossKind get kind => BossKind.shadow;
  final double maximumHealth;
  late SpriteAnimationComponent _body;
  late SpriteAnimation _walk, _idle;
  final _poses = <ShadowPhase, SpriteAnimation>{};
  ShadowPhase phase = ShadowPhase.arrival;
  double _phaseTime = 0;
  int _pattern = 0;
  bool _fired = false;
  int _volleys = 0;
  final _aim = Vector2(1, 0);
  final _dashStart = Vector2.zero();
  final _dashEnd = Vector2.zero();
  @override
  bool get enraged => combatHealth.fraction <= 0.5;
  @override
  bool get isBoss => true;
  @override
  int get xpReward => 15;
  @override
  int get scoreReward => 1000;

  @override
  Future<void> onLoad() async {
    initializeHealth(maximumHealth);
    final art = RegunArt.shared;
    _idle = BossArt.idle(kind);
    _walk = BossArt.walk(kind);
    for (final pair in [
      (ShadowPhase.fanWarning, 1, 0, .16),
      (ShadowPhase.fan, 1, 4, .15),
      (ShadowPhase.dashWarning, 2, 0, .16),
      (ShadowPhase.dash, 2, 4, .13),
      (ShadowPhase.strikeWarning, 3, 0, .16),
      (ShadowPhase.strike, 3, 4, .13)
    ]) {
      _poses[pair.$1] = art.animation('bosses/shadow',
          row: pair.$2, from: pair.$3, count: 4, step: pair.$4, loop: false);
    }
    _body = SpriteAnimationComponent(
        animation: _idle,
        size: Vector2.all(240),
        position: Vector2(size.x * .5, size.y * .85 - .38 * 240),
        anchor: Anchor.center);
    add(_body);
    add(CircleHitbox(
        radius: 51,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive));
  }

  void _enter(ShadowPhase next) {
    if (next == ShadowPhase.recovery) game.releaseBossAttack(this);
    phase = next;
    _phaseTime = 0;
    _fired = false;
    _volleys = 0;
    _body.animation = _poses[next] ??
        (next == ShadowPhase.pursuit
            ? _walk
            : enraged
                ? RegunArt.shared
                    .animation('bosses/shadow', row: 4, count: 4, step: .18)
                : _idle);
  }

  void _commitAttack() {
    if (!game.claimBossAttack(this)) return;
    final delta = game.myPlayer.position - position;
    final lead =
        game.movementJoystick.relativeDelta * game.gameState.movementSpeed * .3;
    if (lead.length > 110) lead.scale(110 / lead.length);
    _aim.setFrom((delta + lead).normalized());
    if (_aim.isZero()) _aim.setValues(1, 0);
    _dashStart.setFrom(position);
    _dashEnd
        .setFrom(position + _aim * (delta.length + 500).clamp(550.0, 1100.0));
    game.constrainActor(_dashEnd, 80);
    final next = delta.length > 650
        ? ShadowPhase.dashWarning
        : delta.length < 190 && _pattern % 3 == 2
            ? ShadowPhase.strikeWarning
            : _pattern.isOdd
                ? ShadowPhase.dashWarning
                : ShadowPhase.fanWarning;
    _pattern++;
    _body.scale.x = _aim.x < 0 ? -1 : 1;
    _enter(next);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (combatHealth.isDead ||
        game.gameState.gameplayState != GameplayState.playing) {
      return;
    }
    _phaseTime += dt;
    final distance = position.distanceTo(game.myPlayer.position);
    switch (phase) {
      case ShadowPhase.arrival:
        if (_phaseTime >= 1.5) _enter(ShadowPhase.pursuit);
      case ShadowPhase.pursuit:
        _body.animation = distance > 190 ? _walk : _idle;
        if (distance > 190) {
          game.moveActor(this, (game.myPlayer.position - position).normalized(),
              enraged ? 245 : 205, dt,
              radius: 80);
        }
        if (_phaseTime >= (enraged ? .65 : 1.0)) _commitAttack();
      case ShadowPhase.fanWarning:
        if (_phaseTime >= (enraged ? .7 : .85)) _enter(ShadowPhase.fan);
      case ShadowPhase.fan:
        if (_volleys < (enraged ? 3 : 2) && _phaseTime >= _volleys * .22) {
          _volleys++;
          game.audio.play('enemy3projectile.wav');
          final count = enraged ? 7 : 5;
          for (var i = 0; i < count; i++) {
            final direction = _aim.clone()
              ..rotate((i - (count - 1) / 2) * pi / 10 +
                  (_volleys.isEven ? pi / 20 : 0));
            game.world.add(ShadowProjectile(
                position: position.clone(),
                direction: direction,
                speed: enraged ? 560 : 500,
                ownerHealth: combatHealth));
          }
        }
        if (_phaseTime >= 0.65) _enter(ShadowPhase.recovery);
      case ShadowPhase.dashWarning:
        if (_phaseTime >= 0.9) _enter(ShadowPhase.dash);
      case ShadowPhase.dash:
        final before = position.clone();
        game.moveTo(
            this,
            _dashStart +
                (_dashEnd - _dashStart) * (_phaseTime / 0.52).clamp(0, 1),
            80);
        if (BulletComponent.segmentDistanceSquared(
                    game.myPlayer.position, before, position) <
                80 * 80 &&
            !game.segmentBlocked(before, game.myPlayer.position)) {
          game.damagePlayer(cause: 'Shadow dash');
        }
        if (_phaseTime >= 0.52) _enter(ShadowPhase.recovery);
      case ShadowPhase.strikeWarning:
        if (_phaseTime >= 0.9) _enter(ShadowPhase.strike);
      case ShadowPhase.strike:
        if (!_fired && _phaseTime >= .16) {
          _fired = true;
          game.audio.play('impact_boss.wav');
          game.addCombatEffect(
              HeavyImpact(position: position.clone(), radius: 145));
          if (distance <= 185 &&
              !game.segmentBlocked(position, game.myPlayer.position)) {
            game.damagePlayer(cause: 'Shadow strike');
          }
        }
        if (_phaseTime >= 0.5) _enter(ShadowPhase.recovery);
      case ShadowPhase.recovery:
        if (_phaseTime >= (enraged ? .55 : .85)) _enter(ShadowPhase.pursuit);
    }
    game.constrainActor(position, 80);
    if (phase == ShadowPhase.pursuit ||
        phase == ShadowPhase.arrival ||
        phase == ShadowPhase.recovery) {
      final deltaX = game.myPlayer.position.x - position.x;
      if (deltaX.abs() > 20) _body.scale.x = deltaX < 0 ? -1 : 1;
    }
    _body.position.x = size.x * .5;
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    if (phase == ShadowPhase.arrival ||
        phase == ShadowPhase.strikeWarning ||
        phase == ShadowPhase.strike) {
      canvas.drawCircle(center, phase == ShadowPhase.arrival ? 85 : 185,
          Paint()..color = const Color(0x35D38D80));
      canvas.drawCircle(
          center,
          phase == ShadowPhase.arrival ? 85 : 185,
          Paint()
            ..color = const Color(0xffDDA581)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    if (phase == ShadowPhase.dashWarning) {
      final endpoint = (_dashEnd - position + size / 2).toOffset();
      canvas.drawLine(
          center,
          endpoint,
          Paint()
            ..color = const Color(0x45DDA581)
            ..strokeWidth = 160);
      canvas.drawLine(
          center,
          endpoint,
          Paint()
            ..color = const Color(0xffEBC899)
            ..strokeWidth = 3);
    }
    if (phase == ShadowPhase.fanWarning) {
      final endpoint = (_aim * 200 + size / 2).toOffset();
      canvas.drawLine(
          center,
          endpoint,
          Paint()
            ..color = const Color(0xffC782A3)
            ..strokeWidth = 4);
    }
    super.render(canvas);
  }

  @override
  void onCombatDeath() {
    game.addCombatEffectForKill(position,
        radius: 120, remains: RegunArt.shared.sprite('bosses/shadow', 39));
    for (final bolt
        in game.world.children.whereType<ShadowProjectile>().toList()) {
      bolt.removeFromParent();
    }
    removeFromParent();
  }
}
