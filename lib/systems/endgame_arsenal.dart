part of 'arsenal_system.dart';

/// Finite committed attacks. Input is deliberately absent from their snapshots.
class CommittedArea {
  CommittedArea(
    this.id,
    this.position,
    this.direction,
    this.range,
    this.damage,
  );
  final int id;
  final Vector2 position, direction;
  final double range, damage;
  double age = 0;
  int next = 0;
  bool resolved = false;
  final owners = <int, double>{};
  Map<String, dynamic> toJson() => {
    'id': id,
    'position': [position.x, position.y],
    'direction': [direction.x, direction.y],
    'range': range,
    'damage': damage,
    'age': age,
    'next': next,
    'resolved': resolved,
    'owners': [
      for (final e in owners.entries) [e.key, e.value],
    ],
  };
}

class EndgameArsenal {
  EndgameArsenal(this.system);
  final ArsenalSystem system;
  RegunGame get game => system.game;
  final anchors = <CommittedArea>[],
      lanes = <CommittedArea>[],
      echoes = <CommittedArea>[];
  int get effectCount => anchors.length + lanes.length + echoes.length;
  int? _primeOwner;
  bool _fatalBrand = false;
  bool get brandReady => _primeOwner != null;
  int _primeShot = 0, _minimumPairShot = 0;
  double _primeUntil = 0;
  final _acceptedShots = <int, double>{};
  final _pendingShots = <int, int>{};
  int ownerId(PositionComponent target) {
    final owner = game.projectileOwner(target);
    return owner is CombatEnemy ? owner.combatId : identityHashCode(owner);
  }

  void beginShot(int shot, int count) => _pendingShots[shot] = count;
  double pairMultiplier(PositionComponent target, int shot) =>
      shot >= _minimumPairShot &&
          !system.state.reloading &&
          !_acceptedShots.containsKey(shot) &&
          (_primeOwner == ownerId(target) || _fatalBrand) &&
          shot > _primeShot &&
          shot % 2 != _primeShot % 2 &&
          system.clock < _primeUntil
      ? 1.8
      : 1;
  bool acceptPair(
    PositionComponent target,
    int shot, {
    Vector2? direction,
    double amount = 0,
  }) {
    if (_acceptedShots.containsKey(shot)) return false;
    final paired = pairMultiplier(target, shot) > 1;
    _acceptedShots[shot] = system.clock;
    if (shot < _primeShot ||
        shot < _minimumPairShot ||
        system.state.reloading) {
      return false;
    }
    _primeShot = shot;
    _primeOwner = paired ? null : ownerId(target);
    _fatalBrand =
        !paired && target is CombatEnemy && target.combatHealth.isDead;
    _primeUntil = system.clock + 1.25;
    if (direction != null) {
      if (paired) {
        _verdict(target, direction, amount * .4);
      } else {
        system.audio.play('prime_twinVerdict.wav');
      }
    }
    return paired;
  }

  void _verdict(PositionComponent host, Vector2 direction, double damage) {
    final origin = host.position.clone(), hostId = ownerId(host);
    final owners = <int>{hostId};
    final targets = game.projectileTargets.toList()
      ..sort(
        (a, b) => a.position
            .distanceToSquared(origin)
            .compareTo(b.position.distanceToSquared(origin)),
      );
    final rays = [
      direction.clone()..rotate(-.24),
      direction.clone()..rotate(.24),
    ];
    for (final target in targets) {
      final id = ownerId(target), radius = game.enemyRadius(target) + 16;
      if (owners.contains(id) ||
          game.segmentBlocked(origin, target.position) ||
          !rays.any(
            (d) =>
                BulletComponent.segmentDistanceSquared(
                  target.position,
                  origin,
                  system.clip(origin, origin + d * 220),
                ) <=
                radius * radius,
          )) {
        continue;
      }
      if (game.hitEnemy(
        target,
        damage,
        primary: false,
        direction: direction,
        reaction: WeaponReaction.verdictFork,
      )) {
        owners.add(id);
        if (game.claimWeaponImpact()) {
          game.addCombatEffect(
            WeaponImpact(
              position: target.position.clone(),
              weapon: WeaponType.twinVerdict,
              direction: direction,
            ),
          );
        }
      }
      if (owners.length >= 3) break;
    }
    system.audio.play('verdict_twinVerdict.wav');
    game.reserveWeaponPatch();
    game.addCombatEffect(VerdictBurst(position: origin, direction: direction));
  }

