import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/models/combat_health.dart';
import 'package:regun/notifiers/game_notifier.dart';

/// Shared damage/reward path for every active enemy, including bosses.
mixin CombatEnemy
    on PositionComponent, HasGameReference<RegunGame>
    implements Damageable {
  @override
  late final CombatHealth combatHealth;
  int get xpReward => 1;
  int get scoreReward => 10;
  bool get isBoss => false;
  double _flash = 0;
  final _flashPaint = Paint()
    ..colorFilter =
        const ColorFilter.mode(Color(0xffFFF1D5), BlendMode.srcATop);
  final _softFlashPaint = Paint()
    ..colorFilter =
        const ColorFilter.mode(Color(0xffF5D2AD), BlendMode.modulate);
  Paint? get damagePaint => _flash > .05
      ? game.preferences.reducedMotion
          ? _softFlashPaint
          : _flashPaint
      : null;
  bool _rewarded = false;
  double? _restoredHealth, _restoredMaximum;
  Vector2? incomingDirection;
  double burnRemaining = 0, _burnTick = 0, burnDamage = 0;
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
    super.update(dt);
    priority = 10000 + (position.y + size.y * .35).round();
    _flash = (_flash - dt).clamp(0, 0.12);
    // Sprite enemies draw themselves; boss bodies live one level below the root.
    final bodies = this is SpriteAnimationComponent
        ? [this as SpriteAnimationComponent]
        : children.whereType<SpriteAnimationComponent>();
    for (final body in bodies) {
      body.paint.colorFilter = damagePaint?.colorFilter;
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
    if (burning && !combatHealth.isDead) {
      canvas.drawRect(
          Rect.fromCenter(center: (size / 2).toOffset(), width: 12, height: 18),
          Paint()..color = const Color(0xA6E99B64));
    }
    if (marked && !combatHealth.isDead) {
      canvas.drawCircle(
          (size / 2).toOffset(),
          (size.x < size.y ? size.x : size.y) * 0.35,
          Paint()
            ..color = const Color(0xffE3C87D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    if (_flash > 0) {
      canvas.drawCircle(
          (size / 2).toOffset(), 16, Paint()..color = const Color(0x99F1C77C));
    }
    if (!isBoss && !combatHealth.isDead && combatHealth.fraction < 1) {
      final width = size.x * 0.45;
      final left = (size.x - width) / 2;
      canvas.drawRect(Rect.fromLTWH(left, size.y * 0.28, width, 4),
          Paint()..color = const Color(0xff211B25));
      canvas.drawRect(
          Rect.fromLTWH(left, size.y * 0.28, width * combatHealth.fraction, 4),
          Paint()..color = const Color(0xffDBAA67));
    }
  }
}
