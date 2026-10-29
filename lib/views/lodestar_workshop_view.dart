import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:regun/presentation/lodestar_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/systems/target_shape.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

enum LodestarStudy { carriage, orbit, eight, reverse, wall }

class LodestarWorkshopController extends ChangeNotifier {
  LodestarWorkshopController() {
    restart();
  }
  late LodestarRig rig;
  late LodestarSections sections;
  LodestarStudy study = LodestarStudy.carriage;
  LodestarSection selected = LodestarSection.feeder;
  bool paused = false, foundry = false, reducedMotion = false, sockets = false;
  bool close = false, loading = false;
  double clock = 0, loadClock = 0;
  final hitClocks = <LodestarSection, double>{};
  static const bounds = Rect.fromLTRB(-1800, -1300, 1800, 1300);
  static const wall = TargetCapsule(Offset(400, -450), Offset(400, 450), 35);
  void restart() {
    sections = LodestarSections();
    final space = LodestarSpace(
      bounds: bounds,
      broken: (s) => !sections.living(s),
      solids: study == LodestarStudy.wall ? [wall] : const [],
    );
    rig = LodestarRig(head: const Offset(260, -170), acceptPose: space.accepts);
    hitClocks.clear();
    clock = 0;
    loadClock = 0;
    notifyListeners();
  }

  void choose(LodestarStudy value) {
    study = value;
    restart();
  }

  void hit() {
    final result = sections.primary(selected, 10, LodestarHitLedger());
    if (result.isNotEmpty) hitClocks[selected] = clock;
    notifyListeners();
  }

  void pick(Offset at) {
    final list = rig.poses.where(
      (p) =>
          study != LodestarStudy.carriage ||
          p.section == LodestarSection.mortars ||
          p.section == LodestarSection.feeder,
    );
    for (final p in list) {
      if (p.footprint().distance(at) <= 8) {
        selected = p.section;
        break;
      }
    }
    notifyListeners();
  }

  void advance(double dt, {bool step = false}) {
    if (paused && !step) return;
    if (!dt.isFinite || dt <= 0) return;
    rig.advance(
      dt,
      beforeStep: (time) {
        rig.requestedSpeed = 0;
        switch (study) {
          case LodestarStudy.carriage:
            break;
          case LodestarStudy.orbit:
            rig.requestedSpeed = 260;
            rig.desiredHeading = time * 260 / 320;
          case LodestarStudy.eight:
            // Broad bounded-curvature target. Rejection is visible, not hidden by
            // relaxing anatomy. Gate 2 pursuit/escape acceptance remains open.
            final phase = time * .24;
            rig.requestedSpeed = 260;
            rig.desiredHeading = math.atan2(
              580 * math.cos(2 * phase),
              950 * math.cos(phase),
            );
          case LodestarStudy.reverse:
            rig.requestedSpeed = time % 8 < 4 ? 220 : -220;
            rig.desiredHeading = .35 * math.sin(time * .4);
          case LodestarStudy.wall:
            rig.requestedSpeed = 260;
            rig.desiredHeading = 0;
        }
        if (sections.defeated) rig.requestedSpeed = 0;
        if (loading && sections.living(LodestarSection.feeder)) {
          loadClock += LodestarRig.tick;
        }
      },
    );
    clock = rig.elapsed;
    notifyListeners();
  }

  double scale(Size size) =>
      math.min(size.width / 1500, size.height / 700) * (close ? 2.8 : 1);
  Offset center() {
    if (study == LodestarStudy.carriage) {
      return (rig.poses[2].position + rig.poses[3].position) / 2;
    }
    if (close) return rig.poses[selected.index].position;
    final positions = rig.poses.map((p) => p.position).toList();
    return Offset(
      (positions.map((p) => p.dx).reduce(math.min) +
              positions.map((p) => p.dx).reduce(math.max)) /
          2,
      (positions.map((p) => p.dy).reduce(math.min) +
              positions.map((p) => p.dy).reduce(math.max)) /
          2,
    );
  }

  Offset world(Offset point, Size size) =>
      (point - size.center(Offset.zero)) / scale(size) + center();
}

/// Only tool/lodestar_workshop.dart reaches this view. No playable encounter,
/// combat registration, normal loadout button, profile writes or network access.
class LodestarWorkshopView extends StatefulWidget {
  const LodestarWorkshopView({super.key});
  @override
  State<LodestarWorkshopView> createState() => _LodestarWorkshopViewState();
}