  void miss(int shot) {
    final left = (_pendingShots[shot] ?? 1) - 1;
    if (left > 0) {
      _pendingShots[shot] = left;
      return;
    }
    _pendingShots.remove(shot);
    if (!_acceptedShots.containsKey(shot) && shot > _primeShot) breakPair();
  }

  void resetForReload() {
    _minimumPairShot = system.nextAttack;
    breakPair();
  }

  void breakPair() {
    _primeOwner = null;
    _fatalBrand = false;
    _primeUntil = 0;
  }

  void clear() {
    anchors.clear();
    lanes.clear();
    echoes.clear();
    breakPair();
    _minimumPairShot = 0;
    _acceptedShots.clear();
    _pendingShots.clear();
  }

  bool _canRelease(Vector2 direction) =>
      system.ready &&
      !direction.isZero() &&
      !game.segmentBlocked(game.myPlayer.position, system.muzzle(direction));

  bool fireFlak() {
    final direction = system.aim;
    if (!_canRelease(direction) ||
        system.flightCount >= 4 ||
        game.projectileCount + 4 > RegunGame.maxProjectiles) {
      return false;
    }
    final amount = system._releaseDamage();
    system.flights.add(
      ArsenalFlight(
        system.nextAttack,
        ArsenalFlightKind.flak,
        system.muzzle(direction),
        direction.clone(),
        amount,
        math.min(1600, system.state.bulletSpeed),
        system.effectiveRange,
      )..patchDamage = amount * (.45 / 2.4),
    );
    system._released();
    return true;
  }

  void advanceFlak(ArsenalFlight f, double dt) {
    if (f.spent) return;
    f.age += dt;
    final before = f.position.clone();
    final step = math.min(f.speed * dt, math.max(0.0, f.range - f.travelled));
    final proposed = before + f.direction * step;
    var end = system.clip(before, proposed);
    PositionComponent? direct;
    var distance = before.distanceTo(end);
    for (final target in game.projectileTargets) {
      final radius = game.enemyRadius(target) + 8;
      if (BulletComponent.segmentDistanceSquared(target.position, before, end) >
              radius * radius ||
          game.segmentBlocked(before, target.position)) {
        continue;
      }
      final at = BulletComponent.contactDistance(
        target.position,
        before,
        end,
        radius,
      );
      if (at <= distance) {
        distance = at;
        direct = target;
      }
    }
    if (direct != null) end = before + f.direction * distance;
    f.position.setFrom(end);
    f.travelled += before.distanceTo(end);
    final terminal =
        direct != null ||
        end.distanceToSquared(proposed) > 1e-8 ||
        f.range - f.travelled <= .5 ||
        before.distanceToSquared(end) < .0001 ||
        f.age >= math.min(3.0, f.range / math.max(1.0, f.speed) + .12);
    if (!terminal) return;
    // Release all four reservations before adding the complete secondary fan.
    f.spent = true;
    for (final turn in [-.42, -.14, .14, .42]) {
      final d = f.direction.clone()..rotate(turn);
      game.addProjectile(
        BulletComponent(
          position: end.clone(),
          direction: d,
          angle: math.atan2(d.y, d.x),
          damage: f.patchDamage,
          speed: 750,
          maxTravelDistance: 140,
          weapon: WeaponType.flakRegent,
          primary: false,
          reaction: WeaponReaction.flakFragment,
          ignoreTarget: direct == null ? null : game.projectileOwner(direct),
          initialDelay: system._frameOffset,
        ),
      );
    }
    // Admission of secondary procs cannot steal the reserved fragment slots.
    if (direct != null) {
      system._direct(
        direct,
        f.damage,
        f.direction,
        attackId: f.id,
        travel: f.travelled,
      );
    }
    if (direct == null) system.audio.play('impact_flakRegent.wav');
    game.reserveWeaponPatch();
    game.addCombatEffect(FlakBurst(position: end.clone()));
  }

