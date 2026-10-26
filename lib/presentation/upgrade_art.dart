import 'package:regun/models/upgrade_animation_recipe.dart';
import 'package:regun/systems/support_rewards.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/upgrade_presentation.dart';

/// One owner, one selected-survivor recipe; pending loads retire with the owner.
class UpgradeArtLease {
  UpgradeArtLease({RegunArt? art}) : _art = art ?? RegunArt.shared;
  final RegunArt _art;
  static const atlas = 'upgrades/rook_infusion';
  static const columns = 8;
  static const familyAtlases = {
    'heavyLoad': atlas,
    'walkingSpeedIncrease': 'upgrades/rook_fleet',
    'scrapArmour': 'upgrades/rook_armour',
    'hotShot': 'upgrades/rook_ember',
    'ricochet': 'upgrades/rook_ricochet',
    'support:sentry': 'upgrades/rook_sentry',
  };
  static String familyFor(String id) => upgradeAnimationRecipe(id);
  static String atlasFor(String family) =>
      familyAtlases[familyFor(family)] ?? atlas;
  final _recipes = <String, _UpgradeRecipeLease>{};
  bool get held => _recipes.values.any((r) => r.held);
  bool get ready => readyFor('heavyLoad');
  bool readyFor(String family) => _recipes[atlasFor(family)]?.ready ?? false;

  /// Only offered/accepted recipes are retained. Retired pending loads release
  /// themselves; a later picker never inherits a stale owner.
  void prewarm([Iterable<String> families = const ['heavyLoad']]) {
    final wanted = families
        .map(familyFor)
        .where(familyAtlases.containsKey)
        .map(atlasFor)
        .toSet();
    for (final key in _recipes.keys.toList()) {
      if (!wanted.contains(key)) _recipes.remove(key)!.clear();
    }
    for (final key in wanted) {
      (_recipes[key] ??= _UpgradeRecipeLease(_art, key)).prewarm();
    }
  }

  void clear() {
    for (final recipe in _recipes.values) {
      recipe.clear();
    }
    _recipes.clear();
  }
}

class _UpgradeRecipeLease {
  _UpgradeRecipeLease(this._art, this.atlas);
  final RegunArt _art;
  final String atlas;
  int _epoch = 0;
  bool held = false, _pending = false, _wanted = false;
  bool get ready => held && _art.contains(atlas);
  void prewarm() {
    _wanted = true;
    if (held || _pending) return;
    final epoch = _epoch;
    _pending = true;
    unawaited(
      _art
          .acquire(atlas)
          .then((_) {
            if (!_wanted || epoch != _epoch) {
              _art.release(atlas);
            } else {
              held = true;
            }
            _pending = false;
            if (_wanted && !held) prewarm();
          })
          .catchError((Object error) {
            _pending = false;
          }),
    );
  }

  void clear() {
    _wanted = false;
    _epoch++;
    if (held) _art.release(atlas);
    held = false;
  }
}

Color upgradeInfusionColor(String family) {
  if ({
        'healthIncrease',
        'fieldMedic',
        'salvage',
        'support:aura',
      }.contains(family) ||
      family.startsWith('support:aura:')) {
    return const Color(0xffb6cda0);
  }
  if ({
    'staticCharge',
    'conductiveCore',
    'faradayReserve',
    'stormCircuit',
    'groundWire',
  }.contains(family)) {
    return const Color(0xffb1d1cc);
  }
  if (family == 'exposedSeam') return const Color(0xffb4d2d4);
  return switch (upgradeAnimationRecipe(family)) {
    'hotShot' => const Color(0xffd99869),
    'walkingSpeedIncrease' => const Color(0xffb4c7a5),
    'scrapArmour' => const Color(0xffb8c4bd),
    'ricochet' => const Color(0xffc8bd91),
    'support:sentry' => const Color(0xffa9bdb8),
    _ => const Color(0xffdfbd78),
  };
}

