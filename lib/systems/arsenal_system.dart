import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/systems/sniper_sway.dart';
import 'package:regun/systems/flame_flow.dart';
import 'package:regun/presentation/grenade_art.dart';
import 'package:regun/systems/grenades.dart';

import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/utils/soloud_play.dart';

import 'package:flame/components.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/components/weapons/weapon_impact.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/weapon_art_spec.dart';

part 'endgame_arsenal.dart';

enum ArsenalFlightKind { disc, mortar, spore, flak, anchor }

class ArsenalFlight {
  ArsenalFlight(
    this.id,
    this.kind,
    this.position,
    this.direction,
    this.damage,
    this.speed,
    this.range, {
    Vector2? destination,
  }) : destination = destination ?? position.clone();
  final int id;
  final ArsenalFlightKind kind;
  Vector2 position, direction, destination;
  final double damage, speed, range;
  double patchDamage = 0;
  double travelled = 0, age = 0, duration = .7;
  bool returning = false, spent = false, impactPending = false;
  final outHits = <int>{}, returnHits = <int>{};
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'position': [position.x, position.y],
    'direction': [direction.x, direction.y],
    'destination': [destination.x, destination.y],
    'damage': damage,
    'patchDamage': patchDamage,
    'speed': speed,
    'range': range,
    'travelled': travelled,
    'age': age,
    'duration': duration,
    'returning': returning,
    'impactPending': impactPending,
    'outHits': outHits.toList(),
    'returnHits': returnHits.toList(),
  };
}

class RivetPayload {
  RivetPayload(this.id, this.host, this.position, this.damage);
  final int id, host;
  final Vector2 position;
  final double damage;
  double remaining = 3;
  Map<String, dynamic> toJson() => {
    'id': id,
    'host': host,
    'position': [position.x, position.y],
    'damage': damage,
    'remaining': remaining,
  };
}

class SporePatch {
  SporePatch(this.id, this.position, this.damage);
  final int id;
  final Vector2 position;
  final double damage;
  double remaining = 2.5;
  Map<String, dynamic> toJson() => {
    'id': id,
    'position': [position.x, position.y],
    'damage': damage,
    'remaining': remaining,
  };
}

/// One run-owned controller. Rendering cannot spend ammunition or cause a hit.
/// Fixed substeps resolve charge/heat/melee/flight events, including long frames.
class ArsenalSystem {
  ArsenalSystem(this.game) : audio = game.audio;
  late final endgame = EndgameArsenal(this);
  final SoloudPlay audio;
  final RegunGame game;
  final flights = <ArsenalFlight>[],
      rivets = <RivetPayload>[],
      patches = <SporePatch>[];
  final _procAt = <int, double>{};
  final flame = FlameFlow();
  final sniperSway = SniperSway();
  double cooldown = 0, charge = 0, spool = 0, clock = 0;
  double sustainedFire = 0;
  final muzzleJitter = Vector2.zero();
  double get beltCadence =>
      .085 + (.040 - .085) * (sustainedFire / 8).clamp(0.0, 1.0);
  double _idle = 0, _cooling = 0, _patchTick = 0;
  int nextAttack = 1;
  bool _wasReloading = false, _loopOn = false;
  bool aiming = false;
  final _lastAim = Vector2.zero();
  double _beamAge = 0, _frameOffset = 0, _blocked = 0;
  Vector2? beamFrom, beamTo;
  WeaponType get weapon => game.loadout.weapon;
  GameState get state => game.gameState;
  String get loopOwner => 'arsenal:${identityHashCode(this)}';
  int get flightCount => flights.where((f) => !f.spent).length;
  int get projectileReservations => flights
      .where((f) => !f.spent)
      .fold(0, (sum, f) => sum + (f.kind == ArsenalFlightKind.flak ? 4 : 1));
  int get effectCount =>
      endgame.effectCount +
      rivets.length +
      patches.length +
      (_loopOn || flame.tongues.isNotEmpty ? 1 : 0);
  bool get hasRivets => rivets.isNotEmpty;
  double get visualCharge => weapon == WeaponType.beltRepeater
      ? spool / .4
      : weapon == WeaponType.railLance
      ? charge / .45
      : weapon == WeaponType.prismCutter
      ? (state.maxBullets - state.noOfBullets) / state.maxBullets
      : 0;
  double get _trigger =>
      math.pow(.85, state.effectRank(PowerUp.quickTrigger)).toDouble();
  double get _damageScale => state.shotDamage * game.loadout.character.damage;
  double get _baseDamage => weapon.damage * _damageScale;
  bool get ready =>
      _blocked <= 1e-8 &&
      !state.reloading &&
      state.noOfBullets > 0 &&
      state.gameplayState == GameplayState.playing &&
      !game.playerEntrance.active;
  bool get _effectRoom => (game.runtimeCounts['effects'] ?? 0) < 40;

  void _loop(bool wanted) {
    if (wanted == _loopOn) return;
    _loopOn = wanted;
    if (wanted) {
      audio.startWeaponLoop(loopOwner, 'sustain_${weapon.name}.wav');
    } else {
      audio.stopWeaponLoop(loopOwner);
    }
  }

  void cancelIntent() {
    charge = 0;
    spool = 0;
    sustainedFire = 0;
    cancelAim();
    _loop(false);
    beamFrom = beamTo = null;
  }

  void dispose() {
    cancelIntent();
    flights.clear();
    rivets.clear();
    patches.clear();
    flame.clear();
    sniperSway.reset();
    endgame.clear();
  }

  void cancelAim() {
    aiming = false;
    _lastAim.setZero();
    sniperSway.release();
  }

