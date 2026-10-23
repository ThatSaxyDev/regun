import 'package:regun/presentation/boss_vfx.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/presentation/mummy_walk.dart';
import 'package:regun/presentation/burster_walk.dart';

import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/presentation/marshal_aim.dart';

import 'package:flame/components.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/regun_art.dart';

/// The server owns timing, committed geometry and damage. This adapter only
/// renders its snapshots using the same material/actor atlases as solo play.
class OnlineWorldArt {
  static ColorFilter ambient(bool foundry) =>
      BossArt.ambient(foundry ? ArenaType.foundry : ArenaType.breach);
  static Offset point(dynamic value) =>
      Offset((value['x'] as num).toDouble(), (value['y'] as num).toDouble());
  static void floor(
    Canvas canvas,
    OnlineEntity entity, {
    required bool foundry,
    required bool reducedMotion,
    BossKind? bossKind,
  }) {
    final vfx = bossKind == null
        ? null
        : BossVfx(
            kind: bossKind,
            ambient: ambient(foundry),
            reducedMotion: reducedMotion,
          );
    final p = Offset(entity.x, entity.y), d = entity.data;
    // Boss waves/lanes can enter view from well beyond their owner's position.
    // Their bounded primitives cull the actual footprint instead.
    if (bossKind == null &&
        !canvas.getLocalClipBounds().inflate(900).contains(p)) {
      return;
    }
    switch (entity.kind) {
      case 'hazard':
        final age = entity.number('age') - entity.number('delay');
        if (age < 0) return;
        final warning = age < entity.number('warning'),
            duration = warning
                ? entity.number('warning')
                : entity.number('duration');
        final progress =
            ((age - (warning ? 0 : entity.number('warning'))) /
                    math.max(.001, duration))
                .clamp(0.0, 1.0);
        final material =
            AttackMaterial.values
                .where((m) => m.name == d['material'])
                .firstOrNull ??
            AttackMaterial.stone;
        final points = (d['points'] as List).map(point).toList();
        final width = entity.number('width'), radius = entity.number('radius');
        switch (d['shape']) {
          case 'rays':
            for (final end in points.skip(1)) {
              (vfx?.ribbon ?? AttackVfx.ribbon)(
                canvas,
                points[0],
                end,
                width,
                warning: warning,
                progress: progress,
                material: material,
              );
            }
          case 'line':
          case 'trace':
            for (var i = 0; i < points.length - 1; i++) {
              if (d['material'] == 'lunge') {
                if (warning) {
                  AttackVfx.lungeWarning(
                    canvas,
                    points[i],
                    points[i + 1],
                    progress: progress,
                    ambient: ambient(foundry),
                  );
                }
              } else if (d['material'] == 'laser') {
                AttackVfx.laser(
                  canvas,
                  points[i],
                  points[i + 1],
                  width,
                  warning: warning,
                  progress: progress,
                  reducedMotion: reducedMotion,
                );
              } else {
                final spent =
                    d['shape'] == 'trace' &&
                    !warning &&
                    (i + 1) / (points.length - 1) < progress;
                (vfx?.ribbon ?? AttackVfx.ribbon)(
                  canvas,
                  points[i],
                  points[i + 1],
                  width,
                  warning: warning,
                  progress: progress,
                  material: material,
                  spent: spent,
                );
              }
            }
          case 'ring':
            final gap = entity.number('arc');
            (vfx?.wave ?? AttackVfx.wave)(
              canvas,
              p,
              warning ? radius : radius * progress,
              entity.number('angle') + gap / 2,
              math.pi * 2 - gap,
              warning: warning,
              progress: progress,
              material: material,
              width: width,
            );
          case 'sweep':
            if (warning) {
              (vfx?.fan ?? AttackVfx.fan)(
                canvas,
                p,
                radius,
                entity.number('angle'),
                entity.number('arc'),
                warning: true,
                progress: progress,
                material: material,
                innerRadius: entity.number('innerRadius'),
              );
            } else {
              final a =
                  entity.number('angle') + entity.number('arc') * progress;
              final inner = entity.number('innerRadius');
              (vfx?.ribbon ?? AttackVfx.ribbon)(
                canvas,
                p + Offset(math.cos(a), math.sin(a)) * inner,
                p + Offset(math.cos(a), math.sin(a)) * radius,
                width,
                warning: false,
                progress: progress,
                material: material,
              );
            }
          default:
            (vfx?.disk ?? AttackVfx.disk)(
              canvas,
              p,
              radius,
              ambient: ambient(foundry),
              warning: warning,
              progress: progress,
              material: material,
            );
        }
      case 'ground':
        AttackVfx.disk(
          canvas,
          p,
          90,
          ambient: ambient(foundry),
          warning: false,
          progress: (entity.number('age') / 2.5).clamp(0, 1),
          material: AttackMaterial.ember,
        );
      case 'effect':
        if ((d['material'] as String? ?? '').startsWith('bossVictory:')) return;
        final progress = (entity.number('age') / entity.number('duration', 1))
            .clamp(0.0, 1.0);
        if (d['material'] == 'upgradePulse') {
          AttackVfx.upgradePulse(
            canvas,
            p,
            entity.number('radius', 250),
            progress: progress,
            reducedMotion: reducedMotion,
          );
        } else if (d['material'] == 'chain' && d['end'] != null) {
          // Current server distinguishes drone links (.12s) from weapon chains
          // (.16s). Honor an explicit role too when newer snapshots supply it.
          if (d['role'] == 'companion' ||
              (entity.number('duration') - .12).abs() < 1e-6) {
            AttackVfx.companionLightning(
              canvas,
              p,
              point(d['end']),
              1 - progress,
            );
            return;
          }
          AttackVfx.lightning(
            canvas,
            p,
            point(d['end']),
            1 - progress,
            heavy: true,
          );
        } else {
          AttackVfx.explosion(
            canvas,
            p,
            entity.number('radius'),
            progress: progress,
            ambient: ambient(foundry),
            reducedMotion: reducedMotion,
          );
        }
      case 'pickup':
      case 'mine':
        RegunArt.shared
            .rawSprite(
              'items/items',
              entity.kind == 'pickup'
                  ? 0
                  : entity.number('age') >= .35
                  ? 5
                  : 4,
            )
            .render(
              canvas,
              position: Vector2(p.dx, p.dy),
              size: Vector2.all(entity.kind == 'pickup' ? 28 : 32),
              anchor: Anchor.center,
            );
      case 'supply':
        final phase = d['phase'], capture = entity.number('capture');
        final paint = Paint()
          ..color = const Color(0xffAD9162)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
        for (var i = 0; i < 24; i++) {
          final a = i * math.pi / 12;
          final v = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(
            p + v * 253,
            p + v * 260,
            paint
              ..color = i / 24 < capture / 8
                  ? const Color(0xffE4CE98)
                  : const Color(0xff756A4E),
          );
        }
        if (phase == 'warning') {
          AttackVfx.stamp(
            canvas,
            5,
            p,
            90,
            alpha: .6,
            grading: ambient(foundry),
          );
        }
    }
  }

