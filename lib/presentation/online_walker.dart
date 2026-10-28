import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/data/loadout.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/presentation/walker_battle_art.dart';
import 'package:regun/systems/walker_combat.dart';
import 'package:regun/systems/walker_rig.dart';

/// Server snapshots own AI, hits and phase transitions. This cache only smooths
/// the supplied rig and releases route-owned art; it never advances combat.
class OnlineWalkers {
  OnlineWalkers(this.changed);
  final void Function() changed;
  WalkerAssets? _assets;
  bool _loading = false, _disposed = false;
  String? _scope;
  bool get ready => _assets?.ready == true;
  int get decodedBytes => _assets?.decodedBytes ?? 0;
  final frames = <String, WalkerCombat>{};

  void sync(
    List<OnlineEntity> scene,
    double dt, {
    required bool active,
    String scope = '',
  }) {
    if (_scope != scope) {
      frames.clear();
      _scope = scope;
    }
    final entities = scene
        .where((e) => e.kind == 'enemy' && e.data['kind'] == 'walker')
        .toList();
    final keys = entities.map((e) => e.key).toSet();
    frames.removeWhere((key, _) => !keys.contains(key));
    if (entities.isEmpty) {
      _assets?.dispose();
      _assets = null;
      return;
    }
    if (_assets == null && !_loading && !_disposed) {
      final art = _assets = WalkerAssets();
      _loading = true;
      art
          .load(combat: true)
          .then((_) {
            _loading = false;
            if (_disposed || _assets != art) {
              art.dispose();
              return;
            }
            changed();
          })
          .catchError((Object _) {
            _loading = false;
            art.dispose();
            if (_assets == art) _assets = null;
          });
    }
    for (final e in entities) {
      final raw = e.data['walker'];
      if (raw is! Map) continue;
      final fight = frames.putIfAbsent(
        e.key,
        () => WalkerCombat(
          rig: WalkerRig(barrelLength: 158),
          clear: (_, _, _) => true,
          hurt: (_, _) {},
          signal: (_) {},
        ),
      );
      final previous = fight.rig.toJson();
      final initialized = fight.elapsed > 0;
      try {
        fight.restore(Map<String, dynamic>.from(raw));
      } catch (_) {
        frames.remove(e.key);
        continue;
      }
      if (active && initialized && dt > 0 && dt < .1) {
        final blend = 1 - math.exp(-dt * 24), r = fight.rig;
        Offset point(dynamic p) =>
            Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
        r.position = Offset.lerp(
          point(previous['position']),
          r.position,
          blend,
        )!;
        r.yaw =
            (previous['yaw'] as double) +
            WalkerRig.difference(r.yaw, previous['yaw'] as double) * blend;
        for (var i = 0; i < 4; i++) {
          final old = previous['legs'][i], leg = r.legs[i];
          leg.foot = Offset.lerp(point(old['foot']), leg.foot, blend)!;
          leg.lift =
              (old['lift'] as double) +
              (leg.lift - (old['lift'] as double)) * blend;
        }
      }
      if (raw['landingTarget'] case final List target) {
        fight.presentationLanding = Offset(
          (target[0] as num).toDouble(),
          (target[1] as num).toDouble(),
        );
      } else {
        fight.presentationLanding = null;
      }
    }
  }

  void floor(Canvas canvas, String key, ArenaType arena, bool reduced) {
    final a = _assets, f = frames[key];
    if (a?.ready == true && f != null) {
      WalkerBattleArt(a!).floor(canvas, f, arena, reduced);
    }
  }

  void body(Canvas canvas, String key, bool reduced) {
    final a = _assets, f = frames[key];
    if (a?.ready == true && f != null) {
      WalkerBattleArt(a!).body(canvas, f, reduced: reduced);
    }
  }

  void ordnance(Canvas canvas, ArenaType arena, bool reduced) {
    final a = _assets;
    if (a?.ready != true) return;
    for (final fight in frames.values) {
      WalkerBattleArt(a!).ordnance(canvas, fight, arena, reduced);
    }
  }

  void dispose() {
    _disposed = true;
    _assets?.dispose();
    _assets = null;
    frames.clear();
  }
}
