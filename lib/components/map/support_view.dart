import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/support_art.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/boss_art.dart';

class SupportFieldView extends PositionComponent
    with HasGameReference<RegunGame> {
  SupportFieldView() : super(priority: -19);
  final held = <String>{};
  final pending = <String>{};
  bool released = false;
  @override
  void update(double dt) {
    super.update(dt);
    final wanted =
        game.gameNotifier.support.busy.isNotEmpty ||
        game.gameNotifier.support.offer != null;
    for (final name in SupportArt.atlases) {
      if (wanted && !held.contains(name) && !pending.contains(name)) {
        pending.add(name);
        RegunArt.shared
            .acquire(name)
            .then((_) {
              pending.remove(name);
              if (released ||
                  game.gameNotifier.support.busy.isEmpty &&
                      game.gameNotifier.support.offer == null) {
                RegunArt.shared.release(name);
              } else {
                held.add(name);
              }
            })
            .catchError((Object error) {
              pending.remove(name);
              game.saveIssue = 'Support artwork could not load';
            });
      }
      if (!wanted && held.remove(name)) RegunArt.shared.release(name);
    }
  }

  @override
  void render(Canvas canvas) {
    for (final u in game.supportCombat.runtime.units) {
      if (game.camera.visibleWorldRect.inflate(300).contains(u.position)) {
        SupportArt.floor(
          canvas,
          u,
          game.supportCombat.config,
          ambient: BossArt.ambient(game.loadout.arena),
          reducedMotion: game.preferences.reducedMotion,
        );
      }
    }
  }

  @override
  void onRemove() {
    released = true;
    for (final n in held) {
      RegunArt.shared.release(n);
    }
    held.clear();
    super.onRemove();
  }
}

class SupportBodyView extends PositionComponent
    with HasGameReference<RegunGame> {
  final actors = <int, SupportActorView>{};
  @override
  void update(double dt) {
    super.update(dt);
    final units = game.supportCombat.runtime.units;
    for (final id in actors.keys.toList()) {
      if (!units.any((u) => u.serial == id)) {
        actors.remove(id)!.removeFromParent();
      }
    }
    for (final u in units) {
      if (!actors.containsKey(u.serial)) {
        final actor = SupportActorView(u.serial);
        actors[u.serial] = actor;
        game.world.add(actor);
      }
    }
  }

  @override
  void onRemove() {
    for (final actor in actors.values) {
      actor.removeFromParent();
    }
    actors.clear();
    super.onRemove();
  }
}

class SupportActorView extends PositionComponent
    with HasGameReference<RegunGame> {
  SupportActorView(this.serial);
  final int serial;
  @override
  void update(double dt) {
    super.update(dt);
    final unit = game.supportCombat.runtime.units
        .where((u) => u.serial == serial)
        .firstOrNull;
    if (unit == null) {
      removeFromParent();
      return;
    }
    priority = 10000 + unit.position.dy.round();
  }

  @override
  void render(Canvas canvas) {
    final unit = game.supportCombat.runtime.units
        .where((u) => u.serial == serial)
        .firstOrNull;
    if (unit == null ||
        !game.camera.visibleWorldRect.inflate(350).contains(unit.position)) {
      return;
    }
    SupportArt.body(
      canvas,
      unit,
      game.supportCombat.config,
      ambient: BossArt.ambient(game.loadout.arena),
      reducedMotion: game.preferences.reducedMotion,
    );
  }
}

class SupportRoundsView extends PositionComponent
    with HasGameReference<RegunGame> {
  SupportRoundsView() : super(priority: 20000);
  @override
  void render(Canvas canvas) {
    for (final trace in game.supportCombat.traces) {
      if (game.camera.visibleWorldRect.inflate(40).contains(trace.to)) {
        SupportArt.trace(canvas, trace);
      }
    }
    for (final r in game.supportCombat.runtime.rounds) {
      if (game.camera.visibleWorldRect.inflate(40).contains(r.position)) {
        SupportArt.round(canvas, r);
      }
    }
  }
}

class SupportStatusHud extends PositionComponent
    with HasGameReference<RegunGame> {
  SupportStatusHud() : super(priority: 90001);
  @override
  void render(Canvas canvas) {
    final runtime = game.supportCombat.runtime,
        progress = game.gameNotifier.support;
    final labels = <String>[];
    for (final card in progress.pending) {
      labels.add('${card.family.name.toUpperCase()} PREPARING');
    }
    for (final u in runtime.units) {
      final family = u.card.family.name.toUpperCase();
      final life = u.card.family.name == 'sentry'
          ? game.supportCombat.config.sentryLife(u.card.tier)
          : game.supportCombat.config.auraLife(u.card.tier);
      labels.add(
        '$family ${u.phase == 'active' ? '${(life - u.life).ceil()}s' : u.phase.toUpperCase()}',
      );
    }
    if (labels.isEmpty) return;
    final viewport = game.camera.viewport.virtualSize;
    SupportArt.label(
      canvas,
      Offset(viewport.x / 2, viewport.y - 35),
      labels.join('   /   '),
    );
  }
}