  bool releaseAim(Vector2 released) {
    final releaseDirection = aimedDirection(released);
    cancelAim();
    if (!weapon.firesOnRelease ||
        !ready ||
        cooldown > 1e-8 ||
        released.isZero()) {
      return false;
    }
    final fired = weapon == WeaponType.longwatchSniper
        ? _rounds(directionOverride: releaseDirection)
        : weapon == WeaponType.faultlineDriver
        ? endgame.fireLane(releaseDirection)
        : _launch(released: released);
    if (fired) {
      cooldown = math.max(
        weapon == WeaponType.longwatchSniper ? .65 : .4,
        weapon.cadence * _trigger,
      );
    }
    return fired;
  }

  Vector2 get rawAim => weapon.firesOnRelease
      ? game.weaponJoystick.strengthDelta
      : game.weaponJoystick.relativeDelta;
  Vector2 aimedDirection(Vector2 raw) {
    final direction = game.assistedWeaponDirection(raw, range: effectiveRange);
    if (weapon == WeaponType.longwatchSniper && !direction.isZero()) {
      direction.rotate(sniperSway.angle);
    }
    return direction;
  }

  Vector2 get aim => aimedDirection(rawAim);
  Vector2 muzzle(Vector2 direction) {
    final p = WeaponArtSpec.of(weapon).releaseOffset(direction.toOffset());
    return game.myPlayer.position + Vector2(p.dx, p.dy);
  }

  double get effectiveRange => switch (weapon) {
    WeaponType.cinderHose => math.min(320, state.bulletRange.toDouble()),
    WeaponType.reaperDisc => math.min(650, state.bulletRange.toDouble()),
    WeaponType.scrapMortar => math.min(760, state.bulletRange.toDouble()),
    WeaponType.frostShotgun => math.min(480, state.bulletRange.toDouble()),
    WeaponType.prismCutter => math.min(560, state.bulletRange.toDouble()),
    WeaponType.sporeLobber => math.min(600, state.bulletRange.toDouble()),
    WeaponType.anchorEngine => math.min(760, state.bulletRange.toDouble()),
    _ => state.bulletRange.toDouble(),
  };
  int get pelletCount => !weapon.supportsScatter
      ? 1
      : weapon == WeaponType.cycloneBreacher
      ? 5 + math.min(2, state.rank(PowerUp.numberOfBulletsPerShotIncrease)) * 2
      : weapon == WeaponType.frostShotgun
      ? 3 + math.min(3, state.rank(PowerUp.numberOfBulletsPerShotIncrease)) * 2
      : weapon == WeaponType.railLance || weapon == WeaponType.beltRepeater
      ? math.min(3, 1 + state.rank(PowerUp.numberOfBulletsPerShotIncrease))
      : 1 + math.min(3, state.rank(PowerUp.numberOfBulletsPerShotIncrease));

  double _releaseDamage() {
    var amount = _baseDamage;
    if (weapon.hasLastRound && state.noOfBullets == 1) {
      amount *=
          1 +
          state.effectRank(PowerUp.lastShell) *
              (state.fused('breachEngine') ? .9 : .6);
    }
    if (weapon.hasLastRound && game.consumeBreachCharge()) {
      amount *=
          1 +
          state.effectRank(PowerUp.breachLoader) *
              (state.fused('breachEngine') ? .8 : .5);
    }
    return amount;
  }

  void _released({bool tick = false, bool cue = true}) {
    if (cue) {
      audio.play('shot_${weapon.name}_${game.shotsFired % 3}.wav');
    }
    game.shotsFired++;
    game.myPlayer.recoil = tick ? .35 : 1;
    game.gameNotifier.decreaseBullets();
    nextAttack++;
    _idle = 0;
    if (state.noOfBullets == 0) {
      game.gameNotifier.reloadBullets();
    }
  }

  void advance(double dt, {double blockedFor = 0}) {
    if (state.gameplayState != GameplayState.playing ||
        game.playerEntrance.active) {
      return;
    }
    if (!dt.isFinite || dt <= 0) return;
    // Stalled frames advance finite transients; never replay offline minutes.
    var left = math.min(dt, 2.0);
    _frameOffset = 0;
    _blocked = blockedFor;
    while (left > 1e-8) {
      final step = math.min(left, 1 / 120);
      _step(step);
      _frameOffset += step;
      _blocked = math.max(0, _blocked - step);
      left -= step;
    }
    _procAt.removeWhere((id, at) => clock - at > 1);
  }

