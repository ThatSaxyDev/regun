import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' show Anchor, Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:regun/presentation/ariet_art.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/systems/ariet_rig.dart';
import 'package:regun/systems/ariet_escort_study.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

enum ArietDemo { hover, accelerate, strafe, turn, cargo, scale }

class ArietWorkshopController extends ChangeNotifier {
  ArietWorkshopController() {
    restart(notify: false);
  }
  late ArietRig rig;
  ArietDemo mode = ArietDemo.hover;
  bool paused = false, foundry = false, inspect = false, joints = false;
  bool reducedMotion = false;
  double sceneTime = 0;
  Offset? destination;
  // This is an inspection stage, not the production arena/encounter footprint.
  static const stage = Rect.fromLTRB(-720, -320, 720, 320);
  static final travel = stage.deflate(ArietRig.navigationRadius);
  void restart({bool notify = true}) {
    rig = ArietRig(
      resolveMove: (from, to) => Offset(
        to.dx.clamp(travel.left, travel.right),
        to.dy.clamp(travel.top, travel.bottom),
      ),
    )..reducedMotion = reducedMotion;
    if (mode == ArietDemo.cargo) {
      rig.hoverElevation = 128;
      rig.height = 128;
    }
    sceneTime = 0;
    destination = null;
    if (notify) notifyListeners();
  }

  void choose(ArietDemo next) {
    mode = next;
    restart();
  }

  void moveTo(Offset point) {
    if (mode == ArietDemo.cargo || mode == ArietDemo.scale || paused) return;
    destination = Offset(
      point.dx.clamp(travel.left, travel.right),
      point.dy.clamp(travel.top, travel.bottom),
    );
    notifyListeners();
  }

  void advance(double dt, {bool singleStep = false}) {
    if (paused && !singleStep) return;
    rig.reducedMotion = reducedMotion;
    rig.advance(
      dt,
      beforeStep: (time) {
        sceneTime = time;
        if (destination != null) {
          final d = destination! - rig.position;
          // Brake early enough to settle; navigation yaw stays independent.
          rig.command = ArietRig.limit(
            d * 1.8,
            math.sqrt(2 * ArietRig.braking * d.distance),
          );
          if (d.distance < .4 && rig.velocity.distance < 1) {
            destination = null;
            rig.command = Offset.zero;
            mode = ArietDemo.hover;
          }
          return;
        }
        final phase = time % 10;
        rig.command = Offset.zero;
        rig.speedLimit = ArietRig.cruiseSpeed;
        switch (mode) {
          case ArietDemo.accelerate:
            rig.command = phase < 2.2
                ? const Offset(220, 0)
                : phase < 4.5
                ? Offset.zero
                : phase < 7
                ? const Offset(-220, 0)
                : Offset.zero;
          case ArietDemo.strafe:
            rig.command = phase < 2
                ? const Offset(0, 110)
                : phase < 4
                ? const Offset(0, -110)
                : phase < 6
                ? const Offset(-180, 0)
                : phase < 8
                ? const Offset(180, 0)
                : Offset.zero;
            rig.desiredYaw = 0;
          case ArietDemo.turn:
            // Fixed destinations and holds avoid endless yaw/idle oscillation.
            rig.desiredYaw = phase < 2
                ? 0
                : phase < 5
                ? math.pi * .82
                : phase < 8
                ? -math.pi * .82
                : 0;
            rig.command = phase > 2 && phase < 4
                ? ArietRig.rotate(const Offset(80, 0), rig.yaw)
                : Offset.zero;
          case ArietDemo.hover:
          case ArietDemo.cargo:
          case ArietDemo.scale:
            break;
        }
      },
    );
    sceneTime = rig.elapsed;
    notifyListeners();
  }

  double viewScale(Size size) {
    // Cargo includes a side section: explicitly fit the entire study, while
    // ordinary flight retains the real phone camera width.
    final base = mode == ArietDemo.cargo
        ? math.min(size.width / 1500, size.height / 700)
        : size.width / 1500;
    return base * (inspect ? 1.65 : 1);
  }

  Offset viewOrigin(Size size) =>
      Offset(size.width / 2, size.height / 2) -
      (inspect ? rig.position * viewScale(size) : Offset.zero);
  Offset worldPoint(Offset p, Size size) =>
      (p - viewOrigin(size)) / viewScale(size);
}