class _LodestarWorkshopViewState extends State<LodestarWorkshopView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final controller = LodestarWorkshopController();
  final assets = LodestarAssets();
  late final Ticker ticker;
  Duration? previous;
  bool foreground = true, manualReduced = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ticker = createTicker((now) {
      final before = previous;
      previous = now;
      if (!foreground || !assets.ready || before == null) return;
      controller.advance(((now - before).inMicroseconds / 1e6).clamp(0, .1));
    })..start();
    _load();
  }

  Future<void> _load() async {
    try {
      await assets.load();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    previous = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    controller.dispose();
    assets.dispose();
    super.dispose();
  }

  Widget button(String text, VoidCallback action, {bool selected = false}) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ClickButton(
          text: text,
          onTap: () {
            action();
            previous = null;
            setState(() {});
          },
          width: 112,
          height: 44,
          fontSize: 8,
          buttonColor: selected
              ? const Color(0xffE0B874)
              : const Color(0xffA6A18E),
        ),
      );
  @override
  Widget build(BuildContext context) {
    controller.reducedMotion =
        manualReduced ||
        LocalPreferences.shared.reducedMotion ||
        MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xff161B18),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  button('Back', () => Navigator.of(context).pop()),
                  const Expanded(
                    child: Text(
                      'LODESTAR / CONSTRUCTION',
                      style: TextStyle(
                        fontFamily: FontFam.pressStart,
                        fontSize: 10,
                        color: Color(0xffD4C4A3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: error != null
                  ? const Center(child: Text('Art could not load.'))
                  : !assets.ready
                  ? const Center(child: Text('ASSEMBLING'))
                  : LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (e) => controller.pick(
                          controller.world(e.localPosition, box.biggest),
                        ),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: LodestarWorkshopPainter(controller, assets),
                        ),
                      ),
                    ),
            ),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Text(
                  '${controller.selected.name.toUpperCase()} '
                  '${controller.sections.integrity(controller.selected).toStringAsFixed(0)} / '
                  '${controller.selected.maxIntegrity.toStringAsFixed(0)}  /  '
                  '${controller.rig.speed.toStringAsFixed(0)} u/s  /  '
                  '${controller.rig.rejectedSteps} blocked steps',
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 11,
                    color: Color(0xffC2BCA8),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  for (final s in LodestarStudy.values)
                    button(
                      s.name,
                      () => controller.choose(s),
                      selected: s == controller.study,
                    ),
                  button('Hit 10', controller.hit),
                  button(
                    'Load',
                    () => controller.loading = !controller.loading,
                    selected: controller.loading,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Row(
                children: [
                  button(
                    controller.paused ? 'Resume' : 'Pause',
                    () => controller.paused = !controller.paused,
                  ),
                  button('Step', () {
                    if (controller.paused && foreground) {
                      controller.advance(1 / 60, step: true);
                    }
                  }),
                  button('Restart', controller.restart),
                  button(
                    controller.foundry ? 'Foundry' : 'Breach',
                    () => controller.foundry = !controller.foundry,
                  ),
                  button(
                    'Close',
                    () => controller.close = !controller.close,
                    selected: controller.close,
                  ),
                  button(
                    'Sockets',
                    () => controller.sockets = !controller.sockets,
                    selected: controller.sockets,
                  ),
                  button(
                    'Reduced',
                    () => manualReduced = !manualReduced,
                    selected: controller.reducedMotion,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LodestarWorkshopPainter extends CustomPainter {
  LodestarWorkshopPainter(this.controller, this.assets)
    : super(repaint: controller);
  final LodestarWorkshopController controller;
  final LodestarAssets assets;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.clipRect(Offset.zero & size);
    c.translate(size.width / 2, size.height / 2);
    c.scale(controller.scale(size));
    c.translate(-controller.center().dx, -controller.center().dy);
    final floor = assets.floors[controller.foundry ? 'foundry' : 'breach'];
    if (floor != null) {
      for (var x = -2304.0; x < 2304; x += 768) {
        for (var y = -2304.0; y < 2304; y += 768) {
          c.drawImageRect(
            floor,
            Rect.fromLTWH(
              0,
              0,
              floor.width.toDouble(),
              floor.height.toDouble(),
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
    if (controller.study == LodestarStudy.wall) {
      c.drawRect(
        const Rect.fromLTRB(365, -450, 435, 450),
        Paint()..color = const Color(0xff393F39),
      );
    }
    final art = LodestarArt(assets), poses = controller.rig.poses;
    final construction = controller.study == LodestarStudy.carriage;
    for (var i = 0; i < 5; i++) {
      if (construction && i != 2) continue;
      art.coupling(c, controller.rig.couplings[i]);
    }
    for (final p in poses) {
      if (construction &&
          p.section != LodestarSection.mortars &&
          p.section != LodestarSection.feeder) {
        continue;
      }
      final stamp = controller.hitClocks[p.section];
      final flash = stamp == null
          ? 0.0
          : (1 - (controller.clock - stamp) / .32).clamp(0.0, 1.0);
      art.carriage(
        c,
        p,
        broken: !controller.sections.living(p.section),
        signedTravel: controller.rig.rollerTravel,
        mechanism: controller.loadClock % 1.8 / 1.8,
        feeder: p.section == LodestarSection.feeder,
        sockets: controller.sockets,
        flash: controller.reducedMotion ? 0 : flash,
      );
      if (p.section == controller.selected) {
        c.drawRect(
          Rect.fromCenter(center: p.position, width: 8, height: 8),
          Paint()..color = const Color(0xffBBA274),
        );
      }
    }
    c.restore();
    _label(
      c,
      construction
          ? 'CARRIAGE / FEEDER / TAP TO SELECT'
          : 'BARE SIX-SECTION RIG / WEAPONS NOT BUILT',
      Offset(12, size.height - 22),
    );
  }

  void _label(Canvas c, String text, Offset at) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: 11,
          color: Color(0xffD6C5A1),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, at);
  }

  @override
  bool shouldRepaint(covariant LodestarWorkshopPainter oldDelegate) => true;
}