  void plantAnchor(ArsenalFlight f) {
    game.reserveWeaponPatch();
    system.audio.play('plant_anchorEngine.wav');
    anchors.add(
      CommittedArea(
        f.id,
        f.position.clone(),
        f.direction.clone(),
        190,
        f.damage,
      ),
    );
  }

  bool fireLane(Vector2 direction) {
    if (!_canRelease(direction) || lanes.length >= 2) return false;
    final origin = system.muzzle(direction);
    final end = system.clip(origin, origin + direction * system.effectiveRange);
    if (origin.distanceTo(end) < 1) return false;
    game.reserveWeaponPatch();
    final lane = CommittedArea(
      system.nextAttack,
      origin,
      direction.clone(),
      origin.distanceTo(end),
      system._releaseDamage(),
    );
    lanes.add(lane);
    system._released();
    _laneStep(lane);
    return true;
  }

  bool _insideCone(CommittedArea cone, PositionComponent target) {
    final delta = target.position - cone.position,
        radius = game.enemyRadius(target);
    if (delta.length > cone.range + radius ||
        game.segmentBlocked(cone.position, target.position)) {
      return false;
    }
    if (delta.isZero()) return true;
    final angle = math.acos(
      (delta.normalized().dot(cone.direction)).clamp(-1.0, 1.0),
    );
    return angle <=
        35 * math.pi / 180 +
            math.asin(
              (radius / math.max(radius, delta.length)).clamp(0.0, 1.0),
            );
  }

  bool fireBell() {
    final direction = system.aim;
    if (!_canRelease(direction) || echoes.length >= 2) return false;
    final cone = CommittedArea(
      system.nextAttack,
      system.muzzle(direction),
      direction.clone(),
      system.effectiveRange,
      system._releaseDamage(),
    );
    final targets =
        game.projectileTargets.where((e) => _insideCone(cone, e)).toList()
          ..sort(
            (a, b) => a.position
                .distanceToSquared(cone.position)
                .compareTo(b.position.distanceToSquared(cone.position)),
          );
    for (final target in targets) {
      final id = ownerId(target);
      if (cone.owners.containsKey(id)) continue;
      if (system._direct(
        target,
        cone.damage,
        direction,
        attackId: cone.id,
        travel: math.max(
          0,
          cone.position.distanceTo(target.position) - game.enemyRadius(target),
        ),
      )) {
        cone.owners[id] = 0;
      }
      if (cone.owners.length >= 5) break;
    }
    game.reserveWeaponPatch();
    echoes.add(cone);
    system._released();
    return true;
  }

  void _laneStep(CommittedArea lane) {
    while (lane.next < 3 && lane.age >= lane.next * .1 - 1e-8) {
      final section = lane.next++;
      system.audio.play('section_faultlineDriver.wav');
      final from = lane.position + lane.direction * (lane.range * section / 3);
      final to =
          lane.position + lane.direction * (lane.range * (section + 1) / 3);
      final targets = game.projectileTargets.toList()
        ..sort(
          (a, b) => a.position
              .distanceToSquared(from)
              .compareTo(b.position.distanceToSquared(from)),
        );
      for (final target in targets) {
        final id = ownerId(target), radius = game.enemyRadius(target) + 42;
        if (lane.owners.containsKey(id) ||
            lane.owners.length >= 6 ||
            BulletComponent.segmentDistanceSquared(target.position, from, to) >
                radius * radius ||
            game.segmentBlocked(lane.position, target.position)) {
          continue;
        }
        if (system._direct(
          target,
          lane.damage,
          lane.direction,
          attackId: lane.id,
          travel: math.max(
            0,
            lane.position.distanceTo(target.position) -
                game.enemyRadius(target),
          ),
        )) {
          lane.owners[id] = 0;
        }
      }
    }
  }

