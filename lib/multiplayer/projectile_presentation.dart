import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/weapon_feel.dart';

import 'combat_state.dart';
import 'identity_key.dart';

/// Swept visual clipping mirrors combat.ts wallContact's five-unit radius.
/// This never reports a hit or changes an authoritative round.
class ProjectileMap {
  ProjectileMap(Map<String, dynamic> data)
    : bounds = rect(data['bounds'] as List),
      obstacles = [for (final r in data['obstacles'] as List) rect(r as List)];
  static Rect rect(List r) => Rect.fromLTRB(
    (r[0] as num).toDouble(),
    (r[1] as num).toDouble(),
    (r[2] as num).toDouble(),
    (r[3] as num).toDouble(),
  );
  final Rect bounds;
  final List<Rect> obstacles;
  static double? segment(Offset a, Offset b, Rect r) {
    var enter = 0.0, exit = 1.0;
    for (final axis in [
      (a.dx, b.dx - a.dx, r.left, r.right),
      (a.dy, b.dy - a.dy, r.top, r.bottom),
    ]) {
      if (axis.$2.abs() < 1e-10) {
        if (axis.$1 < axis.$3 || axis.$1 > axis.$4) return null;
      } else {
        var lo = (axis.$3 - axis.$1) / axis.$2,
            hi = (axis.$4 - axis.$1) / axis.$2;
        if (lo > hi) {
          final old = lo;
          lo = hi;
          hi = old;
        }
        enter = math.max(enter, lo);
        exit = math.min(exit, hi);
        if (enter > exit) return null;
      }
    }
    return enter;
  }

  (Offset, bool) clip(
    Offset a,
    Offset b, [
    List<(Offset, double)> bodies = const [],
  ]) {
    var first = 1.0;
    var blocked = false;
    void hit(double? t) {
      if (t != null && t <= first) {
        first = t;
        blocked = true;
      }
    }

    for (final r in obstacles) {
      hit(segment(a, b, r.inflate(5)));
    }
    final inside = bounds.deflate(5);
    if (!inside.contains(b)) {
      final d = b - a;
      if (b.dx < inside.left && d.dx < 0) hit((inside.left - a.dx) / d.dx);
      if (b.dx > inside.right && d.dx > 0) hit((inside.right - a.dx) / d.dx);
      if (b.dy < inside.top && d.dy < 0) hit((inside.top - a.dy) / d.dy);
      if (b.dy > inside.bottom && d.dy > 0) hit((inside.bottom - a.dy) / d.dy);
    }
    for (final body in bodies) {
      final s = a - body.$1, d = b - a, radius = body.$2 + 5;
      final c = s.distanceSquared - radius * radius, aa = d.distanceSquared;
      if (c <= 0) {
        hit(0);
        continue;
      }
      if (aa < 1e-10) continue;
      final bb = 2 * (s.dx * d.dx + s.dy * d.dy), disc = bb * bb - 4 * aa * c;
      if (disc < 0) continue;
      final t = (-bb - math.sqrt(disc)) / (2 * aa);
      if (t >= 0 && t <= 1) hit(t);
    }
    return (a + (b - a) * first.clamp(0.0, 1.0), blocked);
  }
}

class _Flight {
  _Flight(this.round, this.at, this.serverTime);
  OnlineRound round;
  double at, serverTime, lead = 0, hiddenUntilDistance = -1;
  Offset correction = Offset.zero;
}

class _Ghost {
  _Ghost(this.round, this.born);
  final OnlineRound round;
  final double born;
  bool done = false;
  double doneDistance = double.infinity;
}

