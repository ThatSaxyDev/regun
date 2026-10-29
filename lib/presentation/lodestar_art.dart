import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';

/// One lease per route/encounter, floors borrowed from RegunArt. Pending decodes
/// cannot resurrect a disposed owner. One atlas shared by all six carriages.
class LodestarAssets {
  ui.Image? sheet, arsenal, excavation, warnings, excavationFoundry;
  final foundryNames = <String>{};
  final warningNames = <String>{};
  final groundNames = <String>{};
  final weaponNames = <String>{};
  ui.Image? imageFor(String name) => foundryNames.contains(name)
      ? excavationFoundry
      : warningNames.contains(name)
      ? warnings
      : groundNames.contains(name)
      ? excavation
      : weaponNames.contains(name)
      ? arsenal
      : sheet;
  final Map<String, ui.Rect> rects = {};
  final Map<String, ui.Image> floors = {};
  Future<void>? _pending;
  bool disposed = false;
  bool get ready => !disposed && sheet != null && floors.length == 2;
  int get decodedBytes =>
      [sheet, arsenal, excavation, warnings, excavationFoundry]
          .whereType<ui.Image>()
          .fold(0, (sum, image) => sum + image.width * image.height * 4);
  Future<void> load({bool combat = false}) => _pending ??= _load(combat);
  Future<void> _load(bool combat) async {
    if (disposed) return;
    try {
      final meta = jsonDecode(
        await rootBundle.loadString(
          'assets/art/workshop/lodestar_parts_v01.json',
        ),
      ) as Map;
      if (disposed) return;
      final data = await rootBundle.load(
        'assets/art/workshop/lodestar_parts_v01.png',
      );
      if (disposed) return;
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
      if (disposed) {
        image.dispose();
        return;
      }
      sheet = image;
      final scale = image.width / (meta['sourceSize'][0] as num);
      for (final e in (meta['parts'] as Map).entries) {
        final r = (e.value['rect'] as List).cast<num>();
        rects[e.key as String] = ui.Rect.fromLTWH(
          r[0] * scale,
          r[1] * scale,
          r[2] * scale,
          r[3] * scale,
        );
      }
      if (combat) {
        final extra = jsonDecode(
          await rootBundle.loadString(
            'assets/art/workshop/lodestar_arsenal_v01.json',
          ),
        ) as Map;
        if (disposed) return;
        final bytes = await rootBundle.load(
          'assets/art/workshop/lodestar_arsenal_v01.png',
        );
        if (disposed) return;
        final decoder = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          targetWidth: 768,
          allowUpscaling: false,
        );
        ui.Image art;
        try {
          art = (await decoder.getNextFrame()).image;
        } finally {
          decoder.dispose();
        }
        if (disposed) {
          art.dispose();
          return;
        }
        arsenal = art;
        final ratio = art.width / (extra['sourceSize'][0] as num);
        for (final entry in (extra['parts'] as Map).entries) {
          final r = (entry.value['rect'] as List).cast<num>();
          weaponNames.add(entry.key as String);
          rects[entry.key as String] = ui.Rect.fromLTWH(
            r[0] * ratio,
            r[1] * ratio,
            r[2] * ratio,
            r[3] * ratio,
          );
        }
      }
      if (combat) {
        for (final atlas in ['excavation', 'warnings', 'excavation_foundry']) {
          final meta = jsonDecode(
            await rootBundle.loadString(
              'assets/art/workshop/lodestar_${atlas}_v01.json',
            ),
          ) as Map;
          final bytes = await rootBundle.load(
            'assets/art/workshop/lodestar_${atlas}_v01.png',
          );
          if (disposed) return;
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
            targetWidth: 384,
            allowUpscaling: false,
          );
          ui.Image image;
          try {
            image = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
          if (disposed) {
            image.dispose();
            return;
          }
          if (atlas == 'excavation_foundry') {
            excavationFoundry = image;
          } else if (atlas == 'excavation') {
            excavation = image;
          } else {
            warnings = image;
          }
          final ratio = image.width / (meta['sourceSize'][0] as num);
          for (final e in (meta['parts'] as Map).entries) {
            final r = (e.value['rect'] as List).cast<num>();
            (atlas == 'excavation_foundry'
                    ? foundryNames
                    : atlas == 'excavation'
                    ? groundNames
                    : warningNames)
                .add(e.key as String);
            rects[e.key as String] = ui.Rect.fromLTWH(
              r[0] * ratio,
              r[1] * ratio,
              r[2] * ratio,
              r[3] * ratio,
            );
          }
        }
      }
      await RegunArt.shared.load();
      if (disposed) return;
      for (final name in ['breach', 'foundry']) {
        floors[name] = RegunArt.shared.image('arenas/${name}_floor');
      }
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  void dispose() {
    disposed = true;
    sheet?.dispose();
    sheet = null;
    excavationFoundry?.dispose();
    excavationFoundry = null;
    foundryNames.clear();
    warnings?.dispose();
    warnings = null;
    warningNames.clear();
    excavation?.dispose();
    excavation = null;
    groundNames.clear();
    arsenal?.dispose();
    arsenal = null;
    weaponNames.clear();
    rects.clear();
    floors.clear();
  }
}

/// Gate 1 carriage art, not substitute art for the five unbuilt weapons.
class LodestarArt {
  const LodestarArt(this.assets);
  final LodestarAssets assets;
  void part(
    ui.Canvas c,
    String name,
    ui.Offset at,
    ui.Size size,
    double yaw, {
    double alpha = 1,
  }) {
    final src = assets.rects[name], image = assets.imageFor(name);
    if (src == null || image == null) return;
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(yaw);
    c.drawImageRect(
      image,
      src,
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: size.width,
        height: size.height,
      ),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..color = ui.Color.fromRGBO(255, 255, 255, alpha)
        ..colorFilter = const ui.ColorFilter.mode(
          ui.Color(0xffB2B6A1),
          ui.BlendMode.modulate,
        ),
    );
    c.restore();
  }

