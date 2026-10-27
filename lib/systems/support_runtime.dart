import 'dart:math';
import 'dart:ui';

import 'package:regun/systems/support_rewards.dart';
import 'package:regun/systems/support_aim.dart';

/// Serializable simulation only. Presentation never owns a phase or damage receipt.
class SupportUnit {
  SupportUnit(this.card, this.serial, this.position)
    : phase = card.family == SupportFamily.aura ? 'activating' : 'following';
  final SupportCard card;
  final int serial;
  Offset position;
  String phase;
  double elapsed = 0,
      life = 0,
      heading = 0,
      reload = 0,
      shot = 0,
      burstWait = 0,
      query = 0,
      blocked = 0,
      recoil = 0;
  int ammo = -1, burst = 0, shotsFired = 0;
  String? target;
  bool landed = false, broken = false;
  bool get solid =>
      ['deploying', 'active'].contains(phase) &&
      card.family == SupportFamily.sentry;
  bool get reserved =>
      ['warning', 'falling', 'deploying', 'active'].contains(phase) &&
      card.family == SupportFamily.sentry;
  Rect get footprint =>
      Rect.fromLTWH(position.dx - 35, position.dy - 44, 70, 44);
  Map<String, dynamic> toJson() => {
    'id': card.id,
    'serial': serial,
    'x': position.dx,
    'y': position.dy,
    'phase': phase,
    'elapsed': elapsed,
    'life': life,
    'heading': heading,
    'reload': reload,
    'shot': shot,
    'burstWait': burstWait,
    'query': query,
    'blocked': blocked,
    'recoil': recoil,
    'ammo': ammo,
    'shotsFired': shotsFired,
    'burst': burst,
    'target': target,
    'landed': landed,
    'broken': broken,
  };
  static SupportUnit restore(dynamic raw) {
    if (raw is! Map) throw const FormatException('Invalid support unit');
    final card = SupportCard.read(raw['id'] as String? ?? '');
    if (card == null ||
        raw['serial'] is! int ||
        raw['serial'] < 1 ||
        raw['serial'] > 1000000) {
      throw const FormatException('Invalid support identity');
    }
    double n(String key, double max) {
      final v = raw[key];
      if (v is! num || !v.isFinite || v.abs() > max) {
        throw const FormatException('Invalid support number');
      }
      return v.toDouble();
    }

    final u = SupportUnit(
      card,
      raw['serial'],
      Offset(n('x', 10000), n('y', 10000)),
    );
    u.phase = raw['phase'] as String;
    final phases = card.family == SupportFamily.aura
        ? ['activating', 'active', 'fading']
        : [
            'following',
            'finding',
            'warning',
            'falling',
            'deploying',
            'active',
            'breaking',
          ];
    if (!phases.contains(u.phase)) {
      throw const FormatException('Invalid support phase');
    }
    u.elapsed = n('elapsed', 120);
    u.life = n('life', 120);
    u.heading = n('heading', 100);
    u.reload = n('reload', 12);
    u.shot = n('shot', 5);
    u.burstWait = n('burstWait', 5);
    u.query = n('query', 1);
    u.blocked = n('blocked', 5);
    u.recoil = n('recoil', 1);
    if ([
      u.elapsed,
      u.life,
      u.reload,
      u.shot,
      u.burstWait,
      u.query,
      u.blocked,
      u.recoil,
    ].any((v) => v < 0)) {
      throw const FormatException('Negative support clock');
    }
    u.ammo = raw['ammo'] as int;
    final fired = raw['shotsFired'] ?? 0;
    if (fired is! int || fired < 0 || fired > 1000000) {
      throw const FormatException('Invalid support shots');
    }
    u.shotsFired = fired;
    u.burst = raw['burst'] as int;
    u.target = raw['target'] as String?;
    u.landed = raw['landed'] == true;
    u.broken = raw['broken'] == true;
    if (u.ammo < -1 ||
        u.ammo > 100 ||
        u.burst < 0 ||
        u.burst > 4 ||
        (u.target?.length ?? 0) > 120 ||
        (card.family == SupportFamily.sentry &&
            (u.landed !=
                    ['deploying', 'active', 'breaking'].contains(u.phase) ||
                u.broken != (u.phase == 'breaking')))) {
      throw const FormatException('Invalid support receipt');
    }
    return u;
  }
}

class SupportTarget {
  const SupportTarget(
    this.id,
    this.position,
    this.radius, {
    this.vulnerable = true,
    this.velocity = Offset.zero,
  });
  final String id;
  final Offset position;
  final double radius;
  final bool vulnerable;
  final Offset velocity;
}