/// Frame-rate projectile visuals. Everything in here is presentation only:
/// server rows still own collision, ammo, hits, damage and deletion.
class ProjectilePresentation {
  final _flights = <String, _Flight>{};
  final _ghosts = <String, _Ghost>{};
  final _predictedShots = <String, double>{};
  final _claimed = <String>{};
  String? _epoch, _weapon;
  int _nextShot = 0, _cueCount = 0, _tick = -1, _burst = -1, _blockedBurst = -1;
  double _nextFire = 0, _lastSnapshot = -100;
  List<OnlineRound> _raw = [];
  int matched = 0;
  int get speculativeCount => _ghosts.values.where((g) => !g.done).length;
  int get trackedCount => _flights.length;
  bool wasPredicted(OnlineGun gun) => _predictedShots.containsKey(
    '${gun.data['lastShotBurst'] ?? gun.data['fireBurst']}:${gun.data['lastBurstShot'] ?? gun.data['burstShot']}',
  );
  bool takeCue() {
    final cue = _cueCount > 0;
    _cueCount = 0;
    return cue;
  }

  void clear() {
    _flights.clear();
    _ghosts.clear();
    _predictedShots.clear();
    _claimed.clear();
    _epoch = _weapon = null;
    _nextShot = _cueCount = 0;
    _tick = _burst = _blockedBurst = -1;
    _nextFire = 0;
    _lastSnapshot = -100;
    _raw = [];
    matched = 0;
  }

  void cancelPrediction() {
    _ghosts.clear();
    _cueCount = 0;
  }

  static String? key(OnlineRound r) =>
      r.data['primary'] == true &&
          r.data['hostile'] != true &&
          r.data['burst'] is String &&
          r.data['burstShot'] is num &&
          r.data['pellet'] is num
      ? '${r.owner}:${r.data['burst']}:${r.data['burstShot']}:${r.data['pellet']}'
      : null;
  static Offset point(OnlineRound r) => Offset(r.x, r.y);
  static Offset direction(OnlineRound r) => Offset(r.dx, r.dy);
  static double remaining(OnlineRound r) =>
      math.max(0, combatNumber(r.data, 'range') - r.distance);

  void capture({
    required String epoch,
    required int tick,
    required double now,
    required double serverTime,
    required List<OnlineRound> rounds,
    required String identity,
    required OnlineGun? gun,
    required ProjectileMap map,
  }) {
    if (_epoch != epoch || _weapon != gun?.weapon) {
      clear();
      _epoch = epoch;
      _weapon = gun?.weapon;
      _nextShot = 0;
      _nextFire = now + (gun?.cooldown ?? 0);
    }
    _raw = rounds;
    if (tick > _tick) {
      _tick = tick;
      _lastSnapshot = now;
    }
    final confirmed = gun?.data['fireBurst'] == '$_burst'
        ? combatNumber(gun!.data, 'burstShot').toInt()
        : 0;
    _nextShot = math.max(_nextShot, confirmed);
    final present = rounds.map((r) => r.id).toSet();
    _flights.removeWhere((id, _) => !present.contains(id));
    for (final r in rounds) {
      if (r.data['kind'] == 'grenade') continue;
      final tag = key(r), ghost = _ghosts[tag];
      final old = _flights[r.id];
      if (old != null && serverTime <= old.serverTime) continue;
      final before = old == null ? null : _renderFlight(old, now, map);
      final f = old ?? _Flight(r, now, serverTime);
      final changed =
          old != null && (direction(old.round) - direction(r)).distance > .01;
      if (changed) {
        f.lead = 0;
        f.hiddenUntilDistance = -1;
        f.correction = Offset.zero;
      }
      f.round = r;
      f.at = now;
      f.serverTime = serverTime;
      if (ghost != null && !_claimed.contains(tag)) {
        _claimed.add(tag!);
        matched++;
        // Completed/near-muzzle flights must not reappear behind the player.
        if (ghost.done) {
          f.hiddenUntilDistance = ghost.doneDistance;
          f.lead = 0;
        } else {
          final visual = _ghostPosition(ghost, now, map, const []);
          if (visual != null) {
            final d = direction(r), delta = visual - point(r);
            f.lead = (delta.dx * d.dx + delta.dy * d.dy).clamp(
              0.0,
              r.speed * .3,
            );
            final target = point(r) + d * f.lead;
            final error = visual - target;
            f.correction = error.distance < 80 ? error : Offset.zero;
          } else {
            f.hiddenUntilDistance = ghost.doneDistance;
            f.lead = 0;
          }
        }
        _ghosts.remove(tag);
      } else if (before != null && !changed && f.lead.isFinite) {
        final target = point(r) + direction(r) * f.lead;
        final error = before - target;
        f.correction = error.distance < 80 ? error : Offset.zero;
      }
      _flights[r.id] = f;
    }
    // A confirmed shot can hit cover/a nearby body in its birth transaction and
    // never expose a projectile row. Retire unmatched pellets immediately.
    _ghosts.removeWhere((_, g) {
      final burst = g.round.data['burst'];
      final shot = combatNumber(g.round.data, 'burstShot');
      return (burst == gun?.data['fireBurst'] &&
              shot <= combatNumber(gun!.data, 'burstShot')) ||
          (burst == gun?.data['lastShotBurst'] &&
              shot <= combatNumber(gun!.data, 'lastBurstShot'));
    });
    _expire(now);
  }