/// Family currents stay local to the frozen performance. No world entities,
/// shield boundaries, fake bullets, companion copies or gameplay effects.
void _paintFamilyInfusion(
  Canvas canvas,
  String family,
  double p,
  bool foreground,
  bool reduced, {
  Color? tint,
}) {
  final warm = tint ?? upgradeInfusionColor(family);
  void chip(
    Offset point,
    double width,
    double height,
    double alpha, {
    bool dark = false,
  }) {
    if (alpha <= 0) return;
    final r = Rect.fromCenter(
      center: Offset(point.dx.roundToDouble(), point.dy.roundToDouble()),
      width: width,
      height: height,
    );
    canvas.drawRect(
      r.inflate(2),
      Paint()
        ..color = const Color(0xff33372f)
            .withValues(alpha: alpha.clamp(0, 1) * .8),
    );
    canvas.drawRect(
      r,
      Paint()
        ..color = (dark ? const Color(0xff6c756c) : warm).withValues(
          alpha: alpha.clamp(0, 1),
        ),
    );
    if (!dark && width >= 5) {
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.top, width - 2, 2),
        Paint()
          ..color = const Color(0xffe5dcc5)
              .withValues(alpha: alpha.clamp(0, 1) * .7),
      );
    }
  }

  final charge = reduced ? .65 : (p / .94).clamp(0.0, 1.0);
  if (reduced) {
    if (!foreground) return;
    switch (family) {
      case 'walkingSpeedIncrease':
        for (final x in [-12.0, 12.0]) {
          chip(Offset(x, 30), 11, 3, charge);
        }
      case 'scrapArmour':
        chip(const Offset(0, 1), 19, 13, charge, dark: true);
        chip(const Offset(0, -4), 15, 3, charge);
      case 'hotShot':
        for (final x in [-6.0, 0.0, 6.0]) {
          chip(Offset(x, 1), 3, 7, charge);
        }
      case 'ricochet':
        for (var i = 0; i < 3; i++) {
          chip(Offset(-7 + i * 6, -4 + i * 4), 5, 3, charge);
        }
      case 'support:sentry':
        for (var i = 0; i < 3; i++) {
          chip(Offset(-8 + i * 8, 3), 4, 4, charge);
        }
    }
    return;
  }
  if (foreground) {
    switch (family) {
      case 'walkingSpeedIncrease':
        for (final x in [-12.0, 12.0]) {
          for (var i = 0; i < 3; i++) {
            chip(
              Offset(x, 30 - i * 9.0),
              9 - i * 2.0,
              3,
              charge * (1 - i * .2),
            );
          }
        }
      case 'scrapArmour':
        chip(const Offset(0, 1), 21, 15, charge * .65, dark: true);
        chip(const Offset(-8, -1), 3, 13, charge);
        chip(const Offset(8, -1), 3, 13, charge);
        chip(const Offset(0, -6), 15, 3, charge);
      case 'hotShot':
        for (var i = 0; i < 7; i++) {
          final a = i * 2.4;
          chip(
            Offset(math.cos(a) * 13, math.sin(a) * 8),
            i.isEven ? 5 : 3,
            4,
            charge * .8,
          );
        }
      case 'ricochet':
        for (var i = 0; i < 5; i++) {
          chip(Offset(-12 + i * 6.0, i.isEven ? -5 : 1), 5, 3, charge * .8);
        }
      case 'support:sentry':
        for (var i = 0; i < 3; i++) {
          chip(Offset(-9 + i * 9.0, 3), 5, 5, charge);
          chip(Offset(-9 + i * 9.0, -3), 3, 2, charge * .6);
        }
    }
    return;
  }
  final count = family == 'scrapArmour'
      ? 8
      : family == 'hotShot'
      ? 24
      : 12;
  for (var i = 0; i < count; i++) {
    final t = ((p - (i % 4) * .018) / .90).clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) continue;
    final opacity = math.min(1.0, t * 8) * math.min(1.0, (1 - t) * 10);
    Offset at(double q) {
      final inward = 1 - q * q;
      switch (family) {
        case 'walkingSpeedIncrease':
          final side = i.isEven ? -1.0 : 1.0;
          return Offset(
            side * (12 + 100 * inward),
            30 + math.sin(q * math.pi) * (15 + i % 3 * 4),
          );
        case 'scrapArmour':
          final a = i * math.pi / 4;
          return Offset(
            math.cos(a) * (8 + 105 * inward),
            math.sin(a) * (5 + 65 * inward),
          );
        case 'hotShot':
          final a = i * 2.4 + q * 2.2;
          return Offset(math.cos(a) * 105 * inward, math.sin(a) * 70 * inward);
        case 'ricochet':
          // Angular inward route: three committed bends ending at the chest.
          final side = i.isEven ? -1.0 : 1.0;
          final points = [
            Offset(side * 115, -52 + i % 3 * 30.0),
            Offset(side * 58, 35),
            Offset(-side * 28, -20),
            Offset.zero,
          ];
          final segment = math.min(2, (q * 3).floor());
          return Offset.lerp(
            points[segment],
            points[segment + 1],
            q * 3 - segment,
          )!;
        default:
          // Compact stepped signal packets, ending in the palm/chest command.
          final side = i.isEven ? -1.0 : 1.0;
          final x = side * 110 * inward;
          final y = q < .45 ? -35 + i % 3 * 25.0 : (1 - q) * (i % 3 - 1) * 30;
          return Offset(x, y);
      }
    }

    final width = family == 'scrapArmour'
        ? 13.0
        : family == 'hotShot'
        ? 4.0
        : 7.0;
    final height = family == 'scrapArmour'
        ? 8.0
        : family == 'walkingSpeedIncrease'
        ? 3.0
        : 5.0;
    if (family != 'scrapArmour') {
      for (var trail = 3; trail > 0; trail--) {
        chip(
          at(math.max(0, t - trail * .035)),
          width - 2,
          height - 1,
          opacity * (1 - trail * .23),
        );
      }
    }
    chip(at(t), width, height, opacity);
  }
}