  static void supplyBody(
    Canvas canvas,
    OnlineEntity entity, {
    required bool foundry,
    required bool reducedMotion,
  }) {
    final p = Offset(entity.x, entity.y), d = entity.data, phase = d['phase'];
    if (phase == 'warning' || !RegunArt.shared.contains('arenas/supply_pod')) {
      return;
    }
    final sprite = RegunArt.shared.rawSprite(
      'arenas/supply_pod',
      d['claimed'] == true ? 1 : 0,
    );
    final ref = RegunArt.shared.rawSprite('arenas/supply_pod', 0).srcSize.x;
    final fall = (entity.number('elapsed') / .65).clamp(0, 1);
    final height = phase == 'falling' && !reducedMotion
        ? 220 * (1 - fall * fall)
        : 0.0;
    sprite.render(
      canvas,
      position: Vector2(p.dx, p.dy - height),
      size: sprite.srcSize * (116 / ref),
      anchor: Anchor.bottomCenter,
      overridePaint: Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ambient(foundry)
        ..color = Color.fromRGBO(
          255,
          255,
          255,
          phase == 'breaking'
              ? (1 - entity.number('elapsed') / 1.3).clamp(0, 1)
              : 1,
        ),
    );
  }

  static void enemyFloor(
    Canvas canvas,
    OnlineEntity entity, {
    required bool foundry,
  }) {
    final p = Offset(entity.x, entity.y),
        size = entity.number('size', 85),
        boss = entity.data['boss'] == true;
    BossArt.contactShadow(
      canvas,
      p + Offset(0, size * .3),
      entity.number('radius', 30),
    );
    if (entity.number('spawning') > 0) {
      (boss ? BossVfx(ambient: ambient(foundry)).disk : AttackVfx.disk)(
        canvas,
        p,
        entity.number('radius', 30) + 12,
        ambient: ambient(foundry),
        warning: true,
        progress: 1 - entity.number('spawning') / .7,
        material: AttackMaterial.stone,
      );
    }
  }

