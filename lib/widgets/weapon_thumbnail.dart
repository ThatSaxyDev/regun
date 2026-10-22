import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/presentation/weapon_art_spec.dart';

/// Catalog art shares gameplay's exact weapon silhouette and leases only while mounted.
class WeaponThumbnail extends StatelessWidget {
  const WeaponThumbnail(this.weapon, {super.key});
  final WeaponType weapon;
  @override
  Widget build(BuildContext context) =>
      _WeaponArt(weapon, key: ValueKey(weapon));
}

class _WeaponArt extends StatefulWidget {
  const _WeaponArt(this.weapon, {super.key});
  final WeaponType weapon;
  @override
  State<_WeaponArt> createState() => _WeaponArtState();
}

class _WeaponArtState extends State<_WeaponArt> {
  bool ready = false, held = false;
  @override
  void initState() {
    super.initState();
    ready =
        !widget.weapon.hasLeasedArt &&
        RegunArt.shared.contains(widget.weapon.atlasName);
    _load();
  }

  Future<void> _load() async {
    await RegunArt.shared.load();
    if (widget.weapon.hasLeasedArt) {
      await RegunArt.shared.acquire(widget.weapon.atlasName);
      if (!mounted) {
        RegunArt.shared.release(widget.weapon.atlasName);
        return;
      }
      held = true;
    }
    if (mounted) setState(() => ready = true);
  }

  @override
  void dispose() {
    if (held) RegunArt.shared.release(widget.weapon.atlasName);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ready
      ? CustomPaint(painter: _WeaponPreview(widget.weapon))
      : const SizedBox.expand();
}

class _WeaponPreview extends CustomPainter {
  const _WeaponPreview(this.weapon);
  final WeaponType weapon;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final feel = WeaponFeel.of(weapon);
    final height = WeaponArtSpec.of(weapon).height;
    final scale = math.min(
      (size.width - 4) / feel.width,
      (size.height - 4) / height,
    );
    canvas.translate(
      size.width / 2 + scale * feel.width * (feel.grip - .5),
      size.height / 2 + scale * height * .05,
    );
    canvas.scale(scale);
    paintWeapon(canvas, weapon);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WeaponPreview oldDelegate) =>
      oldDelegate.weapon != weapon;
}
