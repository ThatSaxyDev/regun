import 'dart:ui';

import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/sluice_art.dart';
import 'package:regun/systems/arena_machine.dart';

class ArenaMachineArt {
  static void floor(Canvas canvas, ArenaMachine machine, bool reducedMotion) {
    final area = machine.area;
    switch (machine.kind) {
      case ArenaMachineKind.press:
        final drop = machine.warning
            ? 4.0
            : machine.active
            ? 6.0
            : 0.0;
        final deck = area.deflate(5).translate(0, drop);
        final image = RegunArt.shared.image('arenas/foundry_floor');
        final metal = Paint()..filterQuality = FilterQuality.none;
        canvas.drawRect(area, Paint()..color = const Color(0xff171719));
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            image.width * .36,
            image.height * .23,
            image.width * .32,
            image.height * .24,
          ),
          deck,
          metal,
        );
        canvas.drawRect(
          Rect.fromLTRB(deck.left, deck.top, deck.right, deck.top + 3),
          metal..color = const Color(0xff766757),
        );
        for (final x in [deck.left + 8, deck.right - 8]) {
          for (final y in [deck.top + 7, deck.bottom - 7]) {
            canvas.drawRect(
              Rect.fromCenter(center: Offset(x, y), width: 5, height: 5),
              metal..color = const Color(0xffaaa090),
            );
          }
        }
        // Hazard paint is chipped in small clusters along the front edge.
        final stripe = Paint()
          ..color = machine.active || machine.warning
              ? const Color(0xffd69b50)
              : const Color(0xff83683f);
        for (var i = 0; i < 9; i++) {
          final x = deck.left + 7 + i * 14;
          final y = deck.bottom - 9;
          canvas.drawPath(
            Path()
              ..moveTo(x, y)
              ..lineTo(x + 8, y)
              ..lineTo(x + 13, y + 6)
              ..lineTo(x + 5, y + 6)
              ..close(),
            stripe,
          );
        }
        if (machine.warning || machine.active) {
          canvas.drawRect(
            deck,
            Paint()
              ..color = machine.active
                  ? const Color(0x41b67c40)
                  : const Color(0x33daa15c),
          );
        }
      case ArenaMachineKind.sluice:
        if (machine.warning ||
            machine.active ||
            machine.resetProgress < .14 && machine.resetting) {
          SluiceArt.machineFlow(
            canvas,
            area,
            warning: machine.warning,
            progress: machine.warning
                ? machine.warningProgress
                : machine.activeProgress,
            strength: machine.resetting ? 1 - machine.resetProgress / .14 : 1,
            reducedMotion: reducedMotion,
          );
        }
      case ArenaMachineKind.relay:
        final image = RegunArt.shared.image('arenas/relayGraveyard_floor');
        final w = image.width.toDouble(), h = image.height.toDouble();
        final paint = Paint()..filterQuality = FilterQuality.none;
        final cable = area.deflate(5);
        canvas.save();
        canvas.clipRect(area);
        canvas.drawRect(area, Paint()..color = const Color(0x8c191417));
        for (var y = area.top; y < area.bottom; y += 86) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(w * .23, h * .08, w * .105, h * .20),
            Rect.fromLTWH(cable.left, y, cable.width, 86),
            paint,
          );
        }
        final charged = machine.active
            ? 1.0
            : machine.warning
            ? machine.warningProgress
            : 0.0;
        if (charged > 0) {
          final end = reducedMotion
              ? area.bottom - 6
              : area.top + area.height * charged;
          final line = Rect.fromLTRB(
            area.center.dx - 10,
            area.top,
            area.center.dx + 10,
            end,
          );
          canvas.drawRect(line, paint..color = const Color(0x546ba79a));
          if (machine.active) {
            AttackVfx.lightning(
              canvas,
              area.topCenter.translate(0, 6),
              area.bottomCenter.translate(0, -6),
              .84,
              reducedMotion: reducedMotion,
            );
          } else {
            for (var y = area.top + 18; y < end; y += 29) {
              canvas.drawRect(
                Rect.fromLTWH(area.center.dx - 8, y, 5, 8),
                paint..color = const Color(0xff9ec3ae),
              );
            }
          }
        }
        canvas.restore();
    }
  }

  static void head(
    Canvas canvas,
    ArenaMachine machine,
    Offset shift,
    bool reducedMotion,
  ) {
    final body = machine.body.shift(shift);
    if (machine.kind == ArenaMachineKind.press) {
      final travel = machine.active
          ? 1.0
          : machine.resetting
          ? (1 - machine.resetProgress * 5).clamp(0.0, 1.0)
          : 0.0;
      if (travel > 0) {
        final image = RegunArt.shared.image('arenas/district_press');
        final w = image.width.toDouble(), h = image.height.toDouble();
        final area = machine.area.shift(shift);
        final end = body.bottom - 34 + (reducedMotion ? 54 : 75) * travel;
        final ram = Rect.fromLTRB(
          body.center.dx - 36,
          body.top + 12,
          body.center.dx + 36,
          end,
        );
        if (ram.height > 0) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(w * .38, h * .27, w * .24, h * .26),
            ram,
            Paint()..filterQuality = FilterQuality.none,
          );
        }
        final foot = Rect.fromCenter(
          center: Offset(area.center.dx, end),
          width: 126,
          height: 23,
        );
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(w * .25, h * .63, w * .49, h * .13),
          foot,
          Paint()..filterQuality = FilterQuality.none,
        );
      }
    }
    if (machine.kind == ArenaMachineKind.sluice &&
        (machine.warning || machine.active)) {
      final aperture = Rect.fromLTRB(
        body.left + body.width * .24,
        body.top + body.height * .54,
        body.right - body.width * .24,
        body.bottom,
      );
      final lift = machine.active ? 1.0 : machine.warningProgress * .45;
      final image = RegunArt.shared.image('arenas/district_sluice');
      final w = image.width.toDouble(), h = image.height.toDouble();
      canvas.save();
      canvas.clipRect(aperture);
      SluiceArt.channel(
        canvas,
        aperture,
        flowTime: reducedMotion ? 0 : lift * 12,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(w * .24, h * .58, w * .52, h * .28),
        aperture.translate(0, -lift * aperture.height * .75),
        Paint()..filterQuality = FilterQuality.none,
      );
      canvas.restore();
    }
    final energized = machine.warning || machine.active;
    final color = energized
        ? machine.kind == ArenaMachineKind.relay
              ? const Color(0xffabd4c4)
              : const Color(0xffedb363)
        : machine.ready
        ? const Color(0xff6d7958)
        : const Color(0xff544939);
    for (final side in [-1, 1]) {
      final lamp = Offset(
        body.center.dx + body.width * .34 * side,
        body.top + 18,
      );
      final lens = Rect.fromCenter(center: lamp, width: 11, height: 6);
      canvas.drawRect(
        lens.inflate(3),
        Paint()..color = const Color(0xff282725),
      );
      if (energized) {
        canvas.drawRect(
          lens.inflate(6),
          Paint()..color = color.withValues(alpha: .22),
        );
      }
      canvas.drawRect(lens, Paint()..color = color);
    }
  }
}
