part of 'arsenal_system.dart';

/// Paid, finite flight. An acquisition belongs to one rocket, never held input.
class FrontierShot {
  FrontierShot(
    this.id,
    this.position,
    this.direction,
    this.damage,
    this.speed,
    this.range,
    this.payload, {
    this.target,
  });
  final int id;
  final Vector2 position, direction;
  final double damage, speed, range, payload;
  int? target;
  double age = 0, travelled = 0, tick = 0;
  bool spent = false;
  final arcs = <({Vector2 from, Vector2 to})>[];
  final crossed = <int>{};
  Map<String, dynamic> toJson() => {
    'id': id,
    'position': [position.x, position.y],
    'direction': [direction.x, direction.y],
    'damage': damage,
    'speed': speed,
    'range': range,
    'payload': payload,
    'target': target,
    'crossed': crossed.toList(),
    'age': age,
    'travelled': travelled,
    'tick': tick,
  };
}

class CuttingRing {
  CuttingRing(
    this.id,
    this.center,
    this.damage,
    this.maximum, {
    Vector2? origin,
    Vector2? heading,
    this.gunLaunched = true,
  }) : origin = (origin ?? center).clone(),
       heading = (heading ?? Vector2(1, 0)).clone();
  final int id;
  final Vector2 center, origin, heading;
  final bool gunLaunched;
  final double damage, maximum;
  double radius = 8, age = 0, phaseTime = 0, returnFrom = 8;
  bool returning = false;
  final outward = <int>{}, inward = <int>{};
  Map<String, dynamic> toJson() => {
    'id': id,
    'center': [center.x, center.y],
    'origin': [origin.x, origin.y],
    'heading': [heading.x, heading.y],
    'gunLaunched': gunLaunched,
    'damage': damage,
    'maximum': maximum,
    'radius': radius,
    'age': age,
    'phaseTime': phaseTime,
    'returnFrom': returnFrom,
    'returning': returning,
    'outward': outward.toList(),
    'inward': inward.toList(),
  };
}

/// The three new primaries share release provenance and global reservations.
/// All damage advances on simulation substeps; rendering has no gameplay effects.
class FrontierArsenal {
  FrontierArsenal(this.system);
  final ArsenalSystem system;
  RegunGame get game => system.game;
  WeaponPowerBalance get balance => system.balance;
  WeaponType get weapon => system.weapon;
  bool get handles => {
    WeaponType.houndrack,
    WeaponType.stormOrb,
    WeaponType.ringCaster,
  }.contains(weapon);
  final shots = <FrontierShot>[];
  CuttingRing? ring;
  double _nextFlightCue = 0;
  int get effectCount => shots.length + (ring == null ? 0 : 1);
  double get ringProgress => ring == null
      ? 0
      : ring!.radius / (ring!.maximum * (ring!.gunLaunched ? .35 : 1));

  List<CombatEnemy>? _stepTargets;
  List<CombatEnemy> get targets => _stepTargets ?? collectTargets();
  List<CombatEnemy> collectTargets() =>
      game.liveEnemies
          .whereType<CombatEnemy>()
          .where((e) => !e.combatHealth.isDead && !e.isRemoving && !e.isRemoved)
          .toList()
        ..sort((a, b) => a.combatId.compareTo(b.combatId));
  void clear() {
    shots.clear();
    ring = null;
    _nextFlightCue = 0;
  }

