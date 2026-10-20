import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/multiplayer/geometry.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/online_player_label.dart';
import 'package:regun/widgets/click_button.dart';

/// Deliberately separate from RegunGame: no local director, health, checkpoint,
/// profile rewards or combat may run while the authoritative port is incomplete.
class OnlineArena extends StatefulWidget {
  const OnlineArena({super.key, required this.session});
  final OnlineSession session;
  @override
  State<OnlineArena> createState() => _OnlineArenaState();
}

class _OnlineArenaState extends State<OnlineArena>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  final Map<int, String> pointers = {};
  final Map<String, Offset> origins = {}, knobs = {}, displayed = {};
  final Set<LogicalKeyboardKey> keys = {};
  bool artReady = false;
  double seconds = 0;
  Duration last = Duration.zero;
  OnlineSession get session => widget.session;
  @override
  void initState() {
    super.initState();
    RegunArt.shared.load().then((_) {
      if (mounted) setState(() => artReady = true);
    });
    ticker = createTicker((elapsed) {
      final dt = ((elapsed - last).inMicroseconds / 1000000).clamp(0.0, .1);
      last = elapsed;
      seconds += dt;
      for (final member in session.members) {
        final id = member.identity.toHexString;
        final target = Offset(member.x, member.y);
        final old = displayed[id] ?? target;
        // Small display-only interpolation; simulation coordinates stay server-owned.
        displayed[id] = (target - old).distance > 300
            ? target
            : Offset.lerp(old, target, 1 - math.exp(-18 * dt))!;
      }
      displayed.removeWhere(
        (id, _) => !session.members.any((m) => m.identity.toHexString == id),
      );
      if (mounted) setState(() {});
    })..start();
  }

  void clear() {
    pointers.clear();
    origins.clear();
    knobs.clear();
    keys.clear();
    session.neutral();
  }

  @override
  void dispose() {
    ticker.dispose();
    clear();
    super.dispose();
  }

  void keyboard() {
    session.moveX =
        (keys.contains(LogicalKeyboardKey.keyD) ||
                keys.contains(LogicalKeyboardKey.arrowRight)
            ? 1
            : 0) -
        (keys.contains(LogicalKeyboardKey.keyA) ||
                    keys.contains(LogicalKeyboardKey.arrowLeft)
                ? 1
                : 0)
            .toDouble();
    session.moveY =
        (keys.contains(LogicalKeyboardKey.keyS) ||
                keys.contains(LogicalKeyboardKey.arrowDown)
            ? 1
            : 0) -
        (keys.contains(LogicalKeyboardKey.keyW) ||
                    keys.contains(LogicalKeyboardKey.arrowUp)
                ? 1
                : 0)
            .toDouble();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff161B18),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          final controls = LocalPreferences.shared.controls;
          final geometry = controls.geometry(size);
          final centers = {'move': geometry.movement, 'aim': geometry.aim};
          final radius = controls.size / 2;
          void update(PointerEvent event) {
            final id = pointers[event.pointer];
            if (id == null || id == 'dash') return;
            var delta =
                (event.localPosition - origins[id]!) /
                radius *
                controls.sensitivity;
            if (delta.distance > 1) delta = delta / delta.distance;
            if (delta.distance < controls.deadZone) delta = Offset.zero;
            knobs[id] = delta;
            if (id == 'move') {
              session.moveX = delta.dx;
              session.moveY = delta.dy;
            } else if (delta != Offset.zero) {
              session.aimX = delta.dx / delta.distance;
              session.aimY = delta.dy / delta.distance;
            }
          }

          void release(PointerEvent event) {
            final id = pointers.remove(event.pointer);
            if (id == 'move') session.neutral();
            if (id != null) {
              knobs.remove(id);
              origins.remove(id);
            }
          }

          return Focus(
            autofocus: true,
            onFocusChange: (focused) {
              if (!focused) clear();
            },
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) {
                keys.add(event.logicalKey);
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  session.dash();
                }
              } else if (event is KeyUpEvent) {
                keys.remove(event.logicalKey);
              }
              keyboard();
              return KeyEventResult.handled;
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerDown: (event) {
                      if (!session.connected) return;
                      final p = event.localPosition;
                      if ((p - geometry.dash).distance <
                          controls.buttonSize / 2) {
                        pointers[event.pointer] = 'dash';
                        session.dash();
                        return;
                      }
                      for (final id in ['move', 'aim']) {
                        if (pointers.containsValue(id)) continue;
                        final matchesSide =
                            (p.dx < size.width / 2) ==
                            (centers[id]!.dx < size.width / 2);
                        if ((p - centers[id]!).distance <= radius ||
                            (controls.floating && matchesSide && p.dy > 100)) {
                          pointers[event.pointer] = id;
                          origins[id] = controls.floating ? p : centers[id]!;
                          update(event);
                          break;
                        }
                      }
                    },
                    onPointerMove: update,
                    onPointerUp: release,
                    onPointerCancel: release,
                    child: CustomPaint(
                      painter: _ArenaPainter(
                        session: session,
                        positions: displayed,
                        seconds: seconds,
                        artReady: artReady,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 8,
                  child: IgnorePointer(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 5,
                      children: [
                        for (final member in session.members)
                          SizedBox(
                            width: (size.width - 48) / 3,
                            child: OnlinePlayerLabel(
                              compact: true,
                              member: member,
                              age: session.pingAge(member),
                              online: session.connected,
                              suffix:
                                  member.identity.toHexString ==
                                      session.identity
                                  ? ' | You'
                                  : '',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: (size.width - 116) / 2,
                  bottom: 12,
                  child: SizedBox(
                    width: 116,
                    child: ClickButton(
                      text: 'Leave',
                      height: 44,
                      fontSize: 11,
                      onTap: session.connected && !session.busy
                          ? () {
                              clear();
                              unawaited(session.leave());
                            }
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  top:
                      14 +
                      ((session.members.length / 3).ceil() *
                          32 *
                          MediaQuery.textScalerOf(context).scale(12) /
                          12),
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Text(
                      !session.compatible
                          ? session.error
                          : session.connected
                          ? 'MOVEMENT TEST | No combat | WASD / sticks | Space / Dash'
                          : '${session.status} | Movement paused',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: FontFam.orbitron,
                        color: Color(0xffE5DDD1),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                for (final id in ['move', 'aim'])
                  Positioned(
                    left: (origins[id] ?? centers[id]!).dx - radius,
                    top: (origins[id] ?? centers[id]!).dy - radius,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: controls.opacity,
                        child: Container(
                          width: radius * 2,
                          height: radius * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x77302332),
                            border: Border.all(
                              color: const Color(0xffAD9162),
                              width: 2,
                            ),
                          ),
                          child: Transform.translate(
                            offset: (knobs[id] ?? Offset.zero) * radius * .55,
                            child: Center(
                              child: Container(
                                width: radius * .55,
                                height: radius * .55,
                                decoration: const BoxDecoration(
                                  color: Color(0xffAD9162),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: geometry.dash.dx - controls.buttonSize / 2,
                  top: geometry.dash.dy - controls.buttonSize / 2,
                  child: IgnorePointer(
                    child: Container(
                      width: controls.buttonSize,
                      height: controls.buttonSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xcc302332),
                        border: Border.all(
                          color: const Color(0xffAD9162),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        (session.me?.cooldown ?? 0) > 0 ? '…' : 'DASH',
                        style: const TextStyle(
                          fontFamily: FontFam.orbitron,
                          color: Color(0xffE5DDD1),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!session.connected)
                  Center(
                    child: SizedBox(
                      width: 240,
                      child: ClickButton(
                        text: 'Retry connection',
                        onTap: () => unawaited(session.connect()),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _ArenaPainter extends CustomPainter {
  _ArenaPainter({
    required this.session,
    required this.positions,
    required this.seconds,
    required this.artReady,
  });
  final OnlineSession session;
  final Map<String, Offset> positions;
  final double seconds;
  final bool artReady;
  @override
  void paint(Canvas canvas, Size size) {
    final mine = session.me;
    final center =
        positions[session.identity] ?? Offset(mine?.x ?? 0, mine?.y ?? 0);
    final scale = math.min(size.width / 1500, size.height / 700);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    final geometry =
        onlineGeometry[session.room?.mapId] ?? onlineGeometry['network_lab']!;
    Rect rectOf(List<num> r) => Rect.fromLTRB(
      r[0].toDouble(),
      r[1].toDouble(),
      r[2].toDouble(),
      r[3].toDouble(),
    );
    final bounds = rectOf(geometry['bounds'] as List<num>);
    double cameraAxis(double value, double lo, double hi, double half) =>
        hi - lo <= half * 2
        ? (lo + hi) / 2
        : value.clamp(lo + half, hi - half).toDouble();
    canvas.translate(
      -cameraAxis(center.dx, bounds.left, bounds.right, size.width / scale / 2),
      -cameraAxis(
        center.dy,
        bounds.top,
        bounds.bottom,
        size.height / scale / 2,
      ),
    );

    canvas.drawRect(bounds, Paint()..color = const Color(0xff252B25));
    if (artReady) {
      final image = RegunArt.shared.image(
        session.room?.mapId == 'foundry'
            ? 'arenas/foundry_floor'
            : 'arenas/breach_floor',
      );
      final transform = Matrix4.diagonal3Values(
        768 / image.width,
        768 / image.height,
        1,
      );
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = ui.ImageShader(
            image,
            ui.TileMode.repeated,
            ui.TileMode.repeated,
            transform.storage,
          )
          ..filterQuality = FilterQuality.none
          ..colorFilter = const ColorFilter.mode(
            Color(0xff6B7770),
            BlendMode.modulate,
          ),
      );
    }
    canvas.drawRect(
      bounds.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xff8E7959),
    );
    for (final raw in geometry['obstacles'] as List) {
      final rect = rectOf(raw as List<num>);
      canvas.drawOval(
        Rect.fromCenter(
          center: rect.bottomCenter + const Offset(8, -10),
          width: rect.width + 20,
          height: rect.height * .65,
        ),
        Paint()..color = const Color(0x750A1114),
      );
      if (artReady) {
        final sprite = RegunArt.shared.rawSprite('arenas/props', 4);
        final width = rect.width * 1.25;
        final height = width * sprite.srcSize.y / sprite.srcSize.x;
        sprite.render(
          canvas,
          position: Vector2(rect.center.dx - width / 2, rect.bottom - height),
          size: Vector2(width, height),
          overridePaint: Paint()..color = const Color(0x99FFFFFF),
        );
      }
    }
    final sorted = session.members.toList()..sort((a, b) => a.y.compareTo(b.y));
    for (final member in sorted) {
      final p =
          positions[member.identity.toHexString] ?? Offset(member.x, member.y);
      final color = member.team == 0
          ? const Color(0xffA9C990)
          : const Color(0xffD7A3B7);
      canvas.drawOval(
        Rect.fromCenter(center: p + const Offset(0, 22), width: 65, height: 22),
        Paint()..color = const Color(0x77000000),
      );
      canvas.drawCircle(
        p,
        34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color,
      );
      if (artReady) {
        final moving = member.moveX != 0 || member.moveY != 0;
        final frame = moving ? (seconds * 12).floor() % 8 : 0;
        final facing = member.aimX.abs() > member.aimY.abs()
            ? (member.aimX < 0 ? 2 : 0)
            : (member.aimY > 0 ? 1 : 3);
        RegunArt.shared
            .sprite(
              moving ? 'characters/rook_run' : 'characters/rook',
              facing * 8 + frame,
            )
            .render(
              canvas,
              position: Vector2(p.dx, p.dy),
              size: Vector2.all(100),
              anchor: Anchor.center,
            );
      }
      final text = TextPainter(
        text: TextSpan(
          text: member.name,
          style: TextStyle(
            fontFamily: FontFam.orbitron,
            color: color,
            fontSize: 18,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, p + Offset(-text.width / 2, -65));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}
