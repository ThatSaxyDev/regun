import 'package:regun/systems/freeze_state.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/data/loadout.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/models/combat_health.dart';
import 'package:regun/notifiers/game_notifier.dart';

/// Shared damage/reward path for every active enemy, including bosses.
mixin CombatEnemy on PositionComponent, HasGameReference<RegunGame>
    implements Damageable {
  @override
  late final CombatHealth combatHealth;
  int combatId = 0;
  final freezeState = FreezeState();
  bool get freezeHeld => freezeState.held;
  bool get canFreeze => !isBoss && impactResponse > 0;
  void onFreezeStarted() {}
  bool freeze() {
    if (!canFreeze ||
        combatHealth.isDead ||
        isRemoving ||
        !freezeState.apply()) {
      return false;
    }
    _impactRemaining = 0;
    _pulseRemaining = 0;
    onFreezeStarted();
    return true;
  }

  int get xpReward => 1;
  int get scoreReward => 10;
  bool get isBoss => false;
  double get impactResponse => isBoss ? 0 : 1;
  double _impactRemaining = 0, _impactDuration = 1, _impactCooldown = 0;
  final _impactDirection = Vector2.zero();
  double _impactDistance = 0;
  double _pulseRemaining = 0, _pulseDistance = 0;
  final _pulseDirection = Vector2.zero();
  void receiveUpgradePulse(Vector2 direction, double distance) {
    if (freezeHeld ||
        impactResponse <= 0 ||
        combatHealth.isDead ||
        direction.isZero()) {
      return;
    }
    _pulseDirection.setFrom(direction.normalized());
    _pulseDistance = distance * impactResponse;
    _pulseRemaining = .32;
  }

  double get impactStride => _pulseRemaining > 0
      ? 0
      : _impactRemaining > 0
      ? 1 - .8 * impactResponse * (_impactRemaining / _impactDuration)
      : 1;

  /// One bounded response per target, not one stack per pellet. A cooldown
  /// leaves normal pursuit between bursts even with rapid-fire upgrades.
  void receiveBulletImpact(Vector2 direction, WeaponType weapon) {
    if (freezeHeld ||
        impactResponse <= 0 ||
        _impactCooldown > 0 ||
        direction.isZero() ||
        combatHealth.isDead ||
        isRemoving) {
      return;
    }
    final motion = WeaponFeel.impactMotion(weapon);
    _impactDirection.setFrom(direction.normalized());
    _impactDistance = motion.distance * impactResponse;
    _impactDuration = motion.duration;
    _impactRemaining = motion.duration;
    _impactCooldown = .24;
  }

  double _flash = 0;
  final _flashPaint = Paint()
    ..colorFilter = const ColorFilter.mode(
      Color(0xffFFF1D5),
      BlendMode.srcATop,
    );
  final _softFlashPaint = Paint()
    ..colorFilter = const ColorFilter.mode(
      Color(0xffF5D2AD),
      BlendMode.modulate,
    );
  Paint? get damagePaint => _flash > .05
      ? game.preferences.reducedMotion
            ? _softFlashPaint
            : _flashPaint
      : null;
  bool _rewarded = false;
  double? _restoredHealth, _restoredMaximum;
  Vector2? incomingDirection;
  bool incomingArmorPiercing = false;
  double burnRemaining = 0, _burnTick = 0, burnDamage = 0;
  double cinderRemaining = 0, cinderTick = 0;
  void igniteCinder() {
    cinderRemaining = 1;
  }

  bool burnCanSpread = true, marked = false, lastHitWasSecondary = false;
  bool get burning => burnRemaining > 0;

  void restoreHealth(double health, {double? maximum}) {
    _restoredMaximum = maximum;
    if (!health.isFinite || health <= 0) {
      throw const FormatException('Invalid enemy health');
    }
    if (isLoaded) {
      combatHealth.current = health.clamp(0, combatHealth.maximum);
    } else {
      _restoredHealth = health;
    }
  }

  void ignite(double damage, {bool maySpread = true}) {
    burnRemaining = 3;
    burnDamage = damage.clamp(0, 8);
    burnCanSpread = maySpread;
  }

  void initializeHealth(double maximum) {
    combatHealth = CombatHealth(_restoredMaximum ?? maximum);
    if (_restoredHealth != null) {
      combatHealth.current = _restoredHealth!.clamp(0, combatHealth.maximum);
    }
  }

  @override
  void onMount() {
    super.onMount();
    if (parent == game.world && !isBoss && !game.registerEnemy(this)) {
      removeFromParent();
      return;
    }
    if (parent == game.world && !game.reserveEnemySpace(this)) {
      removeFromParent();
    }
  }

  @override
  void onRemove() {
    game.unregisterEnemy(this);
    super.onRemove();
  }

  @override
  bool takeDamage(double amount) {
    if (isRemoving || game.gameState.gameplayState != GameplayState.playing) {
      return false;
    }
    final result = combatHealth.damage(amount);
    if (result == DamageResult.ignored) return false;
    _flash = 0.09;
    if (isBoss) game.revision.value++;
    if (result == DamageResult.killed && !_rewarded) {
      _rewarded = true;
      game.enemyDefeated(this, xp: xpReward, score: scoreReward, boss: isBoss);
      onCombatDeath();
    }
    return true;
  }

  void onCombatDeath();

  @override
  void update(double dt) {
    final wasFrozen = freezeHeld;
    if (game.gameState.gameplayState == GameplayState.playing) {
      freezeState.advance(dt);
    }
    if (this is SpriteAnimationComponent && (wasFrozen || freezeHeld)) {
      (this as SpriteAnimationComponent).playing = !freezeHeld;
    }
    super.update(dt);
    priority = 10000 + (position.y + size.y * .35).round();
    _flash = (_flash - dt).clamp(0, 0.12);
    if (game.gameState.gameplayState == GameplayState.playing &&
        !combatHealth.isDead) {
      if (_pulseRemaining > 0) {
        final step = dt.clamp(0.0, _pulseRemaining),
            next = _pulseRemaining - step;
        final fraction =
            (_pulseRemaining * _pulseRemaining - next * next) / (.32 * .32);
        game.moveTo(
          this,
          position + _pulseDirection * (_pulseDistance * fraction),
          game.crowdRadius(this),
        );
        _pulseRemaining = next;
      }
      _impactCooldown = (_impactCooldown - dt).clamp(0, .24);
      if (_impactRemaining > 0) {
        final step = dt.clamp(0.0, _impactRemaining);
        final next = _impactRemaining - step;
        final travel =
            (_impactRemaining * _impactRemaining - next * next) /
            (_impactDuration * _impactDuration);
        // Uses body occupancy and wall substeps; never shove through a body.
        game.moveTo(
          this,
          position + _impactDirection * (_impactDistance * travel),
          game.crowdRadius(this),
        );
        _impactRemaining = (_impactRemaining - dt).clamp(0, _impactDuration);
      }
    }
    if (game.gameState.gameplayState == GameplayState.playing &&
        !combatHealth.isDead &&
        cinderRemaining > 0) {
      final step = dt.clamp(0.0, cinderRemaining);
      cinderRemaining -= step;
      cinderTick += step;
      while (cinderTick >= .5 - 1e-8 && !combatHealth.isDead) {
        cinderTick = (cinderTick - .5).clamp(0, .5);
        lastHitWasSecondary = true;
        takeDamage(.3);
      }
      if (cinderRemaining <= 1e-8) {
        cinderRemaining = 0;
        cinderTick = 0;
      }
    }
    // Sprite enemies draw themselves; boss bodies live one level below the root.
    final bodies = this is SpriteAnimationComponent
        ? [this as SpriteAnimationComponent]
        : children.whereType<SpriteAnimationComponent>();
    for (final body in bodies) {
      body.paint.colorFilter =
          damagePaint?.colorFilter ??
          (isBoss ? BossArt.ambient(game.loadout.arena) : null);
    }
    if (game.gameState.gameplayState == GameplayState.playing &&
        burning &&
        !combatHealth.isDead) {
      burnRemaining -= dt;
      _burnTick += dt;
      if (_burnTick >= 0.5) {
        _burnTick = 0;
        lastHitWasSecondary = true;
        takeDamage(burnDamage);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (freezeState.frozen && !combatHealth.isDead) {
      final center = (size / 2).toOffset();
      for (final side in [-1, 1]) {
        AttackVfx.chip(
          canvas,
          center + Offset(side * size.x * .3, size.y * .18),
          9,
          const Color(0xffA9C9C7),
        );
      }
    }
    if ((burning || cinderRemaining > 0) && !combatHealth.isDead) {
      canvas.drawRect(
        Rect.fromCenter(center: (size / 2).toOffset(), width: 12, height: 18),
        Paint()..color = const Color(0xA6E99B64),
      );
    }
    if (marked && !combatHealth.isDead) {
      final c = (size / 2).toOffset(), r = size.x * .3;
      for (final sign in [-1, 1]) {
        AttackVfx.stroke(
          canvas,
          [
            c + Offset(sign * r, -8),
            c + Offset(sign * r, -r),
            c + Offset(sign * (r - 8), -r),
          ],
          const Color(0xffDAC18A),
          3,
        );
      }
    }
    if (_flash > 0) {
      AttackVfx.chip(canvas, (size / 2).toOffset(), 9, const Color(0xffD5B88B));
    }
    if (!isBoss && !combatHealth.isDead && combatHealth.fraction < 1) {
      final width = size.x * 0.45;
      final left = (size.x - width) / 2;
      canvas.drawRect(
        Rect.fromLTWH(left, size.y * 0.28, width, 4),
        Paint()..color = const Color(0xff211B25),
      );
      canvas.drawRect(
        Rect.fromLTWH(left, size.y * 0.28, width * combatHealth.fraction, 4),
        Paint()..color = const Color(0xffDBAA67),
      );
    }
  }
}