  bool fire() {
    if (!handles || !system.ready) return false;
    final direction = system.aim;
    if (direction.isZero()) return false;
    if (weapon == WeaponType.ringCaster) {
      final origin = system.muzzle(direction);
      if (ring != null || game.segmentBlocked(game.myPlayer.position, origin)) {
        return false;
      }
      ring = CuttingRing(
        system.nextAttack,
        origin,
        system._releaseDamage(),
        system.effectiveRange,
        heading: direction,
      );
      system._released();
      return true;
    }
    final origin = system.muzzle(direction);
    final limit = weapon == WeaponType.houndrack
        ? balance.rocketLimit
        : balance.orbLimit;
    if (shots.length >= limit ||
        game.projectileCount >= RegunGame.maxProjectiles ||
        game.segmentBlocked(game.myPlayer.position, origin)) {
      return false;
    }
    int? acquisition;
    if (weapon == WeaponType.houndrack) {
      var best = double.infinity;
      for (final e in targets) {
        final delta = e.position - origin;
        if (delta.isZero() ||
            delta.length > system.effectiveRange ||
            game.segmentBlocked(origin, e.position)) {
          continue;
        }
        final angle = math.acos(
          delta.normalized().dot(direction).clamp(-1.0, 1.0),
        );
        // Small stick-directed cone; acquisition never searches behind the gun.
        final score = angle + delta.length * .00001;
        if (angle <= balance.rocketAcquireAngle * math.pi / 180 &&
            score < best) {
          acquisition = e.combatId;
          best = score;
        }
      }
    }
    final damage = system._releaseDamage();
    shots.add(
      FrontierShot(
        system.nextAttack,
        origin,
        direction.clone(),
        damage,
        system.state.bulletSpeed.clamp(100, 2000).toDouble(),
        system.effectiveRange,
        (weapon == WeaponType.houndrack
                ? balance.rocketSplashDamage
                : balance.orbArcDamage) *
            damage /
            balance.damage(weapon),
        target: acquisition,
      ),
    );
    system._released();
    return true;
  }

  void advance(double dt, {required bool held}) {
    if (!handles || (shots.isEmpty && ring == null)) return;
    _stepTargets = collectTargets();
    for (final f in shots.toList()) {
      f.age += dt;
      f.tick = math.max(0, f.tick - dt);
      if (f.tick <= 1e-8) f.arcs.clear();
      final before = f.position.clone();
      if (weapon == WeaponType.houndrack && f.target != null) {
        final enemy = targets.where((e) => e.combatId == f.target).firstOrNull;
        if (enemy == null || game.segmentBlocked(before, enemy.position)) {
          f.target = null;
        } else {
          final delta = enemy.position - before;
          if (!delta.isZero()) {
            final angle = math.atan2(
              f.direction.cross(delta),
              f.direction.dot(delta),
            );
            f.direction.rotate(
              angle
                  .clamp(
                    -balance.rocketTurnRate * dt,
                    balance.rocketTurnRate * dt,
                  )
                  .toDouble(),
            );
            f.direction.normalize();
          }
        }
      }
      final acceleration = weapon == WeaponType.houndrack
          ? .3 +
                .7 *
                    math.pow(
                      (f.age / balance.rocketAcceleration).clamp(0.0, 1.0),
                      1.4,
                    )
          : 1.0;
      final distance = math.min(
        f.speed * acceleration * dt,
        math.max(0.0, f.range - f.travelled),
      );
      final intended = before + f.direction * distance;
      final clipped = system.clip(before, intended);
      CombatEnemy? contact;
      var first = before.distanceTo(clipped);
      final crossings = <({CombatEnemy enemy, double distance})>[];
      for (final e in targets) {
        if (e.combatHealth.isDead) continue;
        final radius =
            game.crowdRadius(e) + (weapon == WeaponType.houndrack ? 4 : 13);
        final hit = BulletComponent.contactDistance(
          e.position,
          before,
          clipped,
          radius,
        );
        if (!hit.isFinite ||
            hit > before.distanceTo(clipped) ||
            BulletComponent.segmentDistanceSquared(
                  e.position,
                  before,
                  clipped,
                ) >
                radius * radius) {
          continue;
        }
        if (weapon == WeaponType.stormOrb) {
          if (!f.crossed.contains(e.combatId)) {
            crossings.add((enemy: e, distance: hit));
          }
        } else if (hit <= first) {
          first = hit;
          contact = e;
        }
      }
      final end = contact == null ? clipped : before + f.direction * first;
      if (weapon == WeaponType.stormOrb) {
        crossings.sort((a, b) => a.distance.compareTo(b.distance));
        var struck = false;
        for (final crossing in crossings) {
          if (f.crossed.length >= 64) break;
          // Record before callbacks: one extra crossing hit per body and paid orb.
          f.crossed.add(crossing.enemy.combatId);
          struck =
              system._direct(
                crossing.enemy,
                f.damage,
                f.direction,
                attackId: f.id,
                travel: f.travelled + crossing.distance,
                reaction: WeaponReaction.of(weapon),
              ) ||
              struck;
        }
        if (struck) system.audio.play('pass_stormOrb.wav');
      }
      f.position.setFrom(end);
      f.travelled += before.distanceTo(end);
      if (weapon == WeaponType.stormOrb && f.tick <= 1e-8) {
        _arcs(f);
        f.tick = balance.orbTick;
      }
      final stopped =
          contact != null ||
          clipped.distanceToSquared(intended) > .01 ||
          f.range - f.travelled <= .5 ||
          distance <= 1e-8 ||
          before.distanceToSquared(end) < 1e-12 ||
          f.age >= (weapon == WeaponType.stormOrb ? balance.orbLifetime : 3.0);
      if (!stopped) continue;
      // Mark terminal before damage callbacks can retire actors or save the run.
      f.spent = true;
      if (contact != null) {
        system._direct(
          contact,
          f.damage,
          f.direction,
          attackId: f.id,
          travel: f.travelled,
          reaction: WeaponReaction.of(weapon),
        );
      }
      if (weapon == WeaponType.houndrack && f.payload > 0) {
        for (final e in targets) {
          if (e.combatHealth.isDead ||
              e == contact ||
              e.position.distanceTo(end) >
                  balance.rocketSplashRadius + game.crowdRadius(e) ||
              game.segmentBlocked(end, e.position)) {
            continue;
          }
          game.hitEnemy(
            e,
            f.payload,
            primary: false,
            direction: e.position - end,
            reaction: WeaponReaction.of(weapon).scaled(.35),
          );
        }
      }
      if (game.claimWeaponImpact()) {
        game.addCombatEffect(
          WeaponImpact(
            position: end.clone(),
            weapon: weapon,
            direction: f.direction,
          ),
        );
      }
      system.audio.play('impact_${weapon.name}.wav');
    }
    shots.removeWhere((f) => f.spent);
    if (shots.any((f) => f.age >= .08) && system.clock >= _nextFlightCue) {
      system.audio.play('flight_${weapon.name}.wav');
      _nextFlightCue =
          system.clock + (weapon == WeaponType.houndrack ? .22 : .32);
    }
    _advanceRing(dt, held);
    _stepTargets = null;
  }

