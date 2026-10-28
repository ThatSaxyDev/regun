import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/components/enemies/boss_encounter.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/regun_art.dart';

class BossReveal {
  final actors = <PositionComponent>[];
  final cameraFrom = Vector2.zero();
  double elapsed = 0;
  bool reduced = false;
  bool get active => actors.isNotEmpty;
  double get duration => reduced ? .65 : 2.65;
  double get opacity => reduced ? 1 : ((elapsed - 1.05) / .65).clamp(0, 1);
  double get seal => (elapsed / (reduced ? .18 : .95)).clamp(0, 1);
  double get fade => ((duration - elapsed) / (reduced ? .2 : .6)).clamp(0, 1);
  void begin(
    PositionComponent actor,
    Vector2 camera, {
    required bool reducedMotion,
  }) {
    if (!active) {
      elapsed = 0;
      cameraFrom.setFrom(camera);
      reduced = reducedMotion;
    }
    actors.add(actor);
  }

  void reset() {
    actors.clear();
    elapsed = 0;
  }

  bool advance(double dt) {
    actors.removeWhere(
      (a) =>
          a.isRemoving ||
          a.isRemoved ||
          (a.isLoaded && (a as CombatEnemy).combatHealth.isDead),
    );
    if (!active) return true;
    if (actors.any((a) => !a.isLoaded || !a.isMounted)) return false;
    elapsed = math.min(duration, elapsed + dt);
    return elapsed >= duration;
  }

  Vector2 camera(Vector2 player, Vector2 target) {
    if (reduced) return player;
    double ease(double t) {
      t = t.clamp(0, 1);
      return t * t * (3 - 2 * t);
    }

    if (elapsed < .65) {
      return cameraFrom + (target - cameraFrom) * ease(elapsed / .65);
    }
    if (elapsed < 2.05) return target;
    return target + (player - target) * ease((elapsed - 2.05) / .6);
  }
}

/// Eight authored seal grammars share etched circular construction, not a copy
/// of Aura Salad's sixfold field. No collision, damage, lights or particle actors.
class BossPortalArt {
  static const colors = [
    Color(0xffb9a4c6),
    Color(0xffd29b79),
    Color(0xffb6ba83),
    Color(0xffc6bd91),
    Color(0xffb39c81),
    Color(0xffb4d0cd),
    Color(0xffcf9d65),
    Color(0xffb3bca1),
  ];
  static void paint(
    Canvas canvas,
    Offset at,
    BossKind kind,
    double open,
    double fade, {
    required bool reducedMotion,
    double time = 0,
  }) {
    if (open <= 0 || fade <= 0) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1, .52);
    final radius = kind.bodyRadius + 100;
    final r = radius * (reducedMotion ? 1 : .7 + .3 * open);
    if (kind == BossKind.walker) return;
    final c = colors[kind.index];
    final visibility = fade * open * open * (3 - 2 * open);
    void line(List<Offset> ps, {double width = 3, double alpha = 1}) {
      AttackVfx.stroke(
        canvas,
        ps,
        const Color(0xff17201c).withValues(alpha: visibility * alpha),
        width + 5,
      );
      AttackVfx.stroke(
        canvas,
        ps,
        c.withValues(alpha: visibility * alpha),
        width,
      );
    }

