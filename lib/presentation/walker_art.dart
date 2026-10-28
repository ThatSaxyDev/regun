import 'dart:convert';

import 'package:flame/components.dart' show Anchor;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:regun/systems/walker_rig.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/walker_combat.dart';
import 'package:regun/presentation/attack_vfx.dart';

/// Owned by the workshop route, not the global combat atlas cache. Late loads
/// are disposed if the route leaves before decoding completes.
class WalkerAssets {
  ui.Image? parts;
  ui.Image? arsenal;
  final Set<String> arsenalNames = {};
  final Map<String, ui.Image> floors = {};
  final Map<String, ui.Rect> rects = {};
  bool _disposed = false;
  bool get disposed => _disposed;
  bool get ready => !_disposed && parts != null && arsenal != null && floors.length == 2;
  // Floors are borrowed from the non-lazy world cache, not decoded twice.
  int get decodedBytes => [
    parts,
    arsenal,
  ].whereType<ui.Image>().fold(0, (n, im) => n + im.width * im.height * 4);
  ui.Image? imageFor(String name) =>
      arsenalNames.contains(name) ? arsenal : parts;

  Future<void> load({bool combat = false}) async {
    final meta = jsonDecode(
      await rootBundle.loadString('assets/art/workshop/walker_parts_v01.json'),
    ) as Map;
    final rectData = meta['parts'] as Map;
    for (final entry in rectData.entries) {
      final v = (entry.value as List).cast<num>();
      rects[entry.key as String] = ui.Rect.fromLTWH(
        v[0].toDouble(),
        v[1].toDouble(),
        v[2].toDouble(),
        v[3].toDouble(),
      );
    }
    // Keep part source pixels intact. This small dedicated atlas is ~6MiB.
    await _loadParts(width: combat ? 1536 : null);
    if (_disposed) return;
    final scale = parts!.width / (meta['sourceSize'][0] as num);
    for (final name in rects.keys.toList()) {
      final r = rects[name]!;
      rects[name] = ui.Rect.fromLTWH(
        r.left * scale,
        r.top * scale,
        r.width * scale,
        r.height * scale,
      );
    }
    if (combat) {
      final extra = jsonDecode(
        await rootBundle.loadString(
          'assets/art/workshop/walker_arsenal_v01.json',
        ),
      ) as Map;
      final bytes = await rootBundle.load(
        'assets/art/workshop/walker_arsenal_v01.png',
      );
      if (_disposed) return;
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        targetWidth: extra['decodeWidth'] as int,
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      if (_disposed) {
        image.dispose();
        return;
      }
      arsenal = image;
      final s = image.width / (extra['sourceSize'][0] as num);
      for (final e in (extra['parts'] as Map).entries) {
        final v = (e.value as List).cast<num>();
        arsenalNames.add(e.key as String);
        rects[e.key as String] = ui.Rect.fromLTWH(
          v[0] * s,
          v[1] * s,
          v[2] * s,
          v[3] * s,
        );
      }
    }
    await RegunArt.shared.load();
    if (_disposed) return;
    for (final floor in ['breach', 'foundry']) {
      floors[floor] = RegunArt.shared.image('arenas/${floor}_floor');
    }
  }

  Future<void> _loadParts({int? width}) async {
    if (_disposed) return;
    final data = await rootBundle.load(
      'assets/art/workshop/walker_parts_v01.png',
    );
    if (_disposed) return;
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      allowUpscaling: false,
      targetWidth: width,
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    if (_disposed) {
      image.dispose();
      return;
    }
    parts = image;
  }

  void dispose() {
    _disposed = true;
    parts?.dispose();
    parts = null;
    arsenal?.dispose();
    arsenal = null;
    floors.clear();
  }
}