  static void enemy(
    Canvas canvas,
    OnlineEntity entity, {
    required bool foundry,
    required bool reducedMotion,
    MummyWalk? mummyWalk,
    Offset? laserAim,
    Offset? laserOrigin,
  }) {
    final p = Offset(entity.x, entity.y),
        d = entity.data,
        size = entity.number('size', 85),
        kind = d['kind'] as String;
    if (!canvas.getLocalClipBounds().inflate(size).contains(p)) return;
    final boss = d['boss'] == true,
        name = '${boss ? 'bosses' : 'enemies'}/$kind',
        art = RegunArt.shared;
    if (!art.contains(name)) return;
    final dead = entity.number('health') <= 0,
        phase = entity.number('phase').toInt(),
        clock = entity.number('age');
    int frame;
    if (dead) {
      frame = boss
          ? 36 + (entity.number('deadAge') * 5).floor().clamp(0, 3)
          : 7;
    } else if (boss) {
      final bphase = d['bossPhase'];
      final pose = entity.number('pose').toInt() % 3;
      frame = bphase == 'warning'
          ? 8 + pose
          : bphase == 'active'
          ? 12 + pose * 8 + (entity.number('bossClock') * 12).floor() % 3
          : bphase == 'recovery'
          ? 0
          : (4 + (clock * 7).floor() % 4);
      if (kind == 'marshal' && bphase == 'active') frame = 10;
    } else {
      frame = phase == 1
          ? 5
          : phase == 2
          ? 6
          : (clock * (kind == 'nest' ? 6 : 12)).floor() % 4;
    }
    final aimedMarshal = !dead && kind == 'marshal' && laserAim != null;
    if (aimedMarshal) {
      MarshalAim.paint(
        canvas,
        p,
        laserAim,
        size,
        left: laserOrigin == null
            ? entity.number('dx', 1) < 0
            : MarshalAim.facingLeft(p, laserOrigin, laserAim, size),
        ambient: ambient(foundry),
      );
    }
    canvas.save();
    canvas.translate(p.dx, p.dy);
    final facingLeft =
        !dead && kind == 'mummy' && phase == 0 && mummyWalk != null
        ? mummyWalk.left
        : entity.number('dx', 1) < 0;
    if (kind != 'burster' && facingLeft) canvas.scale(-1, 1);
    final sprite = !dead && kind == 'mummy' && phase == 0
        ? art.sprite('enemies/mummy_walk', mummyWalk?.frame ?? 0)
        : !dead && kind == 'burster' && phase == 0
        ? art.sprite(
            'enemies/burster_walk',
            BursterWalk.frame(
              Offset(entity.number('dx', 1), entity.number('dy')),
              clock * 90,
            ),
          )
        : dead && kind == 'ranged'
        ? art.rawSprite('enemies/ranged_remains', 0)
        : art.sprite(name, frame);
    if (!aimedMarshal) {
      sprite.render(
        canvas,
        position: Vector2.zero(),
        size: dead && kind == 'ranged'
            ? Vector2(size, size * sprite.srcSize.y / sprite.srcSize.x)
            : Vector2.all(size),
        anchor: Anchor.center,
        overridePaint: Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = ambient(foundry)
          ..color = Color.fromRGBO(
            255,
            255,
            255,
            dead ? (1 - entity.number('deadAge') / .8).clamp(0, 1) : 1,
          ),
      );
    }
    canvas.restore();
    if (!dead &&
        (boss || entity.number('health') < entity.number('maximumHealth', 1))) {
      final width = boss ? 140.0 : 50.0;
      canvas.drawRect(
        Rect.fromLTWH(p.dx - width / 2, p.dy - size * .53, width, 5),
        Paint()..color = const Color(0xff392B30),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          p.dx - width / 2,
          p.dy - size * .53,
          width *
              (entity.number('health') / entity.number('maximumHealth', 1))
                  .clamp(0, 1),
          5,
        ),
        Paint()..color = const Color(0xffCB9775),
      );
    }
    for (final raw in d['weakPoints'] as List? ?? []) {
      if ((raw['health'] as num) <= 0) continue;
      final at = point(raw);
      AttackVfx.armour(canvas, at, 26, full: true);
    }
  }
}

/// Pending acquisitions retain their lease until completion, even on route exit.
/// This prevents disposal/re-entry races in the shared lazy atlas cache.
class OnlineArtLeases {
  OnlineArtLeases(this.changed);
  final void Function() changed;
  final Map<String, bool> _acquired = {};
  Set<String> _wanted = {};
  bool _disposed = false;
  void update(List<OnlineEntity> entities) {
    if (_disposed) return;
    _wanted = {
      'arenas/multiplayer_walls_hd',
      for (final e in entities)
        if (e.kind == 'enemy' &&
            [
              'bellkeeper',
              'magistrate',
              'saint',
              'sovereign',
              'marshal',
            ].contains(e.data['kind']))
          'bosses/${e.data['kind']}',
      if (entities.any((e) => e.kind == 'supply')) ...[
        'arenas/supply_pod',
        'effects/landing_dust',
      ],
    };
    for (final name in _acquired.keys.toList()) {
      if (!_wanted.contains(name) && _acquired[name] == true) {
        RegunArt.shared.release(name);
        _acquired.remove(name);
      }
    }
    for (final name in _wanted) {
      if (_acquired.containsKey(name)) continue;
      _acquired[name] = false;
      RegunArt.shared.acquire(name).then((_) {
        if (_disposed || !_wanted.contains(name)) {
          RegunArt.shared.release(name);
          _acquired.remove(name);
        } else {
          _acquired[name] = true;
          changed();
        }
      });
    }
  }

  void dispose() {
    _disposed = true;
    _wanted = {};
    for (final name in _acquired.keys.toList()) {
      if (_acquired[name] == true) {
        RegunArt.shared.release(name);
        _acquired.remove(name);
      }
    }
  }
}