/// Local cosmetic absorption, never a blast, shield or damage geometry.
/// Render in two layers around the authored body so the power enters the torso.
void paintUpgradeInfusion(
  Canvas canvas,
  String family,
  double progress, {
  required bool reducedMotion,
  required bool foreground,
}) {
  _paintUpgradeInfusion(
    canvas,
    upgradeAnimationRecipe(family),
    progress,
    tint: upgradeInfusionColor(family),
    reducedMotion: reducedMotion,
    foreground: foreground,
  );
}

void _paintUpgradeInfusion(
  Canvas canvas,
  String family,
  double progress, {
  Color? tint,
  required bool reducedMotion,
  required bool foreground,
}) {
  if (family != 'heavyLoad') {
    _paintFamilyInfusion(
      canvas,
      family,
      progress.clamp(0.0, 1.0),
      foreground,
      reducedMotion,
      tint: tint,
    );
    return;
  }
  final warm = tint ?? upgradeInfusionColor(family);
  final ink = Paint();
  void pixel(double x, double y, double w, double h, Color c, double alpha) {
    ink.color = c.withValues(alpha: alpha.clamp(0, 1));
    canvas.drawRect(
      Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), w, h),
      ink,
    );
  }

  if (reducedMotion) {
    // Stable warm seams, no inward flight, flash, expansion or body sweep.
    if (foreground) {
      pixel(-12, -10, 3, 17, warm, .65);
      pixel(9, -10, 3, 17, warm, .65);
      pixel(-8, 8, 16, 3, warm, .5);
    }
    return;
  }
  final p = progress.clamp(0.0, 1.0);
  if (!foreground) {
    // Three broken, stepped currents converge on the torso. Their leading
    // tips travel inward; none expands outward like a damaging explosion.
    for (var stream = 0; stream < 3; stream++) {
      final t = ((p - stream * .018) / .90).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final angle = -2.65 + stream * 2.1;
      final distance = 108 * (1 - t * t);
      final opacity = math.min(1.0, t * 9) * math.min(1.0, (1 - t) * 8);
      for (var j = 7; j >= 0; j--) {
        final d = distance + j * 5;
        final bend = (j.isEven ? 1 : -1) * (3 + j * .5);
        final x = math.cos(angle) * d - math.sin(angle) * bend;
        final y = math.sin(angle) * d * .7 + math.cos(angle) * bend;
        pixel(x - 3, y - 3, 9, 7, const Color(0xff6b5941), opacity * .75);
        pixel(
          x,
          y,
          j < 3 ? 6 : 4,
          j < 3 ? 5 : 3,
          warm,
          opacity * (1 - j * .07),
        );
        if (j < 4) pixel(x + 1, y, 2, 3, const Color(0xfff1d7a2), opacity);
      }
    }
    // Staggered iron/brass splinters accelerate inward; their trails point
    // OUTWARD, making absorption distinct from the recovery pulse on resume.
    for (var i = 0; i < 18; i++) {
      final start = (i % 6) * .018;
      final t = ((p - start) / .84).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final angle = i * 2.399963 + .3;
      final reach = 86.0 + (i % 3) * 16;
      final distance = reach * (1 - t * t * t);
      final alpha = math.min(1.0, t * 7) * math.min(1.0, (1 - t) * 9);
      for (var trail = 3; trail >= 0; trail--) {
        final d = distance + trail * (4 + t * 6);
        pixel(
          math.cos(angle) * d,
          math.sin(angle) * d * .68,
          trail == 0 ? 5 : 3,
          trail == 0 ? 5 : 3,
          trail == 0 ? warm : const Color(0xff8c795a),
          alpha * (1 - trail * .23),
        );
      }
    }
  } else {
    // Short chest/arm seams read as contained power, never an immunity bubble.
    final charge = (p / .94).clamp(0.0, 1.0);
    if (charge <= 0) return;
    pixel(-11, -9, 4, 20, warm, charge * .85);
    pixel(8, -9, 4, 20, warm, charge * .85);
    pixel(-7, -3, 14, 4, const Color(0xfff2d6a0), charge * .8);
    for (final side in [-1, 1]) {
      pixel(side * 22.0 - 2, -5, 4, 10, warm, charge * .6);
      pixel(side * 28.0 - 2, 2, 4, 7, warm, charge * .4);
    }
  }
}

