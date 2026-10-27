import 'package:regun/systems/friendly_impact.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/presentation/attack_vfx.dart';

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/game.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/systems/support_runtime.dart';
import 'package:regun/systems/support_aim.dart';
import 'package:regun/systems/weapon_ballistics.dart';
import 'package:regun/systems/weapon_reaction.dart';
import 'package:regun/data/loadout.dart';

class SupportNative {
  SupportNative(this.game);
  final RegunGame game;
  final runtime = SupportRuntime();
  int? ignored;
  final traces = <SupportTrace>[];
  final _targetHistory = <int, Offset>{};
  SupportConfig get config =>
      SupportConfig(game.gameNotifier.weaponPower.snapshot?.values ?? {});
  Iterable<Rect> get solids => runtime.units
      .where((u) => u.solid && u.serial != ignored)
      .map((u) => u.footprint);
  Iterable<Rect> get reservations => runtime.reservations;
  void clear() {
    runtime.clear(game.gameNotifier.support);
    traces.clear();
    _targetHistory.clear();
  }

  void restore(dynamic raw) {
    runtime.restore(raw, game.gameNotifier.support, config);
    for (final u in runtime.units.where((u) => u.reserved)) {
      if (!game.map.bounds.floor.contains(u.footprint.topLeft) ||
          !game.map.bounds.floor.contains(u.footprint.bottomRight) ||
          game.geometry.obstacles.any((r) => r.overlaps(u.footprint))) {
        throw const FormatException('Invalid support placement');
      }
    }
  }

  List<SupportTarget> targets(double dt) {
    final samples = <int, Offset>{};
    final result = game.liveEnemies.map((e) {
      final id = (e as CombatEnemy).combatId, p = e.position.toOffset();
      final previous = _targetHistory[id];
      samples[id] = p;
      return SupportTarget(
        '$id',
        p,
        game.enemyRadius(e),
        velocity: previous == null || dt <= 0 || dt > .1
            ? Offset.zero
            : (p - previous) / dt,
      );
    }).toList();
    _targetHistory
      ..clear()
      ..addAll(samples);
    return result;
  }

  PositionComponent? actor(String id) => game.liveEnemies
      .where((e) => '${(e as CombatEnemy).combatId}' == id)
      .firstOrNull;
  bool blocked(Offset a, Offset b, SupportUnit? self, {double clearance = 0}) =>
      game.geometry.solids
          .where((r) => self == null || r != self.footprint)
          .any(
            (r) => ArenaGeometry.crosses(
              Vector2(a.dx, a.dy),
              Vector2(b.dx, b.dy),
              r.inflate(clearance),
            ),
          );
  Offset? place(Offset p, SupportUnit unit) {
    for (var i = 0; i < 32; i++) {
      final ring = i == 0 ? 0 : 1 + (i - 1) ~/ 8;
      final angle = (i % 8) * pi / 4;
      final candidate = p + Offset(cos(angle), sin(angle)) * (ring * 60.0);
      final rect = Rect.fromLTWH(
        candidate.dx - 35,
        candidate.dy - 44,
        70,
        44,
      ).inflate(32);
      final floor = game.map.bounds.floor.deflate(35);
      if (!floor.contains(rect.topLeft) || !floor.contains(rect.bottomRight)) {
        continue;
      }
      if (game.geometry.solids.any((r) => r.overlaps(rect))) continue;
      if (runtime.units.any(
        (u) =>
            u != unit &&
            u.reserved &&
            ((u.position - candidate).distance < 160 ||
                u.footprint.overlaps(rect)),
      )) {
        continue;
      }
      return candidate;
    }
    return null;
  }