  void _step(double dt) {
    clock += dt;
    cooldown = math.max(0, cooldown - dt);
    _beamAge += dt;
    _idle += dt;
    if (state.reloading && !_wasReloading) {
      charge = spool = sustainedFire = 0;
      cancelAim();
      endgame.resetForReload();
      if (weapon == WeaponType.rivetDriver) {
        for (final r in rivets) {
          r.remaining = math.min(r.remaining, .12);
        }
      }
    }
    _wasReloading = state.reloading;
    _advanceTransients(dt);
    endgame.advance(dt);
    if (weapon == WeaponType.cinderHose) {
      final direction = rawAim.isZero() ? game.myPlayer.aimDirection : aim;
      flame.advance(
        dt,
        active: !rawAim.isZero() && ready,
        nozzle: muzzle(direction),
        direction: direction,
        range: effectiveRange,
        clip: clip,
        reducedMotion: game.preferences.reducedMotion,
      );
    }
    final held = !rawAim.isZero();
    if (weapon == WeaponType.longwatchSniper) {
      sniperSway.advance(dt, aiming: held && ready && cooldown <= 1e-8);
    }
    if (weapon.firesOnRelease) {
      if (held && ready && cooldown <= 1e-8) {
        aiming = true;
        _lastAim.setFrom(rawAim);
      } else if (!held && aiming) {
        final released = _lastAim.clone();
        if (game.weaponJoystick.hasActivePointer) {
          cancelAim();
        } else {
          releaseAim(released);
        }
      } else if (!ready) {
        cancelAim();
      }
      _loop(false);
      return;
    }
    if (!held || !ready) {
      charge = 0;
      sustainedFire = 0;
      spool = math.max(0, spool - dt * 1.6);
      _loop(false);
      if (weapon == WeaponType.prismCutter && !state.reloading && _idle > .4) {
        _cooling += dt * 2;
        if (_cooling >= 1) {
          game.gameNotifier.restorePrimaryUnits(_cooling.floor());
          _cooling %= 1;
        }
      }
      return;
    }
    if (weapon == WeaponType.railLance) {
      if (cooldown > 0) return;
      charge = math.min(.45, charge + dt);
      if (charge >= .45 - 1e-8 && _rounds()) {
        charge = 0;
        cooldown = math.max(.35, .65 * _trigger);
      }
    } else if (weapon == WeaponType.beltRepeater) {
      if (spool == 0) audio.play('spin_beltRepeater.wav');
      spool = math.min(.4, spool + dt);
      if (spool >= .4) sustainedFire += dt;
      if (spool >= .4 && cooldown <= 1e-8 && _rounds()) {
        _loop(true);
        cooldown = math.max(.030, beltCadence * _trigger);
      }
    } else if (weapon.isContinuous) {
      if (cooldown <= 1e-8) _continuous();
    } else if (cooldown <= 1e-8) {
      final fired =
          weapon == WeaponType.reaperDisc ||
              weapon == WeaponType.scrapMortar ||
              weapon == WeaponType.sporeLobber
          ? _launch()
          : weapon == WeaponType.flakRegent
          ? endgame.fireFlak()
          : weapon == WeaponType.mourningBell
          ? endgame.fireBell()
          : _rounds();
      if (fired) {
        cooldown = math.max(switch (weapon) {
          WeaponType.frostShotgun => .45,
          WeaponType.reaperDisc => .35,
          WeaponType.scrapMortar => .55,
          WeaponType.sporeLobber => .40,
          _ => .14,
        }, weapon.cadence * _trigger);
      }
    }
  }

  bool _rounds({Vector2? directionOverride}) {
    final direction = directionOverride ?? aim;
    if (!ready ||
        direction.isZero() ||
        game.projectileCount + pelletCount > RegunGame.maxProjectiles) {
      return false;
    }
    muzzleJitter.setZero();
    if (weapon == WeaponType.beltRepeater) {
      muzzleJitter.setValues(
        (game.random.nextDouble() * 2 - 1) * 2,
        (game.random.nextDouble() * 2 - 1) * 4,
      );
    }
    if (weapon == WeaponType.twinVerdict) {
      muzzleJitter.y = nextAttack.isOdd ? -2.2 : 2.2;
    }
    final offset =
        direction * muzzleJitter.x +
        Vector2(-direction.y, direction.x) * muzzleJitter.y;
    final origin = muzzle(direction) + offset;
    if (game.segmentBlocked(game.myPlayer.position, origin)) return false;
    final amount = _releaseDamage();
    if (weapon == WeaponType.twinVerdict) {
      endgame.beginShot(nextAttack, pelletCount);
    }
    final spread =
        ({WeaponType.frostShotgun, WeaponType.cycloneBreacher}.contains(weapon)
            ? math.pi / 20
            : math.pi / 32) *
        (1 -
            math.max(
                  0,
                  state.rank(PowerUp.numberOfBulletsPerShotIncrease) -
                      ((weapon == WeaponType.railLance ||
                              weapon == WeaponType.beltRepeater)
                          ? 2
                          : 3),
                ) *
                .04);
    for (var i = 0; i < pelletCount; i++) {
      final d = direction.clone()..rotate((i - (pelletCount - 1) / 2) * spread);
      if (weapon == WeaponType.beltRepeater) {
        d.rotate((game.random.nextDouble() * 2 - 1) * math.pi / 90);
      }
      game.addProjectile(
        BulletComponent(
          position: origin.clone(),
          direction: d,
          initialDelay: _frameOffset,
          weapon: weapon,
          shotSequence: nextAttack,
          damage:
              amount /
              (!{
                        WeaponType.frostShotgun,
                        WeaponType.cycloneBreacher,
                      }.contains(weapon) &&
                      pelletCount > 1
                  ? 1.3
                  : 1),
          angle: math.atan2(d.y, d.x),
          speed: math.min(2000, state.bulletSpeed),
          maxTravelDistance: effectiveRange,
          pierce: math.min(
            weapon == WeaponType.railLance
                ? 5
                : weapon == WeaponType.frostShotgun
                ? 2
                : 8,
            (weapon == WeaponType.railLance
                    ? 2
                    : weapon == WeaponType.longwatchSniper
                    ? 3
                    : 0) +
                state.rank(PowerUp.bulletsPhaseThrough),
          ),
          bounces: weapon.supportsRicochet
              ? state.rank(PowerUp.ricochet) + (state.fused('pinball') ? 3 : 0)
              : 0,
        ),
      );
    }
    _released();
    return true;
  }