  void _arcs(FrontierShot f) {
    final nearby =
        targets
            .where(
              (e) =>
                  !e.combatHealth.isDead &&
                  e.position.distanceTo(f.position) <=
                      balance.orbArcRadius + game.crowdRadius(e) &&
                  !game.segmentBlocked(f.position, e.position),
            )
            .toList()
          ..sort(
            (a, b) => a.position
                .distanceToSquared(f.position)
                .compareTo(b.position.distanceToSquared(f.position)),
          );
    var zapped = false;
    for (final e in nearby.take(balance.orbTargets)) {
      // Secondary ticks never run primary chains, first/last-round or force again.
      if (game.hitEnemy(e, f.payload, primary: false)) {
        zapped = true;
        f.arcs.add((from: f.position.clone(), to: e.position.clone()));
      }
    }
    if (zapped) system.audio.play('zap_stormOrb.wav');
  }

  void _advanceRing(double dt, bool held) {
    final r = ring;
    if (r == null) return;
    final oldCenter = r.center.clone(), oldRadius = r.radius;
    r.age += dt;
    if (!r.returning &&
        (!held || r.age >= balance.ringExpand + balance.ringHold)) {
      r.returning = true;
      r.returnFrom = r.radius;
      r.phaseTime = 0;
      system.audio.play('return_ringCaster.wav');
    }
    final previousPhaseTime = r.phaseTime;
    r.phaseTime += dt;
    final progress = (r.age / balance.ringExpand).clamp(0.0, 1.0);
    final maximumRadius = r.maximum * (r.gunLaunched ? .35 : 1);
    final startRadius = r.gunLaunched ? 8.0 : 24.0;
    r.radius = r.returning
        ? math.max(0, r.returnFrom * (1 - r.phaseTime / balance.ringRetract))
        : startRadius + (maximumRadius - startRadius) * progress;
    if (!r.gunLaunched) {
      r.center.setFrom(game.myPlayer.position);
    } else if (r.returning) {
      final gun = system.muzzle(game.myPlayer.aimDirection);
      final fraction =
          (dt / math.max(dt, balance.ringRetract - previousPhaseTime)).clamp(
            0.0,
            1.0,
          );
      r.center.setFrom(
        system.clip(oldCenter, oldCenter + (gun - oldCenter) * fraction),
      );
    } else {
      // Committed travel plus cutting radius equals the existing authored reach.
      r.center.setFrom(
        system.clip(
          r.origin,
          r.origin + r.heading * (r.maximum * .65 * progress),
        ),
      );
    }
    final ledger = r.returning ? r.inward : r.outward;
    for (final e in targets) {
      if (ledger.length >= balance.ringTargets) break;
      if (e.combatHealth.isDead ||
          ledger.contains(e.combatId) ||
          game.segmentBlocked(r.center, e.position)) {
        continue;
      }
      final before = e.position.distanceTo(oldCenter) - oldRadius;
      final after = e.position.distanceTo(r.center) - r.radius;
      final extent = game.crowdRadius(e) + balance.ringThickness / 2;
      if (math.min(before, after) > extent ||
          math.max(before, after) < -extent) {
        continue;
      }
      ledger.add(e.combatId);
      final context = system._releaseContexts[r.id];
      game.hitEnemy(
        e,
        r.damage * (r.returning ? balance.ringReturnScale : 1),
        primary: false,
        weaponHit: true,
        releaseId: context?.$1 ?? 0,
        releaseBonus: context?.$2 ?? 0,
        direction: e.position - r.center,
        reaction: WeaponReaction.of(weapon),
      );
      if (game.claimWeaponImpact()) {
        game.addCombatEffect(
          WeaponImpact(
            position: e.position.clone(),
            weapon: weapon,
            direction: e.position - r.center,
          ),
        );
      }
    }
    if (r.returning && r.radius <= .01) {
      ring = null;
      if (system.state.noOfBullets == 0 && !system.state.reloading) {
        game.gameNotifier.reloadBullets();
      }
    }
  }