    Offset point(double a, double rad) =>
        Offset(math.cos(a) * rad, math.sin(a) * rad);
    // Two broken concentric engravings, with deliberately missing stone seams.
    final segments = 48 + kind.index * 2;
    for (var i = 0; i < segments; i++) {
      if (i % 6 == 5) continue;
      final a = i * math.pi * 2 / segments;
      final b = (i + .72) * math.pi * 2 / segments;
      final slab = Path()
        ..moveTo(point(a, r * .90).dx, point(a, r * .90).dy)
        ..lineTo(point(a, r).dx, point(a, r).dy)
        ..lineTo(point(b, r).dx, point(b, r).dy)
        ..lineTo(point(b, r * .90).dx, point(b, r * .90).dy)
        ..close();
      canvas.drawPath(
        slab,
        Paint()
          ..color = const Color(0xff27352d).withValues(alpha: visibility * .9),
      );
      canvas.drawPath(
        slab,
        Paint()..color = c.withValues(alpha: visibility * .18),
      );
      line([point(a, r * .93), point(b, r * .93)], width: 4, alpha: .9);
      line([point(a, r), point(b, r)], width: 2, alpha: .66);
      if (i.isEven) {
        line([point(a, r * .85), point(b, r * .85)], width: 2, alpha: .42);
      }
    }
    final sides = switch (kind) {
      BossKind.shadow => 5,
      BossKind.demon => 6,
      BossKind.queen => 8,
      BossKind.bellkeeper => 8,
      BossKind.magistrate => 7,
      BossKind.saint => 4,
      BossKind.walker => 4,
      BossKind.sovereign => 4,
      BossKind.marshal => 6,
    };
    final phase = reducedMotion ? 0.0 : (time * 4).floor() * .012;
    for (var i = 0; i < sides; i++) {
      final a = i * math.pi * 2 / sides - math.pi / 2;
      final p = point(a, r * .66),
          n = point(a + math.pi / 2, 1),
          d = point(a, 1);
      final next = point(a + math.pi * 2 / sides, r * .66);
      final anchor = point(a, r * 1.02);
      final plate = Path()
        ..moveTo((anchor - d * 10 - n * 10).dx, (anchor - d * 10 - n * 10).dy)
        ..lineTo((anchor + d * 12 - n * 7).dx, (anchor + d * 12 - n * 7).dy)
        ..lineTo((anchor + d * 12 + n * 7).dx, (anchor + d * 12 + n * 7).dy)
        ..lineTo((anchor - d * 10 + n * 10).dx, (anchor - d * 10 + n * 10).dy)
        ..close();
      canvas.drawPath(
        plate,
        Paint()..color = const Color(0xff1d2925).withValues(alpha: visibility),
      );
      line([anchor - d * 6, anchor + d * 7], width: 5, alpha: .86);
      line([anchor - n * 7, anchor + n * 7], width: 2, alpha: .65);

      line([p, Offset.lerp(p, next, .43)!], width: 2, alpha: .64);
      line([Offset.lerp(p, next, .58)!, next], width: 2, alpha: .64);
      switch (kind) {
        case BossKind.shadow:
          line([p - d * 18 - n * 6, p + n * 5, p + d * 15 - n * 8], alpha: .85);
        case BossKind.demon:
          line([p - n * 13 - d * 6, p + d * 18, p + n * 13 - d * 6], width: 4);
          line([p - d * 8, p + d * 9], width: 2);
        case BossKind.queen:
          line([
            p - n * 12 + d * 5,
            p - n * 5 - d * 11,
            p + d * 12,
            p + n * 9 - d * 2,
          ], width: 3);
        case BossKind.bellkeeper:
          line([
            p - n * 12 - d * 7,
            p - n * 9 + d * 9,
            p + n * 9 + d * 9,
            p + n * 12 - d * 7,
          ], width: 3);
          line([p, p + d * 17], width: 2);
        case BossKind.magistrate:
          line([
            p - d * 14,
            p - n * 8,
            p + d * 14,
            p + n * 8,
            p - d * 14,
          ], width: 3);
          line([p + d * 15, p + d * 28], width: 4);
        case BossKind.walker:
          break;
        case BossKind.saint:
          line([
            p - d * 28,
            p - n * 14,
            p + d * 28,
            p + n * 14,
            p - d * 28,
          ], width: 3);
          line([p - d * 15, p + d * 15 + n * 5], width: 2);
        case BossKind.sovereign:
          for (var j = -1; j <= 1; j++) {
            line([
              p + n * (j * 10) - d * 10,
              p + n * (j * 10) + d * 19,
            ], width: 4);
          }
        case BossKind.marshal:
          line([
            p - n * 11 - d * 10,
            p - n * 11 + d * 10,
            p + n * 11 + d * 10,
            p + n * 11 - d * 10,
            p - n * 11 - d * 10,
          ], width: 3);
          line([p - d * 17, p + d * 17], width: 2);
      }
      // Discrete inward induction strokes; the interior never becomes opaque.
      final q = reducedMotion ? .55 : ((time * .35 + i / sides + phase) % 1);
      final a0 = point(a, r * (.15 + q * .27));
      line([a0, a0 + n * 5 + d * 8, a0 + d * 17], width: 2, alpha: .5 * open);
    }
    canvas.restore();
  }
}

