import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/systems/ariet_rig.dart';
import 'package:regun/systems/ariet_escort_study.dart';

/// One route owns one small Ariet atlas and one shared Walker study atlas.
/// Floors are borrowed; late decoding cannot resurrect a disposed route.
class ArietAssets {
  ui.Image? parts, engineSheet;
  final rects = <String, ui.Rect>{};
  final pivots = <String, ui.Offset>{};
  final floors = <String, ui.Image>{};
  final walker = WalkerAssets();
  bool _disposed = false;
  Future<void>? _loading;
  bool get ready =>
      !_disposed &&
      parts != null &&
      engineSheet != null &&
      walker.parts != null &&
      walker.arsenal != null &&
      walker.rects.containsKey('rocket');
  bool get disposed => _disposed;
  int get decodedBytes =>
      (parts == null ? 0 : parts!.width * parts!.height * 4) +
      walker.decodedBytes +
      (engineSheet == null ? 0 : engineSheet!.width * engineSheet!.height * 4);
  Future<void> load({bool combat = false, bool includeWalker = true}) =>
      _loading ??= _load(combat, includeWalker);
  Future<void> _load(bool combat, bool includeWalker) async {
    if (_disposed) return;
    try {
      final meta = jsonDecode(
        await rootBundle.loadString('assets/art/workshop/ariet_parts_v01.json'),
      ) as Map;
      if (_disposed) return;
      final data = await rootBundle.load(
        'assets/art/workshop/ariet_parts_v01.png',
      );
      if (_disposed) return;
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        targetWidth: combat ? 768 : meta['decodeWidth'] as int,
        allowUpscaling: false,
      );
      ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (_disposed) {
        image.dispose();
        return;
      }
      parts = image;
      final scale = image.width / (meta['sourceSize'][0] as num);
      for (final entry in (meta['parts'] as Map).entries) {
        final r = (entry.value['rect'] as List).cast<num>();
        final pivot = (entry.value['pivot'] as List).cast<num>();
        pivots[entry.key as String] = ui.Offset(
          pivot[0].toDouble(),
          pivot[1].toDouble(),
        );
        rects[entry.key as String] = ui.Rect.fromLTWH(
          r[0] * scale,
          r[1] * scale,
          r[2] * scale,
          r[3] * scale,
        );
      }
      final engineData = await rootBundle.load(
        'assets/art/workshop/ariet_exhaust_v01.png',
      );
      if (_disposed) return;
      final engineCodec = await ui.instantiateImageCodec(
        engineData.buffer.asUint8List(
          engineData.offsetInBytes,
          engineData.lengthInBytes,
        ),
        targetWidth: combat ? 512 : 768,
        allowUpscaling: false,
      );
      ui.Image engineImage;
      try {
        engineImage = (await engineCodec.getNextFrame()).image;
      } finally {
        engineCodec.dispose();
      }
      if (_disposed) {
        engineImage.dispose();
        return;
      }
      engineSheet = engineImage;
      if (includeWalker) {
        await walker.load(
          combat: true,
          partsWidth: combat ? 1280 : null,
          arsenalWidth: 512,
        );
        if (_disposed) return;
        floors.addAll(walker.floors);
      }
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  void dispose() {
    _disposed = true;
    parts?.dispose();
    parts = null;
    engineSheet?.dispose();
    engineSheet = null;
    walker.dispose();
    floors.clear();
    rects.clear();
    pivots.clear();
  }
}

class ArietArt {
  const ArietArt(this.assets, {this.flashFilter});
  final ui.ColorFilter? flashFilter;
  final ArietAssets assets;
  static const _grade = ui.ColorFilter.matrix([
    .87,
    .015,
    0,
    0,
    0,
    .01,
    .88,
    0,
    0,
    0,
    0,
    .01,
    .82,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
  void part(
    ui.Canvas c,
    String name,
    ui.Offset at,
    double width,
    double height, {
    double angle = 0,
    double alpha = 1,
    double pitch = 0,
    double bank = 0,
  }) {
    final src = assets.rects[name], image = assets.parts;
    if (src == null || image == null) return;
    c.save();
    c.translate(at.dx, at.dy);
    c.transform(
      Float64List.fromList([
        math.cos(angle) * math.cos(pitch),
        math.sin(angle) * math.cos(pitch) - .7 * math.sin(pitch),
        0,
        0,
        -math.sin(angle) * math.cos(bank),
        math.cos(angle) * math.cos(bank) - .7 * math.sin(bank),
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ]),
    );
    c.drawImageRect(
      image,
      src,
      ui.Rect.fromLTWH(
        -(assets.pivots[name]?.dx ?? .5) * width,
        -(assets.pivots[name]?.dy ?? .5) * height,
        width,
        height,
      ),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..isAntiAlias = false
        ..colorFilter = flashFilter ?? _grade
        ..color = ui.Color.fromRGBO(255, 255, 255, alpha),
    );
    c.restore();
  }

  void engineSprite(
    ui.Canvas c,
    int frame,
    ui.Offset at,
    double width, {
    required double height,
    required double angle,
    required double alpha,
    bool jet = false,
  }) {
    final sheet = assets.engineSheet;
    if (sheet == null || alpha <= 0) return;
    final measured = [
      const ui.Rect.fromLTWH(100, 150, 570, 300),
      const ui.Rect.fromLTWH(725, 145, 790, 310),
      const ui.Rect.fromLTWH(90, 520, 610, 430),
      const ui.Rect.fromLTWH(725, 490, 800, 500),
    ][frame];
    final scale = sheet.width / 1536;
    final src = ui.Rect.fromLTWH(
      measured.left * scale,
      measured.top * scale,
      measured.width * scale,
      measured.height * scale,
    );
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(angle);
    c.drawImageRect(
      sheet,
      src,
      ui.Rect.fromLTWH(-(jet ? .08 : .5) * width, -height * .5, width, height),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..color = ui.Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1)),
    );
    c.restore();
  }

