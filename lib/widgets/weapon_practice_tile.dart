import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/weapon_thumbnail.dart';

class WeaponPracticeTile extends StatelessWidget {
  const WeaponPracticeTile({
    super.key,
    required this.weapon,
    required this.selected,
    required this.onTap,
  });
  final WeaponType weapon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onTap != null,
    label: '${weapon.title}, ${weapon.capacity} rounds',
    excludeSemantics: true,
    child: InkWell(
      excludeFromSemantics: true,
      onTap: onTap,
      child: CustomPaint(
        painter: _WeaponPlate(selected),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 52, child: WeaponThumbnail(weapon)),
              const SizedBox(height: 12),
              Text(
                weapon.title,
                style: const TextStyle(
                  fontFamily: FontFam.pressStart,
                  fontSize: 9,
                  height: 1.6,
                  color: Color(0xffE5DDD1),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selected ? 'EQUIPPED' : '${weapon.capacity} ROUNDS',
                style: TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 10,
                  color: selected
                      ? const Color(0xffE1BA78)
                      : const Color(0xffB2A8B4),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WeaponPlate extends CustomPainter {
  const _WeaponPlate(this.selected);
  final bool selected;
  @override
  void paint(Canvas canvas, Size size) {
    final path = controlPlate((Offset.zero & size).deflate(1));
    canvas.drawPath(
      path,
      Paint()
        ..color = selected ? const Color(0xff3B3027) : const Color(0xff241F29),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = selected ? const Color(0xffE1BA78) : const Color(0xff665A68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1,
    );
  }

  @override
  bool shouldRepaint(_WeaponPlate oldDelegate) =>
      selected != oldDelegate.selected;
}