  void advance(double dt) {
    _acceptedShots.removeWhere((id, at) => system.clock - at > 4);
    if (system.clock >= _primeUntil) breakPair();
    final pulls = <CombatEnemy, ({CommittedArea area, double amount})>{};
    for (final a in anchors) {
      a.age += dt;
      if (!a.resolved && a.age >= .4 && a.age < 1.05) {
        final targets = game.liveEnemies.whereType<CombatEnemy>().toList()
          ..sort(
            (x, y) => x.position
                .distanceToSquared(a.position)
                .compareTo(y.position.distanceToSquared(a.position)),
          );
        for (final target in targets) {
          if (target.isBoss ||
              target.impactResponse <= 0 ||
              target.combatHealth.isDead ||
              target.position.distanceTo(a.position) > 190 ||
              game.segmentBlocked(a.position, target.position)) {
            continue;
          }
          final id = target.combatId;
          if (!a.owners.containsKey(id) && a.owners.length >= 8) continue;
          final amount = math.min(
            55.0 - (a.owners[id] ?? 0.0),
            90 * dt * target.impactResponse,
          );
          if (amount <= 0) continue;
          final previous = pulls[target];
          if (previous == null || amount > previous.amount) {
            pulls[target] = (area: a, amount: amount);
          }
        }
      }
      if (!a.resolved && a.age >= 1.05 - 1e-8) {
        a.resolved = true;
        game.explode(
          a.position,
          radius: system.balance.anchorRadius,
          damage: a.damage,
          releaseId: system._releaseContexts[a.id]?.$1 ?? 0,
          releaseBonus: system._releaseContexts[a.id]?.$2 ?? 0,
          reaction: WeaponReaction.of(WeaponType.anchorEngine),
        );
        system.audio.play('crush_anchorEngine.wav');
      }
    }
    for (final e in pulls.entries) {
      final body = e.key, pull = e.value;
      final delta = pull.area.position - body.position;
      if (delta.isZero()) continue;
      final before = body.position.clone();
      game.moveTo(
        body,
        before + delta.normalized() * math.min(delta.length, pull.amount),
        game.crowdRadius(body),
      );
      pull.area.owners[body.combatId] =
          (pull.area.owners[body.combatId] ?? 0) +
          before.distanceTo(body.position);
    }
    anchors.removeWhere((a) => a.age >= 1.6);
    for (final lane in lanes) {
      lane.age += dt;
      _laneStep(lane);
    }
    lanes.removeWhere((lane) => lane.age >= .75);
    for (final echo in echoes) {
      echo.age += dt;
      if (echo.resolved || echo.age < .55 - 1e-8) continue;
      echo.resolved = true;
      final seen = <int>{};
      // A lethal echo unregisters its victim (including the last boss). Keep
      // this committed release stable while the live target collection changes.
      for (final target in game.projectileTargets.toList()) {
        final id = ownerId(target);
        if (!echo.owners.containsKey(id) ||
            !seen.add(id) ||
            !_insideCone(echo, target)) {
          continue;
        }
        if (system._direct(
              target,
              echo.damage / 3,
              echo.direction,
              primary: false,
              reaction: WeaponReaction.bellEcho,
            ) &&
            game.claimWeaponImpact()) {
          game.addCombatEffect(
            WeaponImpact(
              position: target.position.clone(),
              weapon: WeaponType.mourningBell,
              direction: echo.direction,
            ),
          );
        }
      }
      system.audio.play('echo_mourningBell.wav');
    }
    echoes.removeWhere((e) => e.age >= .9);
  }