  void coupling(ui.Canvas c, LodestarCoupling link) {
    // Eye centers sit at the two real solved sockets; art adds a small yoke
    // outside each center. Reach rejection prevents visibly stretching hoses.
    part(
      c,
      'coupling',
      (link.a + link.b) / 2,
      ui.Size(link.length * 490 / 446, 13),
      link.yaw,
    );
  }

  void carriage(
    ui.Canvas c,
    LodestarPose pose, {
    required bool broken,
    required double signedTravel,
    double mechanism = 0,
    bool feeder = false,
    bool sockets = false,
    double flash = 0,
  }) {
    final at = pose.position, yaw = pose.yaw;
    final shadow = ui.Paint()..color = const ui.Color(0x55090E0B);
    c.save();
    c.translate(at.dx, at.dy + 3);
    c.rotate(yaw);
    c.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: 104,
        height: broken ? 25 : 100,
      ),
      shadow,
    );
    c.restore();
    if (broken) {
      // Only the actual load-bearing spine survives. The sheet's broad ruined
      // rails are NOT mounted as invisible non-solid armor beside this spine.
      part(c, 'spine', at, const ui.Size(22, 108), yaw - math.pi / 2);
    } else {
      for (final side in [-1.0, 1.0]) {
        part(
          c,
          'bogie',
          pose.socket(ui.Offset(0, side * 42)),
          const ui.Size(72, 26),
          yaw,
        );
        // Actual signed distance indexes the roller cleats. No clock-driven
        // skating; reverse runs them backward and a blocked rig holds them.
        c.save();
        c.translate(at.dx, at.dy);
        c.rotate(yaw);
        c.clipRect(ui.Rect.fromLTWH(-31, side * 42 - 9, 62, 18));
        final phase = signedTravel % 12;
        for (var i = -4; i <= 4; i++) {
          c.drawRect(
            ui.Rect.fromLTWH(i * 12 + phase, side * 42 - 8, 2, 16),
            ui.Paint()..color = const ui.Color(0x886B7064),
          );
        }
        c.restore();
      }
      part(c, 'carriage', at, const ui.Size(116, 88), yaw - math.pi / 2);
      if (feeder) {
        // Short indexed load stroke/hold, still no mortar/attack implementation.
        final stroke = mechanism < .35
            ? mechanism / .35
            : mechanism < .65
            ? 1.0
            : (1 - mechanism) / .35;
        part(
          c,
          'feeder',
          pose.socket(const ui.Offset(-20.3, 0)),
          const ui.Size(87.4, 61),
          yaw,
        );
        part(
          c,
          'feederArm',
          pose.socket(ui.Offset(42.2 + stroke * 6, 0)),
          const ui.Size(43.7, 39.1),
          yaw,
        );
      }
    }
    if (flash > 0) {
      c.save();
      c.translate(at.dx, at.dy);
      c.rotate(yaw);
      final p = ui.Paint()
        ..color = ui.Color.fromRGBO(226, 184, 113, flash * .8)
        ..strokeWidth = 3
        ..style = ui.PaintingStyle.stroke;
      c.drawRect(
        ui.Rect.fromCenter(
          center: ui.Offset.zero,
          width: 112,
          height: broken ? 27 : 116,
        ),
        p,
      );
      c.restore();
    }
    if (sockets) {
      for (final socket in [pose.front, pose.rear]) {
        c.drawRect(
          ui.Rect.fromCenter(center: socket, width: 4, height: 4),
          ui.Paint()..color = const ui.Color(0xffE2C98B),
        );
      }
    }
  }
}