/// The contained charge breaks outward only when the real recovery pulse fires.
/// This small actor accent does not add a second blast or imply extra reach.
void paintUpgradeRelease(
  Canvas canvas,
  String family,
  double age, {
  required bool reducedMotion,
}) {
  if (age < 0 || age >= .24) return;
  final warm = upgradeInfusionColor(family);
  final t = (age / .24).clamp(0.0, 1.0);
  final fade = (1 - t) * (1 - t);
  if (reducedMotion) {
    canvas.drawRect(
      const Rect.fromLTWH(-8, -6, 16, 3),
      Paint()..color = warm.withValues(alpha: fade * .35),
    );
    return;
  }
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4 + .18;
    final d = 18 + 58 * (1 - math.pow(1 - t, 2));
    final x = (math.cos(angle) * d).roundToDouble();
    final y = (math.sin(angle) * d * .65).roundToDouble();
    final rect = Rect.fromCenter(
      center: Offset(x, y),
      width: i.isEven ? 10 : 6,
      height: 5,
    );
    canvas.drawRect(
      rect.inflate(2),
      Paint()..color = const Color(0xff30372c).withValues(alpha: fade),
    );
    canvas.drawRect(rect, Paint()..color = warm.withValues(alpha: fade));
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, 4, 2),
      Paint()..color = const Color(0xfff0dfb6).withValues(alpha: fade),
    );
  }
}

/// Dedicated slot: independent of combat-effect cap; below damage/controls.
class UpgradeConfirmationView extends Component
    with HasGameReference<RegunGame> {
  UpgradeConfirmationView() : super(priority: 50);
  @override
  void render(Canvas canvas) {
    final c = game.upgradePresentation;
    if (c.holding && !game.preferences.reducedMotion) {
      final bounds = Offset.zero & game.camera.viewport.virtualSize.toSize();
      final body = game.camera.viewfinder.localToGlobal(game.myPlayer.position);
      // Constant focus while frozen, then soften back on the final settle.
      // No flash, zoom, camera displacement or opaque hiding of threats.
      final shade = .32 * ((1 - c.progress) / .18).clamp(0.0, 1.0);
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = ui.Gradient.radial(
            body.toOffset(),
            230,
            [const Color(0x00161b18), Color.fromRGBO(13, 18, 16, shade)],
            [.18, 1],
          ),
      );
    }
    if (const bool.fromEnvironment('REGUN_UPGRADE_HIDE_LABELS')) return;
    if ((!c.visible && c.actualUse == null) ||
        (c.receipt == null && c.actualUse == null)) {
      return;
    }
    // Let the character performance carry the frozen beat. Readout follows it.
    if (c.holding) return;
    final r = c.receipt;
    final p = PowerUp.values.where((p) => p.name == r?.id).firstOrNull;
    final ranks = ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];
    final fusion = fusionRecipes.where((f) => f.id == r?.id).firstOrNull;
    final support = r == null ? null : SupportCard.read(r.id);
    final title = p?.title ?? fusion?.title ?? support?.title ?? 'Upgrade';
    final label =
        c.actualUse ??
        '${title.toUpperCase()} ${ranks[r!.afterRank.clamp(0, 8)]}';
    final alpha = c.actualUse != null || c.holding
        ? 1.0
        : ((c.duration + .7 - c.elapsed) / .35).clamp(0.0, 1.0);
    final center = game.camera.viewport.virtualSize.x / 2;
    final width = math.min(600.0, game.camera.viewport.virtualSize.x - 200);
    final rect = Rect.fromCenter(
      center: Offset(center, 112),
      width: width,
      height: c.actualUse == null ? 66 : 34,
    );
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xff202721).withValues(alpha: alpha * .9),
    );
    void text(String value, double y, double size, Color color) {
      final t = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: size,
            color: color.withValues(alpha: alpha),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: width - 20);
      t.paint(canvas, Offset(center - t.width / 2, y));
    }

    text(label, rect.top + 6, 22, const Color(0xffd1c2a2));
    if (c.actualUse == null) {
      text(upgradeReceiptDelta(r!), rect.top + 34, 22, const Color(0xffb4bcaa));
    }
  }
}