  Vector2 clip(Vector2 from, Vector2 to) {
    final end = to.clone();
    game.geometry.constrain(end, 1);
    if (!game.segmentBlocked(from, end)) return end;
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 14; i++) {
      final mid = (lo + hi) / 2;
      if (game.segmentBlocked(from, from + (end - from) * mid)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return from + (end - from) * lo;
  }

  Vector2 mortarTarget(Vector2 direction, {Vector2? released}) {
    final input = released ?? rawAim;
    final strength =
        ((input.length - game.controls.deadZone) / (1 - game.controls.deadZone))
            .clamp(0.0, 1.0);
    final minimum = math.max(
      55.0,
      WeaponArtSpec.of(weapon).releaseOffset(direction.toOffset()).distance +
          12,
    );
    return clip(
      muzzle(direction),
      game.myPlayer.position +
          direction * (minimum + (effectiveRange - minimum) * strength),
    );
  }

  Vector2 previewLanding(Vector2 direction) {
    final origin = muzzle(direction), end = mortarTarget(direction);
    if (weapon != WeaponType.sporeLobber) return end;
    var distance = origin.distanceTo(end);
    for (final target in game.projectileTargets) {
      final radius = game.enemyRadius(target) + 9;
      if (BulletComponent.segmentDistanceSquared(
            target.position,
            origin,
            end,
          ) <=
          radius * radius) {
        distance = math.min(
          distance,
          BulletComponent.contactDistance(target.position, origin, end, radius),
        );
      }
    }
    return origin + (end - origin).normalized() * distance;
  }

  bool _launch({Vector2? released}) {
    final maxFlights = weapon == WeaponType.reaperDisc ? 3 : 4;
    if (weapon == WeaponType.anchorEngine &&
        flightCount + endgame.anchors.length >= 2) {
      return false;
    }
    if (!ready ||
        flightCount >= maxFlights ||
        game.projectileCount >= RegunGame.maxProjectiles) {
      return false;
    }
    final direction = released == null
        ? aim
        : game.assistedWeaponDirection(released, range: effectiveRange);
    if (direction.isZero()) return false;
    final origin = muzzle(direction);
    if (game.segmentBlocked(game.myPlayer.position, origin)) return false;
    final kind = weapon == WeaponType.reaperDisc
        ? ArsenalFlightKind.disc
        : weapon == WeaponType.anchorEngine
        ? ArsenalFlightKind.anchor
        : weapon == WeaponType.scrapMortar
        ? ArsenalFlightKind.mortar
        : ArsenalFlightKind.spore;
    final target = weapon.firesOnRelease
        ? mortarTarget(direction, released: released)
        : null;
    final flightDirection = target == null
        ? direction.clone()
        : (target - origin).normalized();
    final f = ArsenalFlight(
      nextAttack,
      kind,
      origin,
      flightDirection,
      _releaseDamage(),
      math.min(
        weapon == WeaponType.reaperDisc ? 1200 : 1000,
        state.bulletSpeed,
      ),
      target == null ? effectiveRange : origin.distanceTo(target),
      destination: target,
    );
    f.patchDamage = .8 * _damageScale;
    f.duration = (.55 + .3 * origin.distanceTo(f.destination) / 620).clamp(
      .55,
      1.0,
    );
    flights.add(f);
    _released();
    return true;
  }

  bool _direct(
    PositionComponent target,
    double amount,
    Vector2 direction, {
    bool primary = true,
  }) {
    final owner = game.projectileOwner(target);
    final id = owner is CombatEnemy ? owner.combatId : identityHashCode(owner);
    var proc = primary;
    if (weapon.isContinuous) {
      proc = primary && clock - (_procAt[id] ?? -100) >= .25 - 1e-8;
      if (proc) _procAt[id] = clock;
    }
    final accepted = game.hitEnemy(
      target,
      amount,
      primary: proc,
      direction: direction,
    );
    if (accepted && proc) _contact(target, direction);
    return accepted;
  }

  void _contact(PositionComponent target, Vector2 direction) {
    if (!game.claimWeaponImpact()) return;
    game.addCombatEffect(
      WeaponImpact(
        position: target.position.clone(),
        weapon: weapon,
        direction: direction,
      ),
    );
    if (weapon != WeaponType.sporeLobber) {
      audio.play('impact_${weapon.name}.wav');
    }
  }

  void _continuous() {
    if (!ready || !_effectRoom) return;
    final direction = aim;
    if (direction.isZero()) return;
    final origin = muzzle(direction),
        end = clip(origin, origin + direction * effectiveRange);
    if (game.segmentBlocked(game.myPlayer.position, origin)) return;
    final targets =
        game.liveEnemies
            .where((e) => !game.segmentBlocked(origin, e.position))
            .toList()
          ..sort(
            (a, b) => weapon == WeaponType.prismCutter
                ? BulletComponent.contactDistance(
                    a.position,
                    origin,
                    end,
                    game.crowdRadius(a) + 6,
                  ).compareTo(
                    BulletComponent.contactDistance(
                      b.position,
                      origin,
                      end,
                      game.crowdRadius(b) + 6,
                    ),
                  )
                : a.position
                      .distanceToSquared(origin)
                      .compareTo(b.position.distanceToSquared(origin)),
          );
    final amount = _releaseDamage();
    var hits = 0;
    var visibleEnd = end;
    for (final target in targets) {
      final delta = target.position - origin, radius = game.crowdRadius(target);
      if (weapon == WeaponType.prismCutter) {
        if (BulletComponent.segmentDistanceSquared(
              target.position,
              origin,
              end,
            ) >
            (radius + 6) * (radius + 6)) {
          continue;
        }
        final along = BulletComponent.contactDistance(
          target.position,
          origin,
          end,
          radius + 6,
        );
        visibleEnd = origin + direction * along;
        _direct(target, amount, direction);
        hits++;
        break;
      }
      if (delta.length > flame.front(effectiveRange) + radius) continue;
      final angle =
          math.atan2(delta.y, delta.x) - math.atan2(direction.y, direction.x);
      final wrapped = math.atan2(math.sin(angle), math.cos(angle)).abs();
      if (wrapped >
          math.pi / 9 +
              math.asin(
                (radius / math.max(radius, delta.length)).clamp(0.0, 1.0),
              )) {
        continue;
      }
      _direct(target, amount, direction);
      if (target is CombatEnemy && !target.combatHealth.isDead) {
        target.igniteCinder();
      }
      hits++;
      if (hits >= 8) {
        visibleEnd =
            origin +
            direction * math.min(effectiveRange, delta.length + radius);
        break;
      }
    }
    beamFrom = origin;
    beamTo = visibleEnd;
    _beamAge = 0;
    final starting = !_loopOn;
    _loop(true);
    _released(tick: true, cue: starting);
    cooldown = weapon == WeaponType.cinderHose
        ? math.max(.075, .10 * _trigger)
        : .10;
  }

  void lodge(PositionComponent target) {
    if (!_effectRoom ||
        target is! CombatEnemy ||
        rivets.length >= 8 ||
        rivets.where((r) => r.host == target.combatId).length >= 2) {
      return;
    }
    rivets.add(
      RivetPayload(
        nextAttack++,
        target.combatId,
        target.position.clone(),
        1.75 * _damageScale,
      ),
    );
  }

  void _advanceTransients(double dt) {
    for (final r in rivets) {
      final host = game.liveEnemies
          .whereType<CombatEnemy>()
          .where((e) => e.combatId == r.host)
          .firstOrNull;
      if (host != null) {
        r.position.setFrom((host as PositionComponent).position);
      } else {
        r.remaining = math.min(r.remaining, .12);
      }
      r.remaining = math.max(0, r.remaining - dt);
    }
    final due = rivets.where((r) => r.remaining <= 0).toList();
    for (final r in due) {
      if (!rivets.contains(r) || !_effectRoom) continue;
      final group = due
          .where(
            (v) =>
                rivets.contains(v) &&
                v.position.distanceToSquared(r.position) < 20 * 20,
          )
          .toList();
      final amount = group.fold<double>(0, (s, v) => s + v.damage);
      for (final item in group) {
        rivets.remove(item);
      }
      game.explode(r.position, radius: 125, damage: amount);
    }
    for (final f in flights.toList()) {
      if (!f.spent) _flightStep(f, dt);
    }
    flights.removeWhere((f) => f.spent);
    for (final p in patches) {
      p.remaining -= dt;
    }
    patches.removeWhere((p) => p.remaining <= 1e-8);
    _patchTick += dt;
    if (_patchTick >= .25 - 1e-8) {
      _patchTick = math.max(0, _patchTick - .25);
      final strongest = <PositionComponent, double>{};
      for (final p in patches) {
        var count = 0;
        final targets = game.liveEnemies.toList()
          ..sort(
            (a, b) => a.position
                .distanceToSquared(p.position)
                .compareTo(b.position.distanceToSquared(p.position)),
          );
        for (final target in targets) {
          final reach = 100 + game.crowdRadius(target);
          if (target.position.distanceToSquared(p.position) > reach * reach ||
              game.segmentBlocked(p.position, target.position)) {
            continue;
          }
          strongest[target] = math.max(strongest[target] ?? 0, p.damage * .25);
          if (++count >= 8) break;
        }
      }
      for (final e in strongest.entries) {
        game.hitEnemy(e.key, e.value, primary: false);
      }
    }
  }

  void _patchAt(ArsenalFlight f) {
    if (patches.length >= 4) patches.removeAt(0);
    game.reserveWeaponPatch();
    // Gameplay patches have their own four-slot budget; visual FX saturation
    // must never discard a paid capsule impact.
    audio.play('impact_sporeLobber.wav');
    patches.add(SporePatch(f.id, f.position.clone(), f.patchDamage));
  }

  void _flightStep(ArsenalFlight f, double dt) {
    if (f.kind == ArsenalFlightKind.flak) {
      endgame.advanceFlak(f, dt);
      return;
    }
    if (f.kind == ArsenalFlightKind.mortar ||
        f.kind == ArsenalFlightKind.anchor) {
      if (!f.impactPending) {
        final left = math.max(0, f.duration - f.age), step = math.min(dt, left);
        f.position.add(
          (f.destination - f.position) * (left <= 1e-8 ? 1 : step / left),
        );
        f.age += step;
        f.impactPending = f.age >= f.duration - 1e-8;
      }
      if (f.impactPending &&
          (f.kind == ArsenalFlightKind.anchor || _effectRoom)) {
        f.spent = true;
        if (f.kind == ArsenalFlightKind.anchor) {
          endgame.plantAnchor(f);
        } else {
          game.explode(f.position, radius: 145, damage: f.damage);
        }
      }
      return;
    }
    f.age += dt;
    if (f.returning && f.age >= 4) {
      f.spent = true;
      return;
    }
    if (f.returning) {
      // Return targets follow the live gun, including when the survivor moves.
      f.destination.setFrom(muzzle(game.myPlayer.aimDirection));
    }
    final before = f.position.clone();
    final remaining = f.returning
        ? f.position.distanceTo(f.destination)
        : math.max(0.0, f.range - f.travelled);
    if (f.returning) {
      final d = f.destination - f.position;
      if (!d.isZero()) f.direction.setFrom(d.normalized());
    }
    final speed = f.returning
        ? math.max(950.0, game.gameState.movementSpeed + 500)
        : f.speed;
    final step = math.min(speed * dt, remaining);
    final proposed = before + f.direction * step,
        after = clip(before, proposed);
    final blocked = after.distanceToSquared(proposed) > 1e-8;
    final targets = game.projectileTargets.toList()
      ..sort(
        (a, b) =>
            BulletComponent.contactDistance(
              a.position,
              before,
              after,
              game.enemyRadius(a) + 9,
            ).compareTo(
              BulletComponent.contactDistance(
                b.position,
                before,
                after,
                game.enemyRadius(b) + 9,
              ),
            ),
      );
    final ledger = f.returning ? f.returnHits : f.outHits;
    final hitLimit = math.min(8, 3 + state.rank(PowerUp.bulletsPhaseThrough));
    for (final target in targets) {
      final owner = game.projectileOwner(target);
      final id = owner is CombatEnemy
          ? owner.combatId
          : identityHashCode(owner);
      if (ledger.contains(id) ||
          ledger.length >= (f.kind == ArsenalFlightKind.disc ? hitLimit : 1)) {
        continue;
      }
      final radius = game.enemyRadius(target) + 9;
      if (BulletComponent.segmentDistanceSquared(
                target.position,
                before,
                after,
              ) >
              radius * radius ||
          game.segmentBlocked(before, target.position)) {
        continue;
      }
      ledger.add(id);
      _direct(target, f.damage, f.direction, primary: !f.returning);
      if (f.kind == ArsenalFlightKind.spore) {
        f.position.setFrom(
          before +
              f.direction *
                  BulletComponent.contactDistance(
                    target.position,
                    before,
                    after,
                    radius,
                  ),
        );
        _patchAt(f);
        f.spent = true;
        return;
      }
    }
    f.position.setFrom(after);
    f.travelled += before.distanceTo(after);
    if (f.kind == ArsenalFlightKind.spore &&
        (blocked ||
            f.travelled >= f.range - 1e-8 ||
            f.age >= math.min(3, f.range / math.max(1, f.speed) + .5) ||
            before.distanceToSquared(after) < 1e-12)) {
      _patchAt(f);
      f.spent = true;
    } else if (f.kind == ArsenalFlightKind.disc) {
      if (f.returning) {
        if (blocked || remaining <= step + 1e-6) f.spent = true;
      } else if (blocked ||
          f.travelled >= f.range - 1e-8 ||
          ledger.length >= hitLimit ||
          f.age >= math.min(2, f.range / math.max(1, f.speed) + .25) ||
          before.distanceToSquared(after) < 1e-12) {
        f.returning = true;
        f.age = 0;
        f.destination.setFrom(muzzle(game.myPlayer.aimDirection));
      }
    }
  }

  Map<String, dynamic> checkpoint() => {
    'schema': 1,
    'weapon': weapon.name,
    'cooldown': cooldown,
    'clock': clock,
    'idle': _idle,
    'cooling': _cooling,
    'patchTick': _patchTick,
    'nextAttack': nextAttack,
    if (weapon == WeaponType.longwatchSniper)
      'sniperSway': sniperSway.checkpoint(),
    'wasReloading': state.reloading,
    'flights': [
      for (final f in flights)
        if (!f.spent) f.toJson(),
    ],
    'rivets': [for (final r in rivets) r.toJson()],
    'patches': [for (final p in patches) p.toJson()],
    'endgame': endgame.checkpoint(),
  };

  static void validate(Map<String, dynamic> map, WeaponType weapon) {
    if (map['weapon'] == 'breachHammer' &&
        weapon == WeaponType.longwatchSniper) {
      map['weapon'] = weapon.name;
    }
    if (map['sniperSway'] != null) {
      if (weapon != WeaponType.longwatchSniper || map['sniperSway'] is! Map) {
        throw const FormatException('Unexpected sniper fatigue');
      }
      SniperSway.validate(map['sniperSway'] as Map);
    }
    EndgameArsenal.validate(map['endgame'], weapon);
    if (map['schema'] != 1 || map['weapon'] != weapon.name) {
      throw const FormatException('Invalid arsenal state');
    }
    double n(dynamic value, double cap) {
      if (value is! num || !value.isFinite || value < 0 || value > cap) {
        throw const FormatException('Invalid arsenal number');
      }
      return value.toDouble();
    }

    void point(dynamic value) {
      if (value is! List ||
          value.length != 2 ||
          value.any((v) => v is! num || !v.isFinite || v.abs() > 10000)) {
        throw const FormatException('Invalid arsenal point');
      }
    }

    for (final k in ['cooldown', 'idle', 'cooling', 'patchTick', 'clock']) {
      n(
        map[k],
        k == 'cooldown'
            ? 10
            : k == 'cooling'
            ? 1
            : k == 'patchTick'
            ? .25
            : 1e9,
      );
    }
    if (map['nextAttack'] is! int ||
        map['nextAttack'] < 1 ||
        map['nextAttack'] > 1e9 ||
        map['wasReloading'] is! bool) {
      throw const FormatException('Invalid arsenal event');
    }
    if (weapon == WeaponType.anchorEngine &&
        map['flights'] is List &&
        ((map['flights'] as List).length +
                ((map['endgame'] as Map?)?['anchors'] as List? ?? const [])
                    .length >
            2)) {
      throw const FormatException('Anchor cap');
    }
    for (final name in ['flights', 'rivets', 'patches']) {
      final list = map[name];
      if (list is! List || list.length > (name == 'rivets' ? 8 : 4)) {
        throw const FormatException('Invalid arsenal population');
      }
      if (name == 'flights' &&
          weapon == WeaponType.reaperDisc &&
          list.length > 3) {
        throw const FormatException('Disc cap');
      }
      for (final raw in list) {
        if (raw is! Map ||
            raw['id'] is! int ||
            raw['id'] < 1 ||
            raw['id'] >= map['nextAttack']) {
          throw const FormatException('Invalid attack id');
        }
        point(raw['position']);
        n(raw['damage'], 2000);
        if (name == 'flights') {
          final expected = weapon == WeaponType.reaperDisc
              ? 'disc'
              : weapon == WeaponType.scrapMortar
              ? 'mortar'
              : weapon == WeaponType.anchorEngine
              ? 'anchor'
              : weapon == WeaponType.flakRegent
              ? 'flak'
              : weapon == WeaponType.sporeLobber
              ? 'spore'
              : '';
          if (raw['kind'] != expected) {
            throw const FormatException('Wrong flight kind');
          }
          point(raw['direction']);
          point(raw['destination']);
          n(raw['patchDamage'] ?? 0, 2000);
          n(raw['speed'], 2000);
          n(raw['range'], 1600);
          n(raw['travelled'], 4000);
          n(raw['age'], 10);
          n(raw['duration'], 1);
          if (raw['returning'] is! bool || raw['impactPending'] is! bool) {
            throw const FormatException('Invalid flight phase');
          }
          for (final key in ['outHits', 'returnHits']) {
            final ids = raw[key];
            if (ids is! List ||
                ids.length > 32 ||
                ids.any((v) => v is! int || v < 1 || v > 1e9)) {
              throw const FormatException('Invalid flight ledger');
            }
          }
        } else {
          n(raw['remaining'], name == 'rivets' ? 3 : 2.5);
          if (name == 'rivets' && (raw['host'] is! int || raw['host'] < 1)) {
            throw const FormatException('Invalid rivet host');
          }
        }
      }
    }
    if (weapon != WeaponType.rivetDriver &&
            (map['rivets'] as List).isNotEmpty ||
        weapon != WeaponType.sporeLobber &&
            (map['patches'] as List).isNotEmpty) {
      throw const FormatException('Wrong persistent effect');
    }
  }

  void restore(Map<String, dynamic> map) {
    validate(map, weapon);
    cancelIntent();
    flights.clear();
    rivets.clear();
    patches.clear();
    double n(String key) => (map[key] as num).toDouble();
    Vector2 point(dynamic raw) =>
        Vector2((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
    cooldown = n('cooldown');
    clock = n('clock');
    _idle = n('idle');
    _cooling = n('cooling');
    _patchTick = n('patchTick');
    nextAttack = map['nextAttack'] as int;
    _wasReloading = map['wasReloading'] as bool;
    endgame.restore(map['endgame']);
    sniperSway.reset();
    if (map['sniperSway'] is Map) sniperSway.restore(map['sniperSway'] as Map);
    for (final raw in map['flights'] as List) {
      final f = ArsenalFlight(
        raw['id'],
        ArsenalFlightKind.values.byName(raw['kind']),
        point(raw['position']),
        point(raw['direction']),
        (raw['damage'] as num).toDouble(),
        (raw['speed'] as num).toDouble(),
        (raw['range'] as num).toDouble(),
        destination: point(raw['destination']),
      );
      f.patchDamage = (raw['patchDamage'] as num?)?.toDouble() ?? .8;
      f.travelled = (raw['travelled'] as num).toDouble();
      f.age = (raw['age'] as num).toDouble();
      f.duration = (raw['duration'] as num).toDouble();
      f.returning = raw['returning'];
      f.impactPending = raw['impactPending'];
      f.outHits.addAll((raw['outHits'] as List).cast<int>());
      f.returnHits.addAll((raw['returnHits'] as List).cast<int>());
      flights.add(f);
    }
    for (final raw in map['rivets'] as List) {
      final r = RivetPayload(
        raw['id'],
        raw['host'],
        point(raw['position']),
        (raw['damage'] as num).toDouble(),
      )..remaining = (raw['remaining'] as num).toDouble();
      rivets.add(r);
    }
    for (final raw in map['patches'] as List) {
      patches.add(
        SporePatch(
          raw['id'],
          point(raw['position']),
          (raw['damage'] as num).toDouble(),
        )..remaining = (raw['remaining'] as num).toDouble(),
      );
    }
  }
}

/// Two bounded render layers share the authoritative system's exact positions.
class ArsenalOverlay extends PositionComponent
    with HasGameReference<RegunGame> {
  ArsenalOverlay({this.floor = false}) : super(priority: floor ? -10 : 20005);
  final bool floor;
  @override
  void render(Canvas canvas) {
    final system = game.arsenal;
    if (system == null || !game.loadout.weapon.usesArsenalRuntime) return;
    final art = RegunArt.shared, weapon = game.loadout.weapon;
    final spec = WeaponArtSpec.of(weapon);
    final view = canvas.getLocalClipBounds().inflate(300);
    final grade = BossArt.ambient(game.loadout.arena);
    system.endgame.render(canvas, floor: floor, view: view, grade: grade);
    if (floor) {
      for (final p in system.patches) {
        if (!view.contains(p.position.toOffset())) continue;
        AttackVfx.sporePatch(
          canvas,
          p.position.toOffset(),
          100,
          progress: 1 - p.remaining / 2.5,
          ambient: grade,
          reducedMotion: game.preferences.reducedMotion,
        );
        // Small brass corners distinguish a friendly patch from hostile poison.
        for (final side in [-1, 1]) {
          AttackVfx.chip(
            canvas,
            p.position.toOffset() + Offset(side * 70, 30),
            4,
            const Color(0x80939372),
          );
        }
      }
      if (weapon.firesOnRelease &&
          !system.rawAim.isZero() &&
          system.ready &&
          !game.playerEntrance.active) {
        final direction = system.aim, from = system.muzzle(direction);
        if (weapon == WeaponType.longwatchSniper ||
            weapon == WeaponType.faultlineDriver) {
          final end = system.clip(
            from,
            from + direction * system.effectiveRange,
          );
          final distance = from.distanceTo(end);
          for (var d = 12.0; d < distance; d += 28) {
            AttackVfx.chip(
              canvas,
              (from + direction * d).toOffset(),
              2,
              const Color(0x779DAD9F),
            );
          }
        } else {
          final end = system.previewLanding(direction), delta = end - from;
          paintGrenadeTrajectory(canvas, [
            for (var i = 0; i <= 16; i++)
              GrenadePreviewPoint(
                (from + delta * (i / 16)).toOffset(),
                (weapon == WeaponType.scrapMortar ||
                        weapon == WeaponType.anchorEngine)
                    ? math.sin(i / 16 * math.pi) * 60
                    : math.sin(i / 16 * math.pi) * 12,
              ),
          ], reducedMotion: game.preferences.reducedMotion);
        }
      }
      for (final f in system.flights.where(
        (f) =>
            f.kind == ArsenalFlightKind.mortar ||
            f.kind == ArsenalFlightKind.anchor,
      )) {
        canvas.drawOval(
          Rect.fromCenter(center: f.position.toOffset(), width: 20, height: 7),
          Paint()..color = const Color(0x700C1113),
        );
      }
      return;
    }
    for (final f in system.flights) {
      if (!view.contains(f.position.toOffset()) || !art.contains(spec.atlas)) {
        continue;
      }
      canvas.save();
      final lift =
          (f.kind == ArsenalFlightKind.mortar ||
                  f.kind == ArsenalFlightKind.anchor) &&
              !game.preferences.reducedMotion
          ? math.sin(
                  (f.age / math.max(.001, f.duration)).clamp(0, 1) * math.pi,
                ) *
                80
          : 0.0;
      canvas.translate(f.position.x, f.position.y - lift);
      canvas.rotate(
        f.kind == ArsenalFlightKind.disc && !game.preferences.reducedMotion
            ? f.age * 24
            : math.atan2(f.direction.y, f.direction.x),
      );
      final sprite = art.rawSprite(
        spec.atlas,
        (f.kind == ArsenalFlightKind.mortar ||
                f.kind == ArsenalFlightKind.anchor)
            ? 1
            : 2,
      );
      final size = f.kind == ArsenalFlightKind.disc
          ? Vector2.all(34)
          : Vector2(22, 14);
      sprite.render(
        canvas,
        size: size,
        anchor: Anchor.center,
        overridePaint: Paint()..colorFilter = grade,
      );
      canvas.restore();
    }
    for (final r in system.rivets) {
      if (!view.contains(r.position.toOffset())) continue;
      final rivetSprite = art.rawSprite('weapons/rivet_driver', 3);
      rivetSprite.render(
        canvas,
        position: r.position + Vector2((r.id % 2) * 12 - 6, -14),
        size: Vector2(10, 24),
        anchor: Anchor.center,
        overridePaint: Paint()..colorFilter = grade,
      );
      AttackVfx.chip(
        canvas,
        r.position.toOffset() + Offset((r.id % 2) * 8 - 4, -12),
        10,
        r.remaining < .2 ? const Color(0xffD2AF76) : const Color(0xffA99C82),
      );
    }
    if (weapon == WeaponType.cinderHose &&
        art.contains('effects/cinder_flame')) {
      for (final tongue in system.flame.tongues) {
        if (!view.contains(tongue.position.toOffset())) continue;
        final p = (tongue.age / tongue.life).clamp(0.0, 1.0);
        final fade = math.min(1.0, tongue.age / .035) * (1 - p);
        canvas.save();
        canvas.translate(tongue.position.x, tongue.position.y);
        canvas.rotate(math.atan2(tongue.direction.y, tongue.direction.x));
        final length = 85 + p * 55;
        final end = system.clip(
          tongue.position,
          tongue.position + tongue.direction * (length - 10),
        );
        canvas.clipRect(
          Rect.fromLTRB(-10, -length, end.distanceTo(tongue.position), length),
        );
        final frame = game.preferences.reducedMotion
            ? 1
            : ((tongue.age * 17).floor() + tongue.seed) % 3;
        art
            .rawSprite('effects/cinder_flame', frame)
            .render(
              canvas,
              position: Vector2(-10, -length * .24),
              size: Vector2(length, length * .48),
              overridePaint: Paint()
                ..filterQuality = FilterQuality.none
                ..colorFilter = grade
                ..color = Color.fromRGBO(255, 255, 255, fade * .9),
            );
        canvas.restore();
      }
    }
    if (weapon.isContinuous &&
        system.beamFrom != null &&
        system.beamTo != null &&
        system._beamAge < .13 &&
        !game.gameState.reloading) {
      final from = system.beamFrom!.toOffset(), to = system.beamTo!.toOffset();
      if (weapon == WeaponType.prismCutter) {
        // Dense textured light fragments, clipped to the same contact segment.
        final delta = to - from,
            count = math.max(1, ((to - from).distance / 10).ceil());
        for (var i = 0; i <= count; i++) {
          AttackVfx.chip(
            canvas,
            from + delta * (i / count),
            i % 3 == 0 ? 7 : 4,
            i % 2 == 0 ? const Color(0xffDFDAC1) : const Color(0xffA5B4A5),
          );
        }
      }
    }
  }
}