  Map<String, dynamic> checkpoint() => {
    'schema': 2,
    'shots': [
      for (final f in shots)
        if (!f.spent) f.toJson(),
    ],
    if (ring != null) 'ring': ring!.toJson(),
  };

  static void validate(dynamic raw, WeaponType weapon, dynamic nextAttack) {
    final handles = {
      WeaponType.houndrack,
      WeaponType.stormOrb,
      WeaponType.ringCaster,
    }.contains(weapon);
    if (raw == null) return; // Old checkpoints have no frontier packet.
    if (!handles ||
        raw is! Map ||
        ![1, 2].contains(raw['schema']) ||
        raw['shots'] is! List ||
        raw['shots'].length > (weapon == WeaponType.stormOrb ? 3 : 12) ||
        nextAttack is! int) {
      throw const FormatException('Invalid frontier arsenal');
    }
    final ids = <int>{};
    void number(dynamic v, double maximum) {
      if (v is! num || !v.isFinite || v < 0 || v > maximum) {
        throw const FormatException('Invalid frontier number');
      }
    }

    void point(dynamic v, {bool direction = false}) {
      if (v is! List ||
          v.length != 2 ||
          v.any((n) => n is! num || !n.isFinite || n.abs() > 10000)) {
        throw const FormatException('Invalid frontier point');
      }
      if (direction && ((v[0] * v[0] + v[1] * v[1]) - 1).abs() > .01) {
        throw const FormatException('Invalid frontier direction');
      }
    }

    void id(dynamic v) {
      if (v is! int || v < 1 || v >= nextAttack || !ids.add(v)) {
        throw const FormatException('Invalid frontier attack');
      }
    }

    for (final f in raw['shots']) {
      if (f is! Map || weapon == WeaponType.ringCaster) {
        throw const FormatException('Unexpected frontier flight');
      }
      id(f['id']);
      point(f['position']);
      point(f['direction'], direction: true);
      for (final key in ['damage', 'payload']) {
        number(f[key], 10000);
      }
      number(f['speed'], 2000);
      number(f['range'], 2000);
      if (f['speed'] < 100 || f['range'] < 60) {
        throw const FormatException('Invalid flight bounds');
      }
      number(f['age'], 6);
      number(f['travelled'], f['range'].toDouble());
      number(f['tick'], 1);
      if (raw['schema'] == 2 && f['crossed'] == null) {
        throw const FormatException('Missing orb crossing ledger');
      }
      if (f['crossed'] != null) {
        final ledger = f['crossed'];
        if (ledger is! List ||
            ledger.length > 64 ||
            ledger.toSet().length != ledger.length ||
            ledger.any((id) => id is! int || id < 1 || id > 1e9) ||
            (weapon != WeaponType.stormOrb && ledger.isNotEmpty)) {
          throw const FormatException('Invalid orb crossing ledger');
        }
      }
      if (f['target'] != null &&
          (weapon != WeaponType.houndrack ||
              f['target'] is! int ||
              f['target'] < 1)) {
        throw const FormatException('Invalid rocket acquisition');
      }
    }
    if (raw['ring'] != null) {
      final r = raw['ring'];
      if (weapon != WeaponType.ringCaster ||
          r is! Map ||
          r['returning'] is! bool) {
        throw const FormatException('Invalid cutting ring');
      }
      id(r['id']);
      point(r['center']);
      if (raw['schema'] == 2) {
        point(r['origin']);
        point(r['heading'], direction: true);
        if (r['gunLaunched'] is! bool) {
          throw const FormatException('Invalid ring launch');
        }
      }
      number(r['damage'], 10000);
      number(r['maximum'], 2000);
      if (r['maximum'] < 60) throw const FormatException('Invalid ring reach');
      number(r['radius'], r['maximum'].toDouble());
      number(r['returnFrom'], r['maximum'].toDouble());
      number(r['age'], 10);
      number(r['phaseTime'], 10);
      for (final key in ['outward', 'inward']) {
        final list = r[key];
        if (list is! List ||
            list.length > 12 ||
            list.toSet().length != list.length ||
            list.any((id) => id is! int || id < 1 || id > 1e9)) {
          throw const FormatException('Invalid ring hit ledger');
        }
      }
    }
  }