class WalkerArt {
  const WalkerArt(this.assets, {this.flashFilter});
  final WalkerAssets assets;
  final ui.ColorFilter? flashFilter;
  static const _shade = ui.Color(0xff101610);
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
    double width, {
    double angle = 0,
    double? height,
    double alpha = 1,
  }) {
    final image = assets.imageFor(name), src = assets.rects[name];
    if (image == null || src == null) return;
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(angle);
    c.drawImageRect(
      image,
      src,
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: width,
        height: height ?? width * src.height / src.width,
      ),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..isAntiAlias = false
        ..colorFilter = flashFilter ?? _grade
        ..color = ui.Color.fromRGBO(255, 255, 255, alpha),
    );
    c.restore();
  }

  void _link(ui.Canvas c, String id, ui.Offset a, ui.Offset b, double width) {
    final d = b - a;
    // Endpoint bearings sit at 10/90% of the link's authored horizontal extent.
    part(
      c,
      id,
      (a + b) / 2,
      d.distance / .8,
      height: width,
      angle: math.atan2(d.dy, d.dx),
    );
  }

  void _piston(ui.Canvas c, ui.Offset a, ui.Offset b) {
    final d = b - a;
    for (final (color, width, length) in [
      (const ui.Color(0xff111713), 9.0, 1.0),
      (const ui.Color(0xff9F9F8B), 5.0, 1.0),
      (const ui.Color(0xff353D32), 9.0, .54),
      (const ui.Color(0xff8A7950), 5.0, .51),
    ]) {
      c.drawLine(
        a,
        a + d * length,
        ui.Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = ui.StrokeCap.square,
      );
    }
  }

  void paint(
    ui.Canvas c,
    WalkerRig rig, {
    bool debug = false,
    WalkerCombat? combat,
  }) {
    for (final leg in rig.legs) {
      c.drawOval(
        ui.Rect.fromCenter(
          center: leg.foot + const ui.Offset(4, 6),
          width: 56 - leg.lift,
          height: 22,
        ),
        ui.Paint()..color = _shade.withValues(alpha: leg.planted ? .65 : .3),
      );
    }
    c.drawOval(
      ui.Rect.fromCenter(
        center: rig.position + const ui.Offset(0, 9),
        width: 204,
        height: 118,
      ),
      ui.Paint()..color = _shade.withValues(alpha: .45),
    );
    final far = rig.legs.where((leg) => leg.foot.dy < rig.position.dy).toList();
    final near = rig.legs
        .where((leg) => leg.foot.dy >= rig.position.dy)
        .toList();
    for (final leg in far) {
      _leg(c, rig, leg, debug);
    }
    final center = rig.point(ui.Offset.zero, rig.height).projected;
    // Thrusters remain cold in the locomotion slice; they are mounted hardware.
    for (final side in [-1.0, 1.0]) {
      final at = rig.point(ui.Offset(-73, side * 30), rig.height - 6).projected;
      part(c, 'thruster', at, 45, angle: rig.yaw);
    }
    part(c, 'chassis', center, 206, angle: rig.yaw);
    // The unused opposite socket stays visibly empty until its module exists.
    final empty = rig.point(const ui.Offset(-12, 43), rig.height + 4).projected;
    part(c, 'bearing', empty, 35, angle: rig.yaw);
    final pivot = rig.turretPivot.projected;
    part(c, 'bearing', pivot, 44, angle: rig.yaw);
    final muzzle = combat == null
        ? rig.muzzle.projected
        : combat.muzzle(false) - WalkerCombat.visualOffset;
    final d = muzzle - pivot;
    final angle = math.atan2(d.dy, d.dx);
    final unit = d / d.distance;
    part(
      c,
      'barrel',
      muzzle - d * (.83 / 2),
      d.distance * .83,
      height: 20,
      angle: angle,
    );
    part(c, 'receiver', pivot + unit * 7, 77, height: 45, angle: angle);
    if (combat != null) {
      final cannonPivot = rig
          .point(const ui.Offset(-12, 43), rig.height + 18)
          .projected;
      final cannonDirection = WalkerCombat.unit(combat.barrelHeading(true));
      final cannonTip = combat.muzzle(true) - WalkerCombat.visualOffset;
      part(c, 'bearing', cannonPivot, 44);
      part(
        c,
        'cannonBarrel',
        cannonTip - cannonDirection * 62,
        124,
        height: 29,
        angle: combat.barrelHeading(true),
      );
      part(
        c,
        'cannonReceiver',
        cannonPivot + cannonDirection * 13,
        89,
        height: 55,
        angle: combat.barrelHeading(true),
      );
      final rack = rig
          .point(const ui.Offset(-48, 0), rig.height + 30)
          .projected;
      part(c, 'rack', rack, 80, angle: combat.rackYaw);
      for (var i = 0; i < 8; i++) {
        final spent = i < combat.rocketSpent;
        final at =
            rack +
            WalkerRig.rotate(
              ui.Offset(9 + (i % 4) * 9, (i ~/ 4 - .5) * 17),
              combat.rackYaw,
            );
        c.drawRect(
          ui.Rect.fromCenter(center: at, width: 5, height: 5),
          ui.Paint()
            ..color = spent
                ? const ui.Color(0xff111511)
                : const ui.Color(0xffBC7651),
        );
      }
      part(
        c,
        'optic',
        rig.point(const ui.Offset(53, 0), rig.height + 5).projected,
        40,
        angle: rig.yaw,
      );
      // Receiver spin marks are small material highlights, not a floating loop.
      for (var i = 0; i < 3; i++) {
        final spin = combat.barrelSpin + i * math.pi * 2 / 3;
        final at =
            pivot + d * .87 + ui.Offset(-unit.dy, unit.dx) * math.sin(spin) * 6;
        c.drawRect(
          ui.Rect.fromCenter(center: at, width: 3, height: 3),
          ui.Paint()..color = const ui.Color(0xffAD9D73),
        );
      }
      for (final (tip, _, flash) in [
        (muzzle, rig.turretYaw, combat.rotaryFlash),
        (cannonTip, combat.cannonYaw, combat.cannonFlash),
      ]) {
        if (flash > 0) {
          AttackVfx.stamp(
            c,
            18,
            tip,
            43,
            height: 28,
            anchor: Anchor.center,
            material: AttackMaterial.ember,
          );
        }
      }
    }
    for (final leg in near) {
      _leg(c, rig, leg, debug);
    }
    if (debug) {
      _cross(c, rig.position, const ui.Color(0xffD5B775));
      _cross(c, muzzle, const ui.Color(0xffD17C68));
    }
  }

  void _leg(ui.Canvas c, WalkerRig rig, WalkerLeg leg, bool debug) {
    final p = rig.pose(leg),
        hip = p.hip.projected,
        knee = p.knee.projected,
        ankle = p.ankle.projected;
    part(
      c,
      'foot',
      ankle + WalkerRig.rotate(const ui.Offset(13, 0), leg.footYaw),
      61,
      angle: leg.footYaw,
    );
    _link(c, 'lower', knee, ankle, 23);
    _link(c, 'upper', hip, knee, 32);
    final side =
        ui.Offset(
          math.cos(leg.footYaw + math.pi / 2),
          math.sin(leg.footYaw + math.pi / 2),
        ) *
        10;
    _piston(
      c,
      ui.Offset.lerp(hip, knee, .2)! + side,
      ui.Offset.lerp(knee, ankle, .55)! + side,
    );
    part(c, 'bearing', hip, 36);
    part(c, 'bearing', knee, 29);
    part(c, 'bearing', ankle, 22);
    if (debug) {
      for (final at in [hip, knee, ankle]) {
        _cross(c, at, const ui.Color(0xffD5B775));
      }
    }
  }

  void _cross(ui.Canvas c, ui.Offset at, ui.Color color) {
    final p = ui.Paint()
      ..color = color
      ..strokeWidth = 2;
    c.drawLine(at - const ui.Offset(5, 0), at + const ui.Offset(5, 0), p);
    c.drawLine(at - const ui.Offset(0, 5), at + const ui.Offset(0, 5), p);
  }
}