  void hit(
    PositionComponent target,
    double damage,
    String source, {
    Vector2? direction,
    bool ballistic = false,
    WeaponReaction? reaction,
  }) {
    final owner = game.projectileOwner(target) as CombatEnemy;
    final before = owner.combatHealth.current;
    game.combat.hit(
      target,
      damage,
      primary: false,
      supportBallistic: ballistic,
      direction: direction,
      reaction: reaction,
      source: source,
    );
    runtime.metrics[source] =
        (runtime.metrics[source] ?? 0) +
        max(0, before - owner.combatHealth.current);
  }

  void impact(SupportUnit u, bool breaking) {
    game.addCombatEffect(
      CombatEffect(
        position: Vector2(u.position.dx, u.position.dy),
        radius: 335,
        material: AttackMaterial.ember,
        duration: .48,
      ),
    );
    ignored = u.serial;
    try {
      for (final e in game.liveEnemies.toList()) {
        final enemy = e as CombatEnemy,
            delta = e.position.toOffset() - u.position;
        if (blocked(u.position, e.position.toOffset(), u)) continue;
        final body = game.enemyRadius(e),
            blastBody = game.crowdRadius(e),
            distance = delta.distance;
        if (distance <= FriendlyImpact.crushRadius + body) {
          hit(
            e,
            FriendlyImpact.crushDamage(
              boss: enemy.isBoss,
              maximum: enemy.combatHealth.maximum,
              current: enemy.combatHealth.current,
            ),
            breaking ? 'sentry_break_crush' : 'sentry_land_crush',
          );
        }
        if (enemy.combatHealth.isDead) continue;
        final direction = delta.distance == 0
            ? Vector2(1, 0)
            : Vector2(delta.dx, delta.dy).normalized();
        if (distance <= FriendlyImpact.blastRadius + blastBody) {
          hit(
            e,
            FriendlyImpact.blastDamage,
            breaking ? 'sentry_break_blast' : 'sentry_land_blast',
            direction: direction,
            reaction: WeaponReaction.grenade,
          );
        } else if (distance <=
            FriendlyImpact.blastRadius +
                FriendlyImpact.pressureBand +
                blastBody) {
          enemy.receiveWeaponImpact(
            direction,
            WeaponReaction.grenade.scaled(
              (1 - (distance - 205 - blastBody) / (130 + blastBody)).clamp(
                .35,
                1,
              ),
              hold: true,
            ),
          );
        }
      }
    } finally {
      ignored = null;
    }
    game.constrainActor(
      game.myPlayer.position,
      30,
      bottomExtent: game.myPlayer.boundaryFootExtent,
    );
    for (final e in game.liveEnemies.toList()) {
      game.moveTo(e, e.position.clone(), game.crowdRadius(e));
    }
  }