  void restore(dynamic raw) {
    clear();
    if (raw == null) return;
    Vector2 point(dynamic v) =>
        Vector2((v[0] as num).toDouble(), (v[1] as num).toDouble());
    for (final f in raw['shots']) {
      shots.add(
        FrontierShot(
            f['id'],
            point(f['position']),
            point(f['direction']),
            (f['damage'] as num).toDouble(),
            (f['speed'] as num).toDouble(),
            (f['range'] as num).toDouble(),
            (f['payload'] as num).toDouble(),
            target: f['target'],
          )
          ..age = (f['age'] as num).toDouble()
          ..travelled = (f['travelled'] as num).toDouble()
          ..tick = (f['tick'] as num).toDouble()
          ..crossed.addAll((f['crossed'] as List? ?? []).cast<int>()),
      );
    }
    if (raw['ring'] case final Map r) {
      ring =
          CuttingRing(
              r['id'],
              point(r['center']),
              (r['damage'] as num).toDouble(),
              (r['maximum'] as num).toDouble(),
              origin: r['origin'] == null ? null : point(r['origin']),
              heading: r['heading'] == null ? null : point(r['heading']),
              gunLaunched: r['gunLaunched'] == true,
            )
            ..radius = (r['radius'] as num).toDouble()
            ..age = (r['age'] as num).toDouble()
            ..phaseTime = (r['phaseTime'] as num).toDouble()
            ..returnFrom = (r['returnFrom'] as num).toDouble()
            ..returning = r['returning']
            ..outward.addAll((r['outward'] as List).cast<int>())
            ..inward.addAll((r['inward'] as List).cast<int>());
      // No held input survives Continue: a paid ring returns on active resume.
    }
  }

  void render(Canvas canvas, Rect view) {
    final reduced = game.preferences.reducedMotion;
    for (final f in shots) {
      if (!view.contains(f.position.toOffset())) continue;
      if (weapon == WeaponType.houndrack) {
        FrontierVfx.rocket(
          canvas,
          f.position.toOffset(),
          f.direction.toOffset(),
          f.age,
          reduced,
          (f.age / balance.rocketAcceleration).clamp(0.0, 1.0),
        );
      } else {
        FrontierVfx.orb(canvas, f.position.toOffset(), f.age, reduced);
        for (final arc in f.arcs) {
          AttackVfx.lightning(
            canvas,
            arc.from.toOffset(),
            system.clip(arc.from, arc.to).toOffset(),
            (f.tick / balance.orbTick).clamp(0.0, 1.0),
            heavy: false,
          );
        }
      }
    }
    final r = ring;
    if (r != null && game.ringArtReady) {
      FrontierVfx.ring(
        canvas,
        RegunArt.shared.image('effects/cutter_ring'),
        r.center.toOffset(),
        r.radius,
        balance.ringThickness,
        r.age,
        r.returning,
        reduced,
        (direction) =>
            system
                .clip(
                  r.center,
                  r.center + Vector2(direction.dx, direction.dy) * r.radius,
                )
                .distanceTo(r.center) >=
            r.radius - 1,
      );
    }
  }
}