class SupportRound {
  SupportRound(
    this.serial,
    this.mount,
    this.position,
    this.direction,
    this.damage,
    this.speed,
    this.range,
  );
  final int serial;
  final String mount;
  Offset position;
  final Offset direction;
  final double damage, speed, range;
  double travel = 0;
  double delay = 0;
  Map<String, dynamic> toJson() => {
    'serial': serial,
    'mount': mount,
    'x': position.dx,
    'y': position.dy,
    'dx': direction.dx,
    'dy': direction.dy,
    'damage': damage,
    'speed': speed,
    'range': range,
    'travel': travel,
  };
  static SupportRound restore(dynamic r) {
    if (r is! Map ||
        r['serial'] is! int ||
        r['serial'] < 1 ||
        !['carbine', 'burstRifle'].contains(r['mount'])) {
      throw const FormatException('Invalid support round');
    }
    double n(String k, double bound) {
      final v = r[k];
      if (v is! num || !v.isFinite || v.abs() > bound) {
        throw const FormatException('Invalid support flight');
      }
      return v.toDouble();
    }

    final d = Offset(n('dx', 1), n('dy', 1));
    final s = SupportRound(
      r['serial'],
      r['mount'],
      Offset(n('x', 10000), n('y', 10000)),
      d,
      n('damage', 600),
      n('speed', 2000),
      n('range', 2000),
    )..travel = n('travel', 2000);
    if ((d.distance - 1).abs() > .001 ||
        s.damage <= 0 ||
        s.speed < 100 ||
        s.range < 60 ||
        s.travel < 0 ||
        s.travel >= s.range) {
      throw const FormatException('Invalid support flight values');
    }
    return s;
  }
}

class SupportRuntime {
  final List<SupportUnit> units = [];
  final Map<String, double> metrics = {};
  final List<SupportRound> rounds = [];
  double tickClock = 0;
  double frameOffset = 0;
  void clear(SupportProgress progress) {
    units.clear();
    rounds.clear();
    metrics.clear();
    tickClock = 0;
    frameOffset = 0;
    progress.busy.clear();
    progress.pending.clear();
  }

