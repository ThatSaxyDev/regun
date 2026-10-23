import 'package:regun/components/weapons/weapon_art.dart';

import 'dart:math' as math;

import 'package:regun/services/local_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/regun_art.dart';

Color? survivorTint(String style) => switch (style) {
  'copper' => const Color(0xffE9BD92),
  'moss' => const Color(0xffCAD8A3),
  'ivory' => const Color(0xffFFF4DC),
  'rust' => const Color(0xffD99B87),
  'slate' => const Color(0xffA9C3D0),
  'dusk' => const Color(0xffBCABCF),
  'shadowPalette' => const Color(0xffD7B8EA),
  'emberPalette' => const Color(0xffF2B58C),
  'engineer' => const Color(0xffF2D28D),
  _ => null,
};

class SurvivorPortrait extends StatefulWidget {
  const SurvivorPortrait({
    super.key,
    this.character = CharacterType.rook,
    this.style = 'standard',
    this.weapon,
    this.maxArtSize = 110,
    this.animated = false,
  });
  final CharacterType character;
  final WeaponType? weapon;
  final String style;
  final double maxArtSize;
  final bool animated;
  @override
  State<SurvivorPortrait> createState() => _SurvivorPortraitState();
}

class _SurvivorPortraitState extends State<SurvivorPortrait>
    with SingleTickerProviderStateMixin {
  late final clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  String? _held, _weaponHeld;
  int _epoch = 0;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _loadArt();
  }

  Future<void> _loadArt() async {
    final epoch = ++_epoch, name = 'characters/${widget.character.name}';
    final gun = widget.weapon;
    final gunAtlas = gun?.hasLeasedArt == true ? gun!.atlasName : null;
    _ready =
        RegunArt.shared.contains(name) &&
        (gun == null || RegunArt.shared.contains(gun.atlasName));
    var mainAcquired = false, gunAcquired = false;
    final jobs = [
      RegunArt.shared.acquire(name).then((_) {
        mainAcquired = true;
      }),
      if (gunAtlas != null)
        RegunArt.shared.acquire(gunAtlas).then((_) {
          gunAcquired = true;
        }),
    ];
    final old = _held, oldGun = _weaponHeld;
    _held = null;
    _weaponHeld = null;
    if (old != null) RegunArt.shared.release(old);
    if (oldGun != null) RegunArt.shared.release(oldGun);
    try {
      await Future.wait(jobs);
    } catch (_) {
      if (mainAcquired) RegunArt.shared.release(name);
      if (gunAcquired) RegunArt.shared.release(gunAtlas!);
      if (mounted && epoch == _epoch) setState(() => _ready = false);
      return;
    }
    if (!mounted || epoch != _epoch) {
      RegunArt.shared.release(name);
      if (gunAtlas != null) RegunArt.shared.release(gunAtlas);
      return;
    }
    _held = name;
    _weaponHeld = gunAtlas;
    setState(() => _ready = true);
  }

  bool get still =>
      !widget.animated ||
      LocalPreferences.shared.reducedMotion ||
      MediaQuery.disableAnimationsOf(context);
  void sync() {
    if (still) {
      clock.stop();
      clock.value = 0;
    } else if (!clock.isAnimating) {
      clock.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(SurvivorPortrait old) {
    super.didUpdateWidget(old);
    if (old.character != widget.character || old.weapon != widget.weapon) {
      _loadArt();
    }
    sync();
  }

  @override
  void dispose() {
    _epoch++;
    if (_held != null) RegunArt.shared.release(_held!);
    if (_weaponHeld != null) RegunArt.shared.release(_weaponHeld!);
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget portrait() => CustomPaint(
      painter: _Portrait(
        widget.character,
        widget.weapon,
        widget.style,
        widget.maxArtSize,
        clock,
        still,
      ),
    );
    return _ready ? portrait() : const SizedBox.shrink();
  }
}

class _Portrait extends CustomPainter {
  _Portrait(
    this.character,
    this.weapon,
    this.style,
    this.maxArtSize,
    this.clock,
    this.still,
  ) : super(repaint: clock);
  final Animation<double> clock;
  final bool still;
  final WeaponType? weapon;
  final CharacterType character;
  final String style;
  final double maxArtSize;
  @override
  void paint(Canvas canvas, Size size) {
    final edge = size.shortestSide.clamp(0.0, maxArtSize);
    canvas.save();
    canvas.translate((size.width - edge) / 2, (size.height - edge) / 2);
    if (!still) {
      canvas.translate(0, -(1 - math.cos(clock.value * math.pi * 2)) * 1.5);
    }
    final paint = Paint()..filterQuality = FilterQuality.none;
    final tint = survivorTint(style);
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    RegunArt.shared
        .survivorIdleFrame(
          character.name,
          weapon == null ? 1 : 0,
          still || clock.value < .5 ? 0 : 1,
        )
        .render(canvas, size: Vector2(edge, edge), overridePaint: paint);
    if (weapon != null) {
      canvas.save();
      canvas.translate(edge * .58, edge * .56);
      canvas.scale(edge / 100);
      paintWeapon(canvas, weapon!, reducedMotion: true);
      canvas.drawRect(
        const Rect.fromLTWH(-11, -2, 7, 7),
        Paint()..color = const Color(0xff454A43),
      );
      canvas.restore();
    }
    const brass = Color(0xffD5BA75);
    if (style == 'queenTrophy') {
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            edge * .38 + i * edge * .08,
            edge * .06 - (i == 1 ? 3 : 0),
            edge * .06,
            edge * .08,
          ),
          Paint()..color = brass,
        );
      }
    }
    if ([
      'veteran',
      'scorpionCharm',
      'eliteHunter',
      'survivor',
    ].contains(style)) {
      canvas.drawRect(
        Rect.fromLTWH(edge * .4, edge * .52, edge * .07, edge * .08),
        Paint()..color = style == 'survivor' ? const Color(0xffAABDE0) : brass,
      );
    }
    if (style == 'endless') {
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            edge * .15 + i * edge * .06,
            edge * .86,
            edge * .035,
            edge * .02,
          ),
          Paint()..color = brass.withValues(alpha: (i + 1) / 5),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Portrait old) =>
      old.character != character ||
      old.weapon != weapon ||
      old.style != style ||
      old.maxArtSize != maxArtSize ||
      old.still != still;
}