  void predict({
    required double now,
    required bool enabled,
    required bool held,
    required OnlineGun? gun,
    required Offset origin,
    required Offset aim,
    required String identity,
    required int team,
    required int burst,
  }) {
    if (!enabled || gun == null || now - _lastSnapshot > .25) {
      cancelPrediction();
      return;
    }
    _expire(now);
    if (_burst != burst) {
      _burst = burst;
      _nextShot = 0;
    }
    final confirmed = gun.data['fireBurst'] == '$burst'
        ? combatNumber(gun.data, 'burstShot').toInt()
        : 0;
    _nextShot = math.max(_nextShot, confirmed);
    if (_blockedBurst == burst ||
        !held ||
        gun.reloading ||
        aim.distance < .001 ||
        now < _nextFire) {
      return;
    }
    final outstanding = _predictedShots.keys
        .where(
          (k) => _ghosts.values.any(
            (g) => '${g.round.data['burst']}:${g.round.data['burstShot']}' == k,
          ),
        )
        .length;
    if (outstanding >= 6 ||
        gun.ammo - outstanding <= 0 ||
        _ghosts.length >= 64) {
      return;
    }
    final oldest = _predictedShots.entries.where(
      (e) =>
          e.key.startsWith('$burst:') &&
          int.parse(e.key.split(':').last) > confirmed,
    );
    if (oldest.any((e) => now - e.value > .6)) return;
    final weapon = WeaponType.values.byName(gun.weapon);
    final extra = gun.rank('numberOfBulletsPerShotIncrease');
    final pellets = weapon == WeaponType.shotgun
        ? 3 + extra.clamp(0, 3) * 2
        : 1 + extra.clamp(0, 3);
    if (_ghosts.length + pellets > 64) return;
    final speedRank = gun.rank('rapidFire'),
        rangeRank = gun.rank('bulletRangeIncrease');
    final speed =
        gun.baseNumber('speed', weapon.speed) +
        math.min(
          800,
          ((speedRank.clamp(0, 3) * 200 + (speedRank - 3).clamp(0, 5) * 40) *
                  gun.strength('rapidFire'))
              .round(),
        );
    final range =
        gun.baseNumber('range', weapon.range) +
        ((rangeRank.clamp(0, 3) * 60 + (rangeRank - 3).clamp(0, 5) * 24) *
                gun.strength('bulletRangeIncrease'))
            .round();
    final trigger = gun.rank('quickTrigger');
    final effective =
        (trigger.clamp(0, 3) + (trigger - 3).clamp(0, 5) * .3) *
        gun.strength('quickTrigger');
    // Server advanceGun/fire runs once per50ms; match its quantized cadence.
    final cadence =
        (gun.baseNumber('cadence', weapon.cadence) *
                    math.pow(.85, effective) /
                    .05 -
                1e-8)
            .ceil() *
        .05;
    _nextFire = now - _nextFire <= .025 ? _nextFire + cadence : now + cadence;
    final shot = ++_nextShot;
    _predictedShots['$burst:$shot'] = now;
    _cueCount++;
    final angle = math.atan2(aim.dy, aim.dx);
    // Carbine's random +/-2 degree heading/muzzle offsets are server-owned.
    // The initial visual uses centered intent and joins that exact trajectory.
    for (var i = 0; i < pellets; i++) {
      final a =
          angle +
          (i - (pellets - 1) / 2) *
              (weapon == WeaponType.shotgun ? math.pi / 20 : math.pi / 32) *
              (1 - math.max(0, extra - 3) * .04);
      final d = Offset(math.cos(a), math.sin(a));
      final p =
          origin + const Offset(0, 6) + d * (WeaponFeel.of(weapon).muzzle + 8);
      final round = OnlineRound('local:$burst:$shot:$i', {
        'x': p.dx,
        'y': p.dy,
        'dx': d.dx,
        'dy': d.dy,
        'originX': p.dx,
        'originY': p.dy,
        'speed': speed,
        'range': range,
        'distance': 0,
        'owner': RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(identity)
            ? identityKeyFromCanonical(identity)
            : identity,
        'team': team,
        'weapon': weapon.name,
        'burst': '$burst',
        'burstShot': shot,
        'pellet': i,
        'primary': true,
      });
      _ghosts[key(round)!] = _Ghost(round, now);
    }
  }

