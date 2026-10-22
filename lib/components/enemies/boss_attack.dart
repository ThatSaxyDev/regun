import 'package:regun/data/enemies.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/models/combat_health.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/systems/boss_attack_shape.dart';

class BossAttack extends PositionComponent with HasGameReference<RegunGame> {
  BossAttack({
    required this.shape,
    required this.owner,
    required this.warning,
    required this.active,
    this.delay = 0,
    this.material = AttackMaterial.stone,
    this.damage = 1,
    this.cause = 'Boss strike',
    this.color = const Color(0xffDDA46E),
    this.sound = 'impact_boss.wav',
    this.onImpact,
    this.bossKind,
  }) : super(priority: material == AttackMaterial.laser ? 20010 : -10);
  final BossKind? bossKind;
  final BossAttackShape shape;
  final CombatHealth owner;
  final double warning, active, delay;
  final int damage;
  final String cause, sound;
  final Color color;
  final AttackMaterial material;
  final VoidCallback? onImpact;
  double age = 0;
  Vector2? _warningFocus;
  bool _hit = false, _sounded = false;
  double get remaining =>
      (delay + warning + active - age).clamp(0, double.infinity);
  double get progress => ((age - delay - warning) / active).clamp(0, 1);

  @override
  Future<void> onLoad() async {
    _warningFocus = game.myPlayer.position.clone();
    if (!game.registerBossAttack(this)) removeFromParent();
  }

  @override
  void onRemove() {
    game.unregisterBossAttack(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isRemoving || owner.isDead) {
      removeFromParent();
      return;
    }
    if (game.gameState.gameplayState != GameplayState.playing) return;
    final previous = progress;
    age += dt;
    if (age >= delay + warning && !_sounded) {
      _sounded = true;
      onImpact?.call();
      game.audio.play(sound);
    }
    if (age >= delay + warning &&
        !_hit &&
        shape.hits(game.myPlayer.position, progress, previous: previous) &&
        !game.segmentBlocked(shape.points.first, game.myPlayer.position)) {
      if (game.damagePlayer(amount: damage, cause: cause)) _hit = true;
    }
    if (age >= delay + warning + active) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (age < delay) return;
    shape.render(
      canvas,
      bossKind: bossKind,
      warning: age < delay + warning,
      progress: progress,
      color: color,
      ambient: BossArt.ambient(game.loadout.arena),
      warningFocus: _warningFocus,
      reducedMotion: game.preferences.reducedMotion,
      warningProgress: ((age - delay) / warning).clamp(0, 1),
      material: material,
    );
  }
}
