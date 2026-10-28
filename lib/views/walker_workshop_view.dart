import 'package:regun/data/loadout.dart';

import 'dart:math' as math;

import 'package:flame/components.dart' show Anchor, Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/systems/walker_rig.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

enum WalkerDemo { walk, strafe, turn, stand, brace }

class WalkerWorkshopController extends ChangeNotifier {
  final rig = WalkerRig();
  WalkerDemo mode = WalkerDemo.walk;
  bool paused = false, foundry = false, joints = false;
  bool autoTarget = true, inspect = false;
  Offset? destination;
  double clock = 0;
  void choose(WalkerDemo value) {
    mode = value;
    destination = null;
    notifyListeners();
  }

  void walkTo(Offset point) {
    destination = Offset(point.dx.clamp(-480, 480), point.dy.clamp(-100, 100));
    mode = WalkerDemo.walk;
    notifyListeners();
  }

  void aimAt(Offset point) {
    autoTarget = false;
    rig.target = Offset(point.dx.clamp(-630, 630), point.dy.clamp(-230, 230));
    notifyListeners();
  }

  void resumeAutoAim() {
    autoTarget = true;
    notifyListeners();
  }

  void toggleFloor() {
    foundry = !foundry;
    notifyListeners();
  }

  void toggleJoints() {
    joints = !joints;
    notifyListeners();
  }

  double viewScale(Size size) =>
      math.min(size.width / 1500, size.height / 700) * (inspect ? 1.65 : 1);
  Offset viewOrigin(Size size) =>
      Offset(size.width / 2, size.height / 2) -
      (inspect ? rig.position * viewScale(size) : Offset.zero);
  Offset worldPoint(Offset at, Size size) =>
      (at - viewOrigin(size)) / viewScale(size);

  void advance(double dt) {
    if (paused) return;
    clock += dt;
    final goal =
        destination ??
        Offset(math.sin(clock * .45) * 245, math.sin(clock * .9) * 66);
    rig.command = (mode == WalkerDemo.walk || mode == WalkerDemo.strafe)
        ? WalkerRig.limit((goal - rig.position) * 1.8, 120)
        : Offset.zero;
    if (mode == WalkerDemo.turn) {
      rig.desiredYaw = clock * .5;
    } else if (mode == WalkerDemo.walk && rig.command.distance > 3) {
      rig.desiredYaw = math.atan2(rig.command.dy, rig.command.dx);
    } else if (mode == WalkerDemo.strafe) {
      rig.desiredYaw = 0;
    }
    rig.braced = mode == WalkerDemo.brace;
    if (autoTarget) {
      rig.target = Offset(
        math.cos(clock * .6) * 365,
        math.sin(clock * .6) * 195,
      );
    }
    rig.advance(dt);
    notifyListeners();
  }
}

/// Isolated locomotion/aim review. It neither spawns a combat enemy nor modifies
/// a saved run. The normal Training route remains paused underneath it.
class WalkerWorkshopView extends StatefulWidget {
  const WalkerWorkshopView({
    super.key,
    this.loadout = const Loadout(training: true),
  });
  final Loadout loadout;
  @override
  State<WalkerWorkshopView> createState() => _WalkerWorkshopViewState();
}

