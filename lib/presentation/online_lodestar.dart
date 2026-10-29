import 'dart:ui';

import 'package:regun/data/loadout.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/presentation/lodestar_art.dart';
import 'package:regun/presentation/lodestar_battle_art.dart';
import 'package:regun/systems/lodestar/lodestar_combat.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/systems/target_shape.dart';

/// Snapshot-only presentation: never runs AI, flights, hit tests or health locally.
class OnlineLodestars {
  OnlineLodestars(this.changed);
  final void Function() changed;
  LodestarAssets? _assets;
  bool _disposed = false;
  String? _scope;
  final frames = <String, LodestarCombat>{};
  bool get ready => _assets?.ready == true;
  int get decodedBytes => _assets?.decodedBytes ?? 0;
  void sync(List<OnlineEntity> scene, {required String scope}) {
    if (_scope != scope) {
      frames.clear();
      _scope = scope;
    }
    final entities = scene
        .where((e) => e.kind == 'enemy' && e.data['kind'] == 'lodestar')
        .toList();
    final keys = entities.map((e) => e.key).toSet();
    frames.removeWhere((key, _) => !keys.contains(key));
    if (entities.isEmpty) {
      _assets?.dispose();
      _assets = null;
      return;
    }
    if (_assets == null && !_disposed) {
      final assets = _assets = LodestarAssets();
      assets
          .load(combat: true)
          .then((_) {
            if (_disposed || _assets != assets) {
              assets.dispose();
              return;
            }
            changed();
          })
          .catchError((Object _) {
            assets.dispose();
            if (_assets == assets) _assets = null;
          });
    }
    for (final entity in entities) {
      final raw = entity.data['lodestar'];
      if (raw is! Map) continue;
      try {
        final f = frames.putIfAbsent(
          entity.key,
          () => LodestarCombat(
            rig: LodestarRig(),
            bounds: const Rect.fromLTRB(-100000, -100000, 100000, 100000),
            clear: (_, __, ___) => true,
            poseLegal: (_) => true,
            hurt: (_, __) => false,
            signal: (_) {},
          ),
        );
        f.restore(raw);
        Offset p(dynamic v) =>
            Offset((v[0] as num).toDouble(), (v[1] as num).toDouble());
        for (final s in raw['shots'] as List? ?? []) {
          f.shots.add(
            LodestarShot(
                p(s['from']),
                p(s['target']),
                s['sequence'] as int,
                shell: s['shell'] == true,
                speed: (s['speed'] as num).toDouble(),
              )
              ..position = p(s['position'])
              ..age = (s['age'] as num).toDouble(),
          );
        }
        for (final m in raw['mines'] as List? ?? []) {
          f.mines.add(
            LodestarMine(p(m['from']), p(m['landing']), m['sequence'] as int)
              ..age = (m['age'] as num).toDouble()
              ..trigger = (m['trigger'] as num).toDouble(),
          );
        }
        for (final b in raw['bursts'] as List? ?? []) {
          f.bursts.add(
            LodestarBurst(
              p(b['position']),
              (b['radius'] as num).toDouble(),
              blast: b['blast'] == true,
            )..age = (b['age'] as num).toDouble(),
          );
        }
        for (final shape in raw['warnedSweep'] as List? ?? []) {
          f.warnedSweep.add(
            TargetCapsule(
              p(shape['a']),
              p(shape['b']),
              (shape['radius'] as num).toDouble(),
            ),
          );
        }
        f.hits.clear();
        for (final e in (raw['hits'] as Map? ?? {}).entries) {
          f.hits[LodestarSection.values.byName(e.key as String)] =
              (e.value as num).toDouble();
        }
        f.player = p(raw['aim']);
        f.restoreMortarRecoil(
          (raw['mortarAt'] as List).map((v) => (v as num).toDouble()).toList(),
        );
      } catch (_) {
        frames.remove(entity.key);
      }
    }
  }

  void floor(Canvas c, String key, ArenaType arena, bool reduced) {
    final a = _assets, f = frames[key];
    if (a?.ready == true && f != null) {
      LodestarBattleArt(a!).floor(c, f, arena, reduced);
    }
  }

  void body(Canvas c, String key, bool reduced) {
    final a = _assets, f = frames[key];
    if (a?.ready == true && f != null) {
      LodestarBattleArt(a!).body(c, f, reduced);
    }
  }

  void ordnance(Canvas c, ArenaType arena, bool reduced) {
    final a = _assets;
    if (a?.ready != true) return;
    for (final f in frames.values) {
      LodestarBattleArt(a!).ordnance(c, f, arena, reduced);
    }
  }

  void dispose() {
    _disposed = true;
    _assets?.dispose();
    _assets = null;
    frames.clear();
  }
}