class BossPortalFloor extends Component with HasGameReference<RegunGame> {
  BossPortalFloor() : super(priority: -9);
  @override
  void render(Canvas canvas) {
    final reveal = game.bossReveal;
    for (final actor in reveal.actors) {
      final kind = (actor as BossEncounter).kind;
      BossPortalArt.paint(
        canvas,
        (actor.position + Vector2(0, actor.size.y * .35)).toOffset(),
        kind,
        reveal.seal,
        reveal.fade,
        reducedMotion: reveal.reduced,
        time: reveal.elapsed,
      );
    }
  }
}

/// The corpse leaves in world space. This component has no camera access.
/// An independent atlas lease outlives the defeated actor's .8s cleanup.
class BossDeparture extends PositionComponent with HasGameReference<RegunGame> {
  BossDeparture({required super.position, required this.kind})
    : super(priority: -9);
  final BossKind kind;
  double age = 0;
  bool _held = false, _retired = false;
  @override
  void onLoad() {
    // Cosmetic loading must not hold the world's lifecycle queue or prevent the
    // defeated actor from retiring. Late/failed packets leave a portal-only fade.
    unawaited(_loadArt().catchError((Object _) {}));
  }

  Future<void> _loadArt() async {
    final owner = game;
    final world = owner.world;
    await RegunArt.shared.acquire('bosses/${kind.name}');
    if (_retired ||
        isRemoving ||
        isRemoved ||
        owner.disposed ||
        owner.world != world) {
      RegunArt.shared.release('bosses/${kind.name}');
      return;
    }
    _held = true;
  }

  void releaseArt() {
    _retired = true;
    if (_held) {
      RegunArt.shared.release('bosses/${kind.name}');
      _held = false;
    }
  }

  @override
  void onRemove() {
    releaseArt();
    super.onRemove();
  }

  @override
  void update(double dt) {
    if (game.gameState.gameplayState.name != 'playing') return;
    age += dt;
    if (age >= 1.55) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final reduced = game.preferences.reducedMotion;
    final open = (age / .35).clamp(0.0, 1.0),
        fade = ((1.55 - age) / .45).clamp(0.0, 1.0);
    final t = ((age - .3) / .85).clamp(0.0, 1.0);
    if (_held) {
      canvas.save();
      canvas.translate(0, -kind.spriteSize * .38 + (reduced ? 0 : t * 40));
      if (!reduced) canvas.scale(1 - t * .18, 1 - t * .65);
      RegunArt.shared
          .sprite('bosses/${kind.name}', 39)
          .render(
            canvas,
            size: Vector2.all(kind.spriteSize),
            anchor: Anchor.center,
            overridePaint: Paint()
              ..colorFilter = BossArt.ambient(game.loadout.arena)
              ..color = Color.fromRGBO(255, 255, 255, 1 - t),
          );
      canvas.restore();
    }
    // Draw the aperture lip over the sinking corpse, grounded to its death spot.
    BossPortalArt.paint(
      canvas,
      Offset.zero,
      kind,
      open,
      fade,
      reducedMotion: reduced,
      time: age,
    );
  }
}