  void paint(
    ui.Canvas c,
    ArietRig rig, {
    bool debug = false,
    bool cargo = false,
    bool groundShadows = true,
    List<double>? noseAngles,
    List<double>? noseRecoil,
    double cannonRecoil = 0,
    double flakRecoil = 0,
    double launcherFlash = 0,
    int launcherCell = -1,
  }) {
    if (groundShadows) {
      // A steady, layered shadow anchors the low hover. Bank does not drag it.
      for (final (width, height, alpha) in [
        (294.0, 238.0, .08),
        (278.0, 220.0, .12),
        (258.0, 198.0, .13),
      ]) {
        c.save();
        c.translate(rig.position.dx, rig.position.dy + 7);
        c.rotate(rig.yaw);
        c.drawOval(
          ui.Rect.fromCenter(
            center: ui.Offset.zero,
            width: width,
            height: height,
          ),
          ui.Paint()
            ..color = const ui.Color(0xff0C120F).withValues(alpha: alpha),
        );
        c.restore();
      }
    }
    // Draw exhaust behind the assembled machinery, at nozzle altitude.
    for (final puff in rig.exhaustPuffs) {
      final p = puff.progress;
      engineSprite(
        c,
        puff.frame,
        puff.position,
        40 + p * 40,
        height: 28 + p * 28,
        angle: math.atan2(puff.velocity.dy, puff.velocity.dx),
        alpha: .5 * puff.strength * math.pow(1 - p, 1.6),
      );
    }
    if (rig.enginesRunning) {
      for (var i = 0; i < 2; i++) {
        final d = rig.engineDirection(i), nozzle = rig.engineNozzle(i);
        final power = rig.reducedMotion ? .4 : rig.thrust;
        if (rig.reducedMotion) {
          engineSprite(
            c,
            2 + i,
            nozzle + d * 70,
            60,
            height: 36,
            angle: math.atan2(d.dy, d.dx),
            alpha: .26,
          );
        }
        final angle = math.atan2(d.dy, d.dx), length = 80 + power * 80;
        engineSprite(
          c,
          power > .55 ? 1 : 0,
          nozzle,
          length,
          height: 20 + power * 16,
          angle: angle,
          alpha: .46,
          jet: true,
        );
        // Advect distinct hot tongues from the nozzle out through the plume.
        // Constant core + staggered smooth packets avoid an on/off flame blink.
        final packets = rig.reducedMotion ? 2 : 4;
        for (var packet = 0; packet < packets; packet++) {
          final flow = rig.jetFlow(i, packet);
          final envelope = math.sin(flow * math.pi);
          engineSprite(
            c,
            packet % 2,
            nozzle + d * (length * .78 * flow),
            25 + power * 25,
            height: (15 + power * 10) * (1 - flow * .4),
            angle: angle,
            alpha: (rig.reducedMotion ? .22 : .48) * envelope,
            jet: true,
          );
        }
      }
    }
    void engine(int i) {
      final local = ArietRig.podMounts[i];
      final at = rig.project(local);
      // Axis is the lateral bearing; front/rear vertical travel projects the tilt.
      final angle = rig.reducedMotion ? 0.0 : rig.podAngle;
      const length = 220.0;
      part(
        c,
        'pod',
        at,
        length,
        88,
        angle: rig.yaw,
        pitch: angle + rig.pitch,
        bank: rig.bank,
      );
      // Bearing remains attached to the fixed pylon while pod pitches.
      part(
        c,
        'pylon',
        rig.project(ui.Offset(-10, local.dy.sign * 108)),
        94,
        25,
        angle: rig.yaw + math.pi / 2,
      );
    }

    final far =
        rig.project(ArietRig.podMounts[0]).dy <
            rig.project(ArietRig.podMounts[1]).dy
        ? 0
        : 1;
    engine(far);
    // Carrier rails are a separate underside assembly, visible fore/aft.
    part(
      c,
      'cradle',
      rig.project(ui.Offset.zero, z: -17),
      320,
      180,
      angle: rig.yaw,
    );
    if (cargo) {
      for (var i = 0; i < 2; i++) {
        final escort = ArietEscortStudy(folded: true);
        c.save();
        final at = rig.project(ArietRig.cargoMounts[i], z: -28);
        c.translate(at.dx, at.dy);
        c.rotate(rig.yaw);
        c.translate(0, escort.rig.height * .7 * escort.scale);
        c.scale(escort.scale);
        WalkerArt(assets.walker).paint(c, escort.rig, groundShadows: false);
        c.restore();
      }
    }
    part(
      c,
      'hull',
      rig.project(ui.Offset.zero),
      340,
      164,
      angle: rig.yaw,
      alpha: cargo ? .18 : 1,
      pitch: rig.pitch,
      bank: rig.bank,
    );
    // Both pods sit below the entire weapon deck at every heading.
    engine(1 - far);
    void bearing(ui.Offset local, double diameter, double z) {
      final at = rig.roofSocket(local, z);
      final deck = rig.air(local);
      for (final dx in [-4.0]) {
        c.drawRect(
          ui.Rect.fromLTRB(at.dx + dx, at.dy, at.dx + dx + 8, deck.dy),
          ui.Paint()..color = const ui.Color(0xff2C342C),
        );
        c.drawRect(
          ui.Rect.fromLTRB(at.dx + dx, at.dy, at.dx + dx + 1.5, deck.dy),
          ui.Paint()..color = const ui.Color(0xff827C5C),
        );
      }
      // Pixel-stepped iron bearing, toothed brass race and a textured receiver.
      c.save();
      c.translate(at.dx, at.dy);
      c.rotate(rig.yaw);
      for (final (inset, color) in [
        (0.0, const ui.Color(0xff242A24)),
        (4.0, const ui.Color(0xff9A8960)),
        (7.0, const ui.Color(0xff454E3F)),
      ]) {
        final d = diameter - inset * 2;
        final path = ui.Path();
        for (var n = 0; n < 12; n++) {
          final a = n * math.pi / 6;
          final p = ui.Offset(math.cos(a), math.sin(a)) * (d / 2);
          if (n == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        c.drawPath(
          path,
          ui.Paint()
            ..color = color
            ..isAntiAlias = false,
        );
      }
      for (var n = 0; n < 8; n++) {
        final a = n * math.pi / 4;
        final p = ui.Offset(math.cos(a), math.sin(a)) * (diameter / 2 - 6);
        c.drawRect(
          ui.Rect.fromCenter(center: p, width: 3, height: 3),
          ui.Paint()..color = const ui.Color(0xffB5A67C),
        );
      }
      c.restore();
    }

    // Six recessed launch cells with a visible loaded/launch state.
    final launcher = rig.launcherSocket;
    part(c, 'pylon', launcher, 54, 60, angle: rig.yaw);
    c.save();
    c.translate(launcher.dx, launcher.dy);
    c.rotate(rig.yaw);
    for (var n = 0; n < 6; n++) {
      final x = -18.0 + (n ~/ 3) * 20, y = -21.0 + (n % 3) * 20;
      c.drawRect(
        ui.Rect.fromLTWH(x - 2, y - 2, 18, 17),
        ui.Paint()..color = const ui.Color(0xffB19A68),
      );
      c.drawRect(
        ui.Rect.fromLTWH(x, y, 14, 13),
        ui.Paint()..color = const ui.Color(0xff202920),
      );
      c.drawRect(
        ui.Rect.fromLTWH(x + 4, y + 3, 6, 7),
        ui.Paint()
          ..color = launcherFlash > 0 && n == launcherCell
              ? const ui.Color(0xffF0C078)
              : const ui.Color(0xff747E60),
      );
    }
    c.restore();
    // Lowest weapon first. Raised barrel trunnions separate the crossing sweeps.
    bearing(ArietRig.flakMount, 47, ArietRig.flakHeight);
    final flakAt = rig.flakSocket;
    for (final side in [-1.0, 1.0]) {
      part(
        c,
        'nose',
        flakAt + ArietRig.rotate(ui.Offset(-flakRecoil, side * 8), rig.flakYaw),
        57,
        13,
        angle: rig.flakYaw,
      );
    }
    bearing(ArietRig.cannonMount, 55, ArietRig.cannonHeight);
    part(
      c,
      'cannon',
      rig.cannonSocket -
          ArietRig.rotate(ui.Offset(cannonRecoil, 0), rig.cannonYaw),
      102,
      38,
      angle: rig.cannonYaw,
      alpha: cargo ? .35 : 1,
    );
    for (var i = 0; i < 2; i++) {
      final local = ArietRig.noseMounts[i];
      final angle = noseAngles?[i] ?? rig.rotaryYaw[i];
      bearing(local, 43, ArietRig.rotaryZ(i));
      part(
        c,
        'nose',
        rig.noseSocket(i) -
            ArietRig.rotate(ui.Offset(noseRecoil?[i] ?? 0, 0), angle),
        68,
        23,
        angle: angle,
        alpha: cargo ? .35 : 1,
      );
    }
    if (debug) {
      for (final at in [
        ...ArietRig.podMounts,
        ...ArietRig.cargoMounts,
        ...ArietRig.noseMounts,
        ArietRig.cannonMount,
      ]) {
        final p = rig.project(at);
        final paint = ui.Paint()
          ..color = const ui.Color(0xffDDC491)
          ..strokeWidth = 1.5;
        c.drawLine(p - const ui.Offset(5, 0), p + const ui.Offset(5, 0), paint);
        c.drawLine(p - const ui.Offset(0, 5), p + const ui.Offset(0, 5), paint);
      }
      c.drawCircle(
        rig.position,
        ArietRig.navigationRadius,
        ui.Paint()
          ..color = const ui.Color(0x66C5AE75)
          ..style = ui.PaintingStyle.stroke,
      );
    }
  }
}