  void advance(double dt) {
    for (final trace in traces) {
      trace.age += dt;
    }
    traces.removeWhere((trace) => trace.age >= SupportTrace.duration);
    final sampled = targets(dt);
    final progress = game.gameNotifier.support;
    runtime.advance(
      dt,
      player: game.myPlayer.position.toOffset(),
      progress: progress,
      config: config,
      targets: () => sampled,
      place: place,
      // A gun's legal shot uses its round width. Aura/blast sight stays unchanged.
      blocked: (a, b, self) =>
          blocked(a, b, self, clearance: self == null ? 0 : 5),
      impact: impact,
      release: (u, p, d, damage) {
        if (runtime.rounds.length >= 8 ||
            game.projectileCount >= RegunGame.maxProjectiles - 24) {
          return false;
        }
        runtime.rounds.add(
          SupportRound(
            u.serial,
            u.card.mount,
            p,
            d,
            damage,
            config.weapon(
              u.card.mount,
              'speed',
              u.card.mount == 'carbine' ? 950 : 1100,
            ),
            config.weapon(
              u.card.mount,
              'range',
              u.card.mount == 'carbine' ? 650 : 700,
            ),
          )..delay = runtime.frameOffset,
        );
        game.upgradePresentation.observe('support:sentry', 'Sentry firing');
        return true;
      },
      auraHit: (target, damage) {
        final e = actor(target.id);
        if (e != null) {
          hit(e, damage, 'aura');
        }
      },
      cue: (u, cue) {
        game.audio.play(switch (cue) {
          'fire' =>
            u.card.mount == 'carbine' ? 'sentry_fire.wav' : 'sentry_burst.wav',
          'reload' => 'sentry_reload.wav',
          'land' => 'supply_land.wav',
          'break' => 'supply_break.wav',
          'activate' => 'aura_start.wav',
          'shutdown' => 'aura_end.wav',
          _ => 'sentry_incoming.wav',
        });
      },
    );
    // Physical rounds own no primary procs, homing, ricochets or knockback.
    for (final r in runtime.rounds.toList()) {
      final flight = min(
        r.speed * max(0, min(dt, .5) - r.delay),
        r.range - r.travel,
      );
      final before = Vector2(r.position.dx, r.position.dy),
          delta = Vector2(r.direction.dx, r.direction.dy) * flight;
      r.delay = 0;
      var end = before + delta;
      final own = runtime.units.where((u) => u.serial == r.serial).firstOrNull;
      final cover = game.geometry.solids
          .where((rect) => own == null || rect != own.footprint)
          .map((rect) => rect.inflate(5))
          .toList();
      bool blockedFlight(Vector2 a, Vector2 b) =>
          cover.any((rect) => ArenaGeometry.crosses(a, b, rect));
      final hitCover = blockedFlight(before, end);
      if (hitCover) {
        var low = 0.0, high = 1.0;
        for (var i = 0; i < 16; i++) {
          final middle = (low + high) / 2;
          if (blockedFlight(before, before + delta * middle)) {
            high = middle;
          } else {
            low = middle;
          }
        }
        end = before + delta * low;
      }
      final hits =
          game.projectileTargets
              .where(
                (t) =>
                    BulletComponent.segmentDistanceSquared(
                      t.position,
                      before,
                      end,
                    ) <=
                    pow(game.enemyRadius(t) + 5, 2),
              )
              .toList()
            ..sort(
              (a, b) =>
                  BulletComponent.contactDistance(
                    a.position,
                    before,
                    end,
                    game.enemyRadius(a) + 5,
                  ).compareTo(
                    BulletComponent.contactDistance(
                      b.position,
                      before,
                      end,
                      game.enemyRadius(b) + 5,
                    ),
                  ),
            );
      if (hits.isNotEmpty) {
        final hit = hits.first;
        final travel =
            r.travel +
            BulletComponent.contactDistance(
              hit.position,
              before,
              end,
              game.enemyRadius(hit) + 5,
            );
        final contact =
            before +
            Vector2(r.direction.dx, r.direction.dy) * (travel - r.travel);
        _trace(before.toOffset(), contact.toOffset(), r.direction);
        this.hit(
          hit,
          r.damage *
              WeaponBallistics.of(
                r.mount == 'carbine'
                    ? WeaponType.carbine
                    : WeaponType.burstRifle,
                power: game.gameNotifier.weaponPower,
              ).multiplier(travel),
          'sentry_round',
          ballistic: true,
          direction: Vector2(r.direction.dx, r.direction.dy),
        );
        runtime.rounds.remove(r);
        continue;
      }
      r.position = end.toOffset();
      // Vector2 stores Float32 coordinates. Rounding can shorten an unobstructed
      // step; it is never evidence of a wall. Keep open-flight range in doubles.
      r.travel += hitCover ? (end - before).length : flight;
      if (r.travel + 1e-6 >= r.range ||
          hitCover ||
          !game.map.bounds.floor.contains(r.position)) {
        _trace(before.toOffset(), end.toOffset(), r.direction);
        runtime.rounds.remove(r);
      }
    }
  }

  void _trace(Offset from, Offset to, Offset direction) {
    if (traces.length >= 24) traces.removeAt(0);
    traces.add(SupportTrace(from, to, direction));
  }
}