  Iterable<Rect> get solids =>
      units.where((u) => u.solid).map((u) => u.footprint);
  Iterable<Rect> get reservations =>
      units.where((u) => u.reserved).map((u) => u.footprint);
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'metrics': metrics,
    'units': units.map((u) => u.toJson()).toList(),
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'tickClock': tickClock,
  };
  void restore(dynamic raw, SupportProgress progress, SupportConfig config) {
    units.clear();
    rounds.clear();
    tickClock = 0;
    if (raw == null) {
      if (progress.busy.length != progress.pending.length) {
        throw const FormatException('Missing support runtime');
      }
      return;
    }
    if (raw is! Map || raw['schema'] != 1) {
      throw const FormatException('Invalid support runtime');
    }
    final clock = raw['tickClock'];
    if (clock is! num || !clock.isFinite || clock < 0 || clock >= config.tick) {
      throw const FormatException('Invalid aura clock');
    }
    tickClock = clock.toDouble();
    metrics.clear();
    if (raw['metrics'] case final Map saved) {
      if (saved.length > 8) {
        throw const FormatException('Invalid support metrics');
      }
      for (final e in saved.entries) {
        if (e.key is! String ||
            ![
              'sentry_round',
              'aura',
              'sentry_land_crush',
              'sentry_land_blast',
              'sentry_break_crush',
              'sentry_break_blast',
            ].contains(e.key) ||
            e.value is! num ||
            !e.value.isFinite ||
            e.value < 0 ||
            e.value > 1e12) {
          throw const FormatException('Invalid support metrics');
        }
        metrics[e.key] = e.value.toDouble();
      }
    }
    units.addAll((raw['units'] as List).map(SupportUnit.restore));
    rounds.addAll((raw['rounds'] as List).map(SupportRound.restore));
    final families = units.map((u) => u.card.family.name).toList();
    if (units.length > 2 ||
        families.toSet().length != families.length ||
        rounds.length > 8 ||
        units.map((u) => u.serial).toSet().length != units.length ||
        rounds.any((r) => r.serial > progress.serial) ||
        units.any(
          (u) =>
              !progress.busy.contains(u.card.family.name) ||
              u.serial > progress.serial ||
              u.card.tier != progress.tiers[u.card.family.name],
        ) ||
        families.any((f) => progress.pending.any((p) => p.family.name == f)) ||
        progress.busy.length != units.length + progress.pending.length) {
      throw const FormatException('Invalid support capacity');
    }
    for (final u in units) {
      if (u.burst > config.behavior('burstRifle', 'burstRounds', 3) - 1) {
        throw const FormatException('Invalid support burst');
      }
      final maxLife = u.card.family == SupportFamily.aura
          ? config.auraLife(u.card.tier)
          : config.sentryLife(u.card.tier);
      final duration = switch (u.phase) {
        'following' => config.incoming - 2.45,
        'finding' => .5,
        'warning' => 1.8,
        'falling' => .65,
        'deploying' => .55,
        'activating' => .35,
        'breaking' => 1.3,
        'fading' => .35,
        _ => maxLife,
      };
      if (u.elapsed > duration + 1e-6 ||
          u.life > maxLife + 1e-6 ||
          u.serial < 1) {
        throw const FormatException('Invalid support phase clock');
      }
    }
  }

  /// All callbacks use authoritative world state. Caller supplies simulation time only.
  void advance(
    double dt, {
    required Offset player,
    required SupportProgress progress,
    required SupportConfig config,
    required List<SupportTarget> Function() targets,
    required Offset? Function(Offset, SupportUnit) place,
    required bool Function(Offset, Offset, SupportUnit?) blocked,
    required void Function(SupportUnit, bool) impact,
    required bool Function(SupportUnit, Offset, Offset, double) release,
    required void Function(SupportTarget, double) auraHit,
    required void Function(SupportUnit, String) cue,
  }) {
    if (!dt.isFinite || dt <= 0) return;
    // Bounded substeps; a pathological stall does not synthesize offline combat.
    var remaining = min(dt, .5);
    while (remaining > 1e-8) {
      final step = min(remaining, .025);
      remaining -= step;
      frameOffset = min(dt, .5) - remaining;
      while (progress.pending.isNotEmpty) {
        final card = progress.pending.removeAt(0);
        units.add(
          SupportUnit(card, progress.serial - progress.pending.length, player),
        );
        cue(units.last, 'incoming');
      }
      tickClock += step;
      final tick = tickClock + 1e-8 >= config.tick;
      if (tick) tickClock = max(0, tickClock - config.tick);
      for (final u in units.toList()) {
        u.elapsed += step;
        u.recoil = max(0, u.recoil - step);
        if (u.card.family == SupportFamily.aura) {
          u.position = player;
          if (u.phase == 'activating' && u.elapsed + 1e-8 >= .35) {
            u.phase = 'active';
            u.elapsed = 0;
            cue(u, 'activate');
            continue;
          }
          if (u.phase == 'active') {
            u.life += step;
            if (u.life + 1e-8 >= config.auraLife(u.card.tier)) {
              u.life = config.auraLife(u.card.tier);
              u.phase = 'fading';
              u.elapsed = 0;
              cue(u, 'shutdown');
              continue;
            }
            if (tick) {
              final pool =
                  targets()
                      .where(
                        (t) =>
                            t.vulnerable &&
                            (t.position - player).distance <=
                                config.auraRadius(u.card.tier) + t.radius &&
                            !blocked(player, t.position, null),
                      )
                      .toList()
                    ..sort((a, b) {
                      final d = (a.position - player).distance.compareTo(
                        (b.position - player).distance,
                      );
                      return d == 0 ? a.id.compareTo(b.id) : d;
                    });
              for (final t in pool.take(config.targets)) {
                auraHit(t, config.auraDamage(u.card.tier));
              }
            }
          } else if (u.phase == 'fading' && u.elapsed >= .35) {
            units.remove(u);
            progress.busy.remove('aura');
          }
          continue;
        }
        switch (u.phase) {
          case 'following':
            final candidate = place(player, u);
            if (candidate != null) u.position = candidate;
            if (u.elapsed + 1e-8 >= config.incoming - 2.45) {
              final locked = place(player, u);
              u.elapsed = 0;
              if (locked == null) {
                u.phase = 'finding';
              } else {
                u.position = locked;
                u.phase = 'warning';
                cue(u, 'lock');
              }
            }
          case 'finding':
            if (u.elapsed >= .5) {
              u.elapsed = 0;
              final candidate = place(player, u);
              if (candidate != null) {
                u.position = candidate;
                u.phase = 'warning';
                cue(u, 'lock');
              }
            }
          case 'warning':
            if (u.elapsed + 1e-8 >= 1.8) {
              u.phase = 'falling';
              u.elapsed = 0;
            }
          case 'falling':
            if (u.elapsed + 1e-8 >= .65) {
              u.phase = 'deploying';
              u.elapsed = 0;
              u.landed = true;
              impact(u, false);
              cue(u, 'land');
            }
          case 'deploying':
            if (u.elapsed + 1e-8 >= .55) {
              u.phase = 'active';
              u.elapsed = 0;
              u.ammo = -1;
              u.reload = 0;
            }
          case 'active':
            u.life += step;
            if (u.life + 1e-8 >= config.sentryLife(u.card.tier)) {
              u.life = config.sentryLife(u.card.tier);
              u.phase = 'breaking';
              u.elapsed = 0;
              u.broken = true;
              u.burst = 0;
              impact(u, true);
              cue(u, 'break');
              continue;
            }
            _fire(u, step, config, targets, blocked, release, cue);
          case 'breaking':
            if (u.elapsed + 1e-8 >= 1.3) {
              units.remove(u);
              progress.busy.remove('sentry');
            }
        }
      }
    }
  }

  void _fire(
    SupportUnit u,
    double dt,
    SupportConfig c,
    List<SupportTarget> Function() targets,
    bool Function(Offset, Offset, SupportUnit?) blocked,
    bool Function(SupportUnit, Offset, Offset, double) release,
    void Function(SupportUnit, String) cue,
  ) {
    final all = targets();
    var target = all.where((t) => t.id == u.target).firstOrNull;
    u.query = max(0, u.query - dt);
    u.shot = max(0, u.shot - dt);
    u.burstWait = max(0, u.burstWait - dt);
    bool legal(SupportTarget t) =>
        t.vulnerable &&
        (t.position - u.position).distance <= c.acquisition(u.card.mount) &&
        !blocked(u.position + const Offset(0, -42), t.position, u);
    if (target == null) {
      u.target = null;
      u.blocked = 0;
      u.burst = 0;
    } else if (!legal(target)) {
      u.blocked += dt;
      u.burst = 0;
      if (u.blocked + 1e-8 >= c.fallback) {
        u.target = null;
        target = null;
      }
    } else {
      u.blocked = 0;
    }
    if (u.target == null && u.query <= 0) {
      u.query = .1;
      final pool = all.where(legal).toList()
        ..sort((a, b) {
          final d = (a.position - u.position).distance.compareTo(
            (b.position - u.position).distance,
          );
          return d == 0 ? a.id.compareTo(b.id) : d;
        });
      target = pool.firstOrNull;
      u.target = target?.id;
      u.blocked = 0;
    }
    // Legacy saved magazine/reload values no longer affect this unlimited mount.
    u.ammo = -1;
    u.reload = 0;
    if (target == null) return;
    final pivot = u.position + const Offset(0, -42);
    var aim = supportAim(
      pivot,
      target.position,
      target.velocity,
      c.weapon(u.card.mount, 'speed', u.card.mount == 'carbine' ? 950 : 1100),
    );
    if (blocked(pivot, aim, u)) aim = target.position;
    final delta = aim - pivot;
    final desired = atan2(delta.dy, delta.dx);
    final error = atan2(sin(desired - u.heading), cos(desired - u.heading));
    u.heading += error.clamp(-c.turn * dt, c.turn * dt);
    u.heading = atan2(sin(u.heading), cos(u.heading));
    if (!legal(target) ||
        u.shot > 1e-8 ||
        (u.card.mount == 'burstRifle' && u.burst == 0 && u.burstWait > 1e-8) ||
        atan2(sin(desired - u.heading), cos(desired - u.heading)).abs() >
            pi / 30) {
      return;
    }
    // Finish the small firing alignment before releasing a straight round.
    u.heading = desired;
    final dir = Offset(cos(u.heading), sin(u.heading));
    final muzzle = supportMuzzle(
      pivot,
      dir,
      all.map((t) => (position: t.position, radius: t.radius)),
    );
    if (blocked(pivot, muzzle, u) || blocked(muzzle, aim, u)) return;
    final damage =
        c.weapon(
          u.card.mount,
          'damage',
          u.card.mount == 'carbine' ? .9 : 1.25,
        ) *
        c.multiplier(u.card.tier);
    if (!release(u, muzzle, dir, damage)) {
      u.shot = .05;
      return;
    }
    u.shotsFired++;
    u.recoil = .10;
    cue(u, 'fire');
    if (u.card.mount == 'burstRifle') {
      if (u.burst == 0) {
        u.burst = c.behavior('burstRifle', 'burstRounds', 3).toInt() - 1;
        u.burstWait = c.burstPeriod;
      } else {
        u.burst--;
      }
      u.shot = c.behavior('burstRifle', 'burstSpacing', .1);
    } else {
      u.shot = c.weapon(u.card.mount, 'cadence', .1);
    }
  }
}