  Map<String, dynamic> checkpoint() => {
    'schema': 1,
    'anchors': [for (final a in anchors) a.toJson()],
    'lanes': [for (final a in lanes) a.toJson()],
    'echoes': [for (final a in echoes) a.toJson()],
  };
  static void validate(dynamic map, WeaponType weapon) {
    if (map == null) return;
    if (map is! Map || map['schema'] != 1) {
      throw const FormatException('Invalid committed attacks');
    }
    for (final name in ['anchors', 'lanes', 'echoes']) {
      final list = map[name];
      final allowed =
          weapon ==
          switch (name) {
            'anchors' => WeaponType.anchorEngine,
            'lanes' => WeaponType.faultlineDriver,
            _ => WeaponType.mourningBell,
          };
      if (list is! List || list.length > 2 || !allowed && list.isNotEmpty) {
        throw const FormatException('Attack population');
      }
      for (final a in list) {
        if (a is! Map ||
            a['id'] is! int ||
            a['id'] < 1 ||
            a['id'] > 1e9 ||
            a['resolved'] is! bool ||
            a['next'] is! int ||
            a['next'] < 0 ||
            a['next'] > 3) {
          throw const FormatException('Attack phase');
        }
        for (final k in ['position', 'direction']) {
          final p = a[k];
          if (p is! List ||
              p.length != 2 ||
              p.any((v) => v is! num || !v.isFinite || v.abs() > 10000)) {
            throw const FormatException('Attack coordinate');
          }
        }
        final d = a['direction'] as List;
        final length2 =
            (d[0] as num) * (d[0] as num) + (d[1] as num) * (d[1] as num);
        if ((length2 - 1).abs() > .001) {
          throw const FormatException('Attack heading');
        }
        for (final k in ['range', 'damage', 'age']) {
          final v = a[k];
          if (v is! num ||
              !v.isFinite ||
              v < 0 ||
              v >
                  (k == 'age'
                      ? 3
                      : k == 'range'
                      ? 1600
                      : 2000)) {
            throw const FormatException('Attack amount');
          }
        }
        final age = (a['age'] as num).toDouble();
        if (name == 'anchors' &&
                (age >= 1.6 || a['resolved'] != (age >= 1.05 - 1e-8)) ||
            name == 'echoes' &&
                (age >= .9 || a['resolved'] != (age >= .55 - 1e-8)) ||
            name == 'lanes' &&
                (age >= .75 ||
                    a['next'] != math.min(3, (age / .1 + 1e-7).floor() + 1))) {
          throw const FormatException('Inconsistent committed phase');
        }
        final owners = a['owners'];
        final cap = name == 'anchors'
            ? 8
            : name == 'lanes'
            ? 6
            : 5;
        if (owners is! List || owners.length > cap) {
          throw const FormatException('Attack ledger');
        }
        final ids = <int>{};
        for (final row in owners) {
          if (row is! List ||
              row.length != 2 ||
              row[0] is! int ||
              row[0] < 1 ||
              row[0] > 1e9 ||
              !ids.add(row[0]) ||
              row[1] is! num ||
              !row[1].isFinite ||
              row[1] < 0 ||
              row[1] > 55.001) {
            throw const FormatException('Attack owner');
          }
        }
      }
    }
  }

  void restore(dynamic map) {
    clear();
    if (map == null) return;
    Vector2 point(List p) =>
        Vector2((p[0] as num).toDouble(), (p[1] as num).toDouble());
    for (final e in {
      'anchors': anchors,
      'lanes': lanes,
      'echoes': echoes,
    }.entries) {
      for (final raw in map[e.key]) {
        final a =
            CommittedArea(
                raw['id'],
                point(raw['position']),
                point(raw['direction']),
                (raw['range'] as num).toDouble(),
                (raw['damage'] as num).toDouble(),
              )
              ..age = (raw['age'] as num).toDouble()
              ..next = raw['next']
              ..resolved = raw['resolved'];
        for (final row in raw['owners']) {
          a.owners[row[0]] = (row[1] as num).toDouble();
        }
        e.value.add(a);
      }
    }
  }