  void _expire(double now) {
    if (_ghosts.values.any(
      (g) => g.round.data['burst'] == '$_burst' && now - g.born > .6,
    )) {
      _blockedBurst = _burst;
    }
    _ghosts.removeWhere((_, g) => now - g.born > .6);
    _predictedShots.removeWhere((_, at) => now - at > 2);
    final activeKeys = _flights.values.map((f) => key(f.round)).toSet();
    _claimed.removeWhere((k) => !activeKeys.contains(k));
  }

  Offset? _ghostPosition(
    _Ghost g,
    double now,
    ProjectileMap map,
    List<(Offset, double)> bodies,
  ) {
    if (g.done) return null;
    final r = g.round, distance = math.max(0.0, now - g.born) * r.speed;
    final origin = point(r),
        end = origin + direction(r) * math.min(distance, remaining(r));
    // Check barrel clipping too; a ghost cannot start on the far side of cover.
    final back =
        origin -
        direction(r) *
            (WeaponFeel.of(WeaponType.values.byName(r.weapon)).muzzle + 8);
    if (map.clip(back, origin).$2) {
      g.done = true;
      g.doneDistance = 0;
      return null;
    }
    final clipped = map.clip(origin, end, bodies);
    if (clipped.$2 || distance >= remaining(r)) {
      g.done = true;
      g.doneDistance = clipped.$2
          ? (clipped.$1 - origin).distance
          : double.infinity;
      return null;
    }
    return clipped.$1;
  }

  Offset? _renderFlight(_Flight f, double now, ProjectileMap map) {
    if (!f.lead.isFinite) return null;
    final r = f.round;
    if (r.distance <= f.hiddenUntilDistance + 5 && f.hiddenUntilDistance >= 0) {
      return null;
    }
    f.hiddenUntilDistance = -1;
    final elapsed = (now - f.at).clamp(0.0, .08);
    final distance = math.min(remaining(r), r.speed * elapsed + f.lead);
    final correction = f.correction * math.exp(-35 * elapsed);
    final clipped = map.clip(
      point(r),
      point(r) + direction(r) * distance + correction,
    );
    if (distance >= remaining(r) || clipped.$2) return null;
    return clipped.$1;
  }

  List<OnlineRound> render(
    double now,
    ProjectileMap map, {
    bool active = true,
    List<(Offset, double)> bodies = const [],
  }) {
    if (!active) return _raw;
    _expire(now);
    final result = <OnlineRound>[];
    for (final r in _raw) {
      if (r.data['kind'] == 'grenade') {
        result.add(r);
        continue;
      }
      final f = _flights[r.id];
      if (f == null) continue;
      final p = _renderFlight(f, now, map);
      if (p != null) {
        result.add(OnlineRound(r.id, {...r.data, 'x': p.dx, 'y': p.dy}));
      }
    }
    for (final g in _ghosts.values) {
      final p = _ghostPosition(g, now, map, bodies);
      if (p != null) {
        result.add(
          OnlineRound(g.round.id, {...g.round.data, 'x': p.dx, 'y': p.dy}),
        );
      }
    }
    return result;
  }
}
