import 'package:flutter/material.dart';
import 'package:regun/utils/constants.dart';

/// One compact row per encounter; no opaque combat-sized title plate.
class BossHealthStrip extends StatelessWidget {
  const BossHealthStrip({
    super.key,
    required this.name,
    required this.fraction,
    this.enraged = false,
  });
  final String name;
  final double fraction;
  final bool enraged;
  @override
  Widget build(BuildContext context) => Semantics(
    excludeSemantics: true,
    label:
        '$name${enraged ? ', enraged' : ''}, ${(fraction * 100).round()} percent health',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xffE8E4D8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 4,
              color: enraged
                  ? const Color(0xffE69A72)
                  : const Color(0xffC782A3),
              backgroundColor: const Color(0x99392B3D),
            ),
          ),
          if (enraged)
            const Padding(
              padding: EdgeInsets.only(left: 5),
              child: Icon(
                Icons.priority_high,
                size: 12,
                color: Color(0xffE69A72),
              ),
            ),
        ],
      ),
    ),
  );
}