class _WalkerWorkshopViewState extends State<WalkerWorkshopView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final controller = WalkerWorkshopController();
  final assets = WalkerAssets();
  late final Ticker ticker;
  Duration? previous;
  bool ready = false, foreground = true, draggingTarget = false;
  bool rookHeld = false;
  int? pointer;
  Object? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.foundry = widget.loadout.arena == ArenaType.foundry;
    ticker = createTicker(_tick)..start();
    _load();
  }

  Future<void> _load() async {
    try {
      await assets.load();
      if (!mounted) return;
      await RegunArt.shared.acquire('characters/rook');
      if (!mounted) {
        RegunArt.shared.release('characters/rook');
        return;
      }
      rookHeld = true;
      setState(() => ready = true);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  void _tick(Duration now) {
    final before = previous;
    previous = now;
    if (!ready || !foreground || before == null || controller.paused) return;
    // A hidden/stalled display never fast-forwards the workshop on return.
    final dt = ((now - before).inMicroseconds / 1000000).clamp(0.0, .1);
    controller.advance(dt);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    previous = null;
    pointer = null;
    draggingTarget = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.rig.reducedMotion =
        LocalPreferences.shared.reducedMotion ||
        MediaQuery.disableAnimationsOf(context);
    previous = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    controller.dispose();
    assets.dispose();
    if (rookHeld) RegunArt.shared.release('characters/rook');
    super.dispose();
  }

  Offset _world(Offset at, Size size) {
    return controller.worldPoint(at, size);
  }

  Widget _button(String label, VoidCallback action, {bool selected = false}) =>
      ClickButton(
        text: label,
        onTap: action,
        width: 108,
        height: 42,
        fontSize: 8,
        buttonColor: selected
            ? const Color(0xffE0B874)
            : const Color(0xffA6A18E),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff161B18),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _button('Back', () => Navigator.of(context).pop()),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'WALKER / 01',
                    style: TextStyle(
                      fontFamily: FontFam.pressStart,
                      fontSize: 12,
                      color: Color(0xffE0B874),
                    ),
                  ),
                ),
                const Text(
                  'RIG STUDY',
                  style: TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 11,
                    color: Color(0xffABA994),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: error != null
                ? const Center(
                    child: Text(
                      'Workshop art could not load.',
                      style: TextStyle(color: Color(0xffE0B874)),
                    ),
                  )
                : !ready
                ? const Center(
                    child: Text(
                      'ASSEMBLING',
                      style: TextStyle(
                        fontFamily: FontFam.pressStart,
                        fontSize: 10,
                        color: Color(0xffE0B874),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) => Listener(
                      onPointerDown: (event) {
                        if (pointer != null || controller.paused) return;
                        pointer = event.pointer;
                        final p = _world(event.localPosition, box.biggest);
                        draggingTarget =
                            (p - controller.rig.target).distance < 85;
                        setState(() {
                          if (draggingTarget) {
                            controller.aimAt(p);
                          } else {
                            controller.walkTo(p);
                          }
                        });
                      },
                      onPointerMove: (event) {
                        if (pointer != event.pointer || controller.paused) {
                          return;
                        }
                        final p = _world(event.localPosition, box.biggest);
                        if (draggingTarget) controller.aimAt(p);
                      },
                      onPointerUp: (event) {
                        if (pointer == event.pointer) pointer = null;
                      },
                      onPointerCancel: (event) {
                        if (pointer == event.pointer) pointer = null;
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: WalkerWorkshopPainter(
                            controller,
                            assets,
                            rook: rookHeld,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Tap floor to walk. Drag Rook to aim. No combat yet.',
              style: TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 11,
                color: Color(0xffBBB8A6),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 3, 10, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final mode in WalkerDemo.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _button(
                        mode.name,
                        () => setState(() => controller.choose(mode)),
                        selected: controller.mode == mode,
                      ),
                    ),
                  _button(
                    controller.paused ? 'Resume' : 'Pause',
                    () => setState(() {
                      controller.paused = !controller.paused;
                      previous = null;
                      pointer = null;
                    }),
                  ),
                  const SizedBox(width: 6),
                  _button(
                    controller.foundry ? 'Foundry' : 'Breach',
                    () => setState(() {
                      controller.toggleFloor();
                    }),
                  ),
                  const SizedBox(width: 6),
                  _button(
                    'Close view',
                    () => setState(
                      () => controller.inspect = !controller.inspect,
                    ),
                    selected: controller.inspect,
                  ),
                  const SizedBox(width: 6),
                  _button(
                    'Joints',
                    () => setState(() {
                      controller.toggleJoints();
                    }),
                    selected: controller.joints,
                  ),
                  const SizedBox(width: 6),
                  _button(
                    'Auto aim',
                    () => setState(controller.resumeAutoAim),
                    selected: controller.autoTarget,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class WalkerWorkshopPainter extends CustomPainter {
  WalkerWorkshopPainter(this.controller, this.assets, {this.rook = false})
    : super(repaint: controller);
  final WalkerWorkshopController controller;
  final WalkerAssets assets;
  final bool rook;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.clipRect(Offset.zero & size);
    final floor = assets.floors[controller.foundry ? 'foundry' : 'breach'];
    if (floor != null) {
      final tile = size.height;
      for (var x = 0.0; x < size.width; x += tile) {
        c.drawImageRect(
          floor,
          Rect.fromLTWH(0, 0, floor.width.toDouble(), floor.height.toDouble()),
          Rect.fromLTWH(x, 0, tile, tile),
          Paint()..filterQuality = FilterQuality.none,
        );
      }
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0x550F160F));
    }
    final origin = controller.viewOrigin(size);
    c.translate(origin.dx, origin.dy);
    c.scale(controller.viewScale(size));
    final rig = controller.rig;
    void target() {
      final at = rig.target;
      c.drawOval(
        Rect.fromCenter(center: at + const Offset(0, 2), width: 48, height: 16),
        Paint()..color = const Color(0x99101610),
      );
      if (rook && RegunArt.shared.contains('characters/rook')) {
        RegunArt.shared
            .sprite('characters/rook', 0)
            .render(
              c,
              position: Vector2(at.dx, at.dy + 8),
              size: Vector2.all(90),
              anchor: Anchor.bottomCenter,
            );
      } else {
        final p = Paint()
          ..color = const Color(0xffD0B77E)
          ..strokeWidth = 3;
        c.drawLine(at - const Offset(7, 0), at + const Offset(7, 0), p);
        c.drawLine(at - const Offset(0, 7), at + const Offset(0, 7), p);
      }
    }

    if (rig.target.dy < rig.position.dy) target();
    WalkerArt(assets).paint(c, rig, debug: controller.joints);
    if (rig.target.dy >= rig.position.dy) target();
    c.restore();
  }

  @override
  bool shouldRepaint(covariant WalkerWorkshopPainter oldDelegate) =>
      oldDelegate.assets != assets || oldDelegate.rook != rook;
}