  void render(
    Canvas canvas, {
    required bool floor,
    required Rect view,
    required ColorFilter grade,
  }) {
    if (!floor) {
      if (_primeOwner != null) {
        for (final body in game.liveEnemies) {
          if (ownerId(body) != _primeOwner ||
              !view.contains(body.position.toOffset())) {
            continue;
          }
          for (final side in [-1, 1]) {
            canvas.save();
            canvas.translate(body.position.x + side * 13, body.position.y - 23);
            canvas.rotate(side * .16);
            RegunArt.shared
                .rawSprite('weapons/twin_verdict', 1)
                .render(
                  canvas,
                  size: Vector2(9, 5),
                  anchor: Anchor.center,
                  overridePaint: Paint()..colorFilter = grade,
                );
            canvas.restore();
          }
        }
      }
      for (final echo in echoes) {
        if (!view.inflate(echo.range).contains(echo.position.toOffset())) {
          continue;
        }
        bool clear(Offset a, Offset b) =>
            game.geometry.bounds.floor.contains(b) &&
            !game.segmentBlocked(Vector2(a.dx, a.dy), Vector2(b.dx, b.dy));
        EndgameVfx.pressure(
          canvas,
          echo.position.toOffset(),
          echo.direction.toOffset(),
          echo.range,
          (echo.age / .60).clamp(0.0, 1.0),
          grade,
          game.preferences.reducedMotion,
          clear,
        );
        if (echo.resolved) {
          EndgameVfx.pressure(
            canvas,
            echo.position.toOffset(),
            echo.direction.toOffset(),
            echo.range,
            ((echo.age - .55) / .35).clamp(0.0, 1.0),
            grade,
            game.preferences.reducedMotion,
            clear,
            echo: true,
          );
        }
      }
      return;
    }
    final art = RegunArt.shared;
    for (final a in anchors) {
      if (!view.contains(a.position.toOffset())) continue;
      AttackVfx.floorArea(
        canvas,
        1,
        a.position.toOffset(),
        140,
        alpha: a.resolved ? .3 : .65,
        ambient: grade,
      );
      if (art.contains('weapons/anchor_engine')) {
        final clamp = ((a.age - .75) / .3).clamp(0.0, 1.0);
        final separation = game.preferences.reducedMotion
            ? 0.0
            : 3 * (1 - clamp);
        final sprite = art.rawSprite('weapons/anchor_engine', 2);
        for (final side in [-1, 1]) {
          canvas.save();
          canvas.translate(a.position.x, a.position.y + side * separation);
          canvas.clipRect(
            side < 0
                ? const Rect.fromLTRB(-20, -12, 20, 0)
                : const Rect.fromLTRB(-20, 0, 20, 12),
          );
          sprite.render(
            canvas,
            size: Vector2(34, 19.14),
            anchor: Anchor.center,
            overridePaint: Paint()..colorFilter = grade,
          );
          canvas.restore();
        }
      }
      if (!a.resolved && a.age > .4) {
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4,
              r = game.preferences.reducedMotion
                  ? 95.0
                  : 130 - ((a.age - .4) * 110 + i * 9) % 100;
          AttackVfx.floorArea(
            canvas,
            1,
            a.position.toOffset() +
                Offset(math.cos(angle) * r, math.sin(angle) * r),
            18,
            alpha: .45,
            ambient: grade,
          );
        }
      }
    }
    for (final lane in lanes) {
      for (var section = 0; section < lane.next; section++) {
        final from =
            lane.position + lane.direction * (lane.range * section / 3);
        final to =
            lane.position + lane.direction * (lane.range * (section + 1) / 3);
        if (!view.inflate(lane.range / 3).contains(from.toOffset())) continue;
        EndgameVfx.fracture(
          canvas,
          from.toOffset(),
          to.toOffset(),
          ((lane.age - section * .1) / .55).clamp(0.0, 1.0),
          grade,
          game.preferences.reducedMotion,
        );
      }
    }
  }
}
