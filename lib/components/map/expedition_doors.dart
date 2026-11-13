import 'package:regun/systems/expedition_signature.dart';

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/systems/expedition.dart';
import 'package:regun/utils/constants.dart';

/// Wall-mounted doors. The floor trigger is active only after the panels open.
class ExpeditionDoors extends Component with HasGameReference<RegunGame> {
  ExpeditionDoors() : super(priority: -55);
  final _signs = <(String, Color), TextPainter>{};

  @override
  void update(double dt) {
    final run = game.expedition!;
    if (run.phase != ExpeditionPhase.exit ||
        game.expeditionSaving ||
        game.expeditionCommitFailed ||
        game.gameState.gameplayState != GameplayState.playing) {
      return;
    }
    game.expeditionDoorProgress = game.preferences.reducedMotion
        ? 1
        : math.min(1, game.expeditionDoorProgress + dt / .44);
  }

  @override
  void onRemove() {
    for (final sign in _signs.values) {
      sign.dispose();
    }
    _signs.clear();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final run = game.expedition!;
    final room = game.expeditionRoom!;
    _paintEntrance(canvas, room);
    if (run.bossRoom && run.finalRegion) return;
    final open =
        run.phase == ExpeditionPhase.exit &&
        !game.expeditionSaving &&
        !game.expeditionCommitFailed;
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < room.doors.length; i++) {
      final gate = room.wallDoor(i);
      final family = open && run.exits.isNotEmpty ? run.exits[i] : null;
      final progress = game.expeditionDoorProgress;
      final eased = Curves.easeInOutCubic.transform(progress);
      final ready = open && progress >= 1;
      final signal = ready
          ? Color(family?.color ?? 0xffd8b17a)
          : Color.lerp(
              const Color(0xffff503c),
              const Color(0xffd8b17a),
              eased,
            )!;
      void plate(Rect rect, Color color) {
        canvas.drawRect(rect, paint..color = color);
      }

      // Recess and panels stay within the north wall strip.
      plate(gate.inflate(6), const Color(0xff534c40));
      plate(gate, const Color(0xff141915));
      canvas.save();
      canvas.clipRect(gate);
      final half = gate.width / 2;
      for (final side in [-1.0, 1.0]) {
        final panel = Rect.fromCenter(
          center: gate.center.translate(side * (half / 2 + eased * half), 0),
          width: half,
          height: gate.height,
        );
        plate(panel.deflate(1), const Color(0xff454a42));
        for (var row = 1; row < 3; row++) {
          plate(
            Rect.fromLTWH(panel.left + 3, panel.top + row * 7, half - 6, 3),
            const Color(0xff6a6f60),
          );
        }
      }
      canvas.restore();
      if (eased > 0) {
        final trim = signal.withValues(alpha: .8 * eased);
        for (final x in [gate.left - 3, gate.right]) {
          plate(Rect.fromLTWH(x, gate.top + 3, 3, gate.height - 6), trim);
        }
      }
      final lamp = gate.center.translate(0, -19);
      canvas.drawCircle(
        lamp,
        12,
        paint..color = signal.withValues(alpha: .15 + eased * .14),
      );
      canvas.drawCircle(lamp, 5, paint..color = signal);
      if (!ready) continue;
      final nextBoss = run.bossRoom
          ? ExpeditionRegion.values[run.region.index + 1].arena.title
          : run.boss.title;
      final signature = family?.signature;
      final signatureName =
          signature != null &&
              run.generator >= 3 &&
              (run.generator >= 9 ||
                  ExpeditionSignature.legacy.contains(signature)) &&
              (run.signatures[signature] ?? 0) < 3
          ? signature.title.toUpperCase()
          : null;
      final title = signatureName ?? family?.label ?? nextBoss.toUpperCase();
      final label = _signs.putIfAbsent(
        (title, signal),
        () => TextPainter(
          text: TextSpan(
            text: title,
            style: TextStyle(
              color: signal,
              fontSize: signatureName == null ? 16 : 12,
              fontFamily: FontFam.pressStart,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      final sign = Offset(gate.center.dx - label.width / 2, gate.bottom + 16);
      plate((sign & label.size).inflate(6), const Color(0xe81a1a17));
      label.paint(canvas, sign);
    }
  }

  void _paintEntrance(Canvas canvas, ExpeditionRoom room) {
    final bottom = room.bounds.bottom - 32;
    final portal = Rect.fromCenter(
      center: Offset(room.entrance.dx, bottom - 44),
      width: 180,
      height: 88,
    );
    final paint = Paint()..isAntiAlias = false;
    canvas.drawRect(portal.inflate(10), paint..color = const Color(0xff252822));
    canvas.drawRect(portal, paint..color = const Color(0xff131915));
    final shutter = Rect.fromLTWH(
      portal.left + 10,
      bottom - 43,
      portal.width - 20,
      30,
    );
    if (!game.crossingExpedition) {
      canvas.drawRect(shutter, paint..color = const Color(0xff51564a));
    }
    for (var i = 1; i < 4 && !game.crossingExpedition; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          shutter.left + 8,
          shutter.top + i * 7,
          shutter.width - 16,
          3,
        ),
        paint..color = const Color(0xff262b24),
      );
    }
    for (final x in [portal.left + 8, portal.right - 16]) {
      canvas.drawRect(
        Rect.fromLTWH(x, portal.top + 8, 8, 12),
        paint..color = const Color(0xffd2ad71),
      );
    }
  }
}