/// Explicit development entry only. No production navigation references this.
class ArietWorkshopView extends StatefulWidget {
  const ArietWorkshopView({super.key});
  @override
  State<ArietWorkshopView> createState() => _ArietWorkshopViewState();
}

class _ArietWorkshopViewState extends State<ArietWorkshopView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final controller = ArietWorkshopController();
  final assets = ArietAssets();
  late final Ticker ticker;
  Duration? previous;
  bool foreground = true, ready = false, rookHeld = false;
  bool systemReduced = false, manualReduced = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (!ready || !foreground || before == null) return;
    controller.advance(((now - before).inMicroseconds / 1e6).clamp(0.0, .1));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    previous = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    systemReduced =
        LocalPreferences.shared.reducedMotion ||
        MediaQuery.disableAnimationsOf(context);
    controller.reducedMotion = systemReduced || manualReduced;
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

  Widget button(
    String label,
    VoidCallback action, {
    bool selected = false,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ClickButton(
      text: label,
      onTap: action,
      isActive: enabled,
      width: 110,
      height: 44,
      fontSize: 8,
      buttonColor: selected ? const Color(0xffE0B874) : const Color(0xffA6A18E),
    ),
  );
  void change(VoidCallback action) => setState(action);
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff161B18),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
            child: Row(
              children: [
                button('Back', () => Navigator.of(context).maybePop()),
                const Expanded(
                  child: Text(
                    'ARIET / 02',
                    style: TextStyle(
                      fontFamily: FontFam.pressStart,
                      fontSize: 11,
                      color: Color(0xffE0B874),
                    ),
                  ),
                ),
                const Text(
                  'FLIGHT STUDY',
                  style: TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 10,
                    color: Color(0xffB5B09F),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: error != null
                ? const Center(child: Text('Workshop art could not load.'))
                : !ready
                ? const Center(
                    child: Text(
                      'ASSEMBLING',
                      style: TextStyle(
                        fontFamily: FontFam.pressStart,
                        color: Color(0xffD1B77D),
                        fontSize: 10,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (e) => controller.moveTo(
                        controller.worldPoint(e.localPosition, box.biggest),
                      ),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: ArietWorkshopPainter(
                            controller,
                            assets,
                            rook: rookHeld,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Text(
              controller.mode == ArietDemo.cargo
                  ? 'Carrier cutaway (fit) / two folded 67.5% Walkers'
                  : controller.mode == ArietDemo.scale
                  ? 'Full Walker / 65% / 67.5% / 70% / geometry study'
                  : 'Tap floor to move. Mounted weapons are inactive.',
              style: const TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 11,
                color: Color(0xffBBB8A6),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final mode in ArietDemo.values)
                    button(
                      mode.name,
                      () => change(() => controller.choose(mode)),
                      selected: controller.mode == mode,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 4, 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  button(
                    controller.paused ? 'Resume' : 'Pause',
                    () => change(() {
                      controller.paused = !controller.paused;
                      previous = null;
                    }),
                    enabled: ready,
                  ),
                  button(
                    'Step',
                    () => controller.advance(1 / 60, singleStep: true),
                    enabled: ready && controller.paused,
                  ),
                  button(
                    'Restart',
                    () => change(controller.restart),
                    enabled: ready,
                  ),
                  button(
                    controller.foundry ? 'Foundry' : 'Breach',
                    () =>
                        change(() => controller.foundry = !controller.foundry),
                  ),
                  button(
                    'Close view',
                    () =>
                        change(() => controller.inspect = !controller.inspect),
                    selected: controller.inspect,
                  ),
                  button(
                    'Sockets',
                    () => change(() => controller.joints = !controller.joints),
                    selected: controller.joints,
                  ),
                  button(
                    'Reduced',
                    () => change(() {
                      manualReduced = !manualReduced;
                      controller.reducedMotion = systemReduced || manualReduced;
                    }),
                    selected: controller.reducedMotion,
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

class ArietWorkshopPainter extends CustomPainter {
  ArietWorkshopPainter(this.controller, this.assets, {this.rook = false})
    : super(repaint: controller);
  final ArietWorkshopController controller;
  final ArietAssets assets;
  final bool rook;
  void label(Canvas c, String text, Offset at, {double size = 17}) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: size,
          color: const Color(0xffD3C6A7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, at);
  }

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.clipRect(Offset.zero & size);
    final image = assets.floors[controller.foundry ? 'foundry' : 'breach'];
    // Same world-sized floor patches/grade as gameplay, independent of screen.
    c.translate(controller.viewOrigin(size).dx, controller.viewOrigin(size).dy);
    c.scale(controller.viewScale(size));
    if (image != null) {
      for (var x = -1536.0; x < 1536; x += 768) {
        for (var y = -768.0; y < 768; y += 768) {
          c.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            Rect.fromLTWH(x, y, 768, 768),
            Paint()
              ..filterQuality = FilterQuality.none
              ..colorFilter = const ColorFilter.mode(
                Color(0xff6B7770),
                BlendMode.modulate,
              ),
          );
        }
      }
    }
    if (controller.mode == ArietDemo.scale) {
      _scale(c);
    } else {
      ArietArt(assets).paint(
        c,
        controller.rig,
        debug: controller.joints,
        cargo: controller.mode == ArietDemo.cargo,
      );
      _rook(c, const Offset(300, 140));
      if (controller.mode == ArietDemo.cargo) {
        _section(c);
      }
    }
    if (controller.joints) {
      final r = controller.rig;
      label(
        c,
        '${r.velocity.distance.toStringAsFixed(0)} u/s / pod ${(r.podAngle * 180 / math.pi).toStringAsFixed(1)}° / ground root',
        const Offset(-680, -300),
      );
    }
    c.restore();
  }

  void _rook(Canvas c, Offset at) {
    if (rook && RegunArt.shared.contains('characters/rook')) {
      RegunArt.shared
          .sprite('characters/rook', 0)
          .render(
            c,
            position: Vector2(at.dx, at.dy),
            size: Vector2.all(100),
            anchor: Anchor.bottomCenter,
          );
    }
  }

  void _scale(Canvas c) {
    for (final (index, scale) in [1.0, .65, .675, .70].indexed) {
      final escort = ArietEscortStudy(scale: scale);
      final at = Offset(-480 + index * 300.0, 20);
      c.save();
      c.translate(at.dx, at.dy);
      c.scale(scale);
      WalkerArt(assets.walker).paint(c, escort.rig, debug: controller.joints);
      c.restore();
      label(
        c,
        index == 0
            ? 'Walker 100%'
            : '${(scale * 100).toStringAsFixed(1)}% / 50 HP trial',
        Offset(at.dx - 115, 180),
        size: 16,
      );
    }
    _rook(c, const Offset(550, 130));
  }

  void _section(Canvas c) {
    // Side section is an explicit engineering envelope, not new side-view art.
    // No damage/drop simulation implied. Shows actual scaled IK below the deck.
    const origin = Offset(-100, 200);
    final p = Paint()
      ..color = const Color(0xff9F946C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    c.drawRect(
      Rect.fromCenter(
        center: origin - const Offset(0, 68),
        width: 276,
        height: 22,
      ),
      p,
    );
    c.drawLine(
      origin + const Offset(-160, -48),
      origin + const Offset(160, -48),
      p,
    );
    for (final mount in ArietRig.cargoMounts) {
      final e = ArietEscortStudy(folded: true);
      final at = origin + Offset(mount.dx, 0);
      c.drawRect(
        Rect.fromCenter(
          center: at - const Offset(0, 25),
          width: 206 * e.scale,
          height: 32 * e.scale,
        ),
        p,
      );
      for (final leg in e.rig.legs.where((l) => l.mount.dy > 0)) {
        final pose = e.pose(leg);
        Offset side(ui.Offset xy, double z) => at + Offset(xy.dx, -z);
        final path = Path()
          ..moveTo(
            side(pose.hip.ground, pose.hip.z).dx,
            side(pose.hip.ground, pose.hip.z).dy,
          )
          ..lineTo(
            side(pose.knee.ground, pose.knee.z).dx,
            side(pose.knee.ground, pose.knee.z).dy,
          )
          ..lineTo(
            side(pose.ankle.ground, pose.ankle.z).dx,
            side(pose.ankle.ground, pose.ankle.z).dy,
          );
        c.drawPath(path, p);
      }
    }
    label(
      c,
      'SIDE SECTION / folded rig / clearance study',
      origin + const Offset(-200, 24),
      size: 15,
    );
  }

  @override
  bool shouldRepaint(covariant ArietWorkshopPainter oldDelegate) =>
      oldDelegate.assets != assets || oldDelegate.rook != rook;
}
