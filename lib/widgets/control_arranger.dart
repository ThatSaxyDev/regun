import 'package:flutter/material.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

class ControlArranger extends StatelessWidget {
  const ControlArranger({
    super.key,
    required this.layout,
    required this.available,
    required this.onChanged,
    required this.onDone,
  });
  final ControlLayout layout;
  final Rect available;
  final ValueChanged<ControlLayout> onChanged;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    final geometry = layout.geometry(available.size);
    final points = {
      'move': geometry.movement,
      'aim': geometry.aim,
      'dash': geometry.dash,
      'grenade': geometry.grenade,
      'reload': geometry.reload,
    };
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x880D0A10),
        child: Stack(
          children: [
            Positioned(
              top: available.top + 12,
              left: available.left + 12,
              right: 24,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'DRAG CONTROLS',
                      style: TextStyle(
                        fontFamily: FontFam.pressStart,
                        fontSize: 12,
                        color: Color(0xffE5DDD1),
                      ),
                    ),
                  ),
                  ClickButtonM(
                    text: 'Reset',
                    width: 110,
                    height: 44,
                    onTap: () =>
                        onChanged(layout.copyWith(positions: const {})),
                  ),
                  const SizedBox(width: 12),
                  ClickButton(
                    text: 'Done',
                    width: 110,
                    height: 44,
                    onTap: onDone,
                  ),
                ],
              ),
            ),
            for (final entry in points.entries)
              Positioned(
                left: available.left + entry.value.dx - 35,
                top: available.top + entry.value.dy - 35,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (event) {
                    final actual = event.globalPosition - available.topLeft;
                    final logicalX = layout.leftHanded
                        ? available.width - actual.dx
                        : actual.dx;
                    final positions = {
                      ...layout.positions,
                      entry.key: [
                        logicalX / available.width,
                        actual.dy / available.height,
                      ],
                    };
                    final next = layout.copyWith(positions: positions);
                    final resolved = next.geometry(available.size);
                    final resolvedPoint = switch (entry.key) {
                      'move' => resolved.movement,
                      'aim' => resolved.aim,
                      'dash' => resolved.dash,
                      'grenade' => resolved.grenade,
                      _ => resolved.reload,
                    };
                    // Reject overlap instead of silently putting a control on top of another.
                    if ((resolvedPoint - actual).distance < 16) {
                      onChanged(next);
                    }
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xff30272E),
                      border: Border.all(
                        color: const Color(0xffE1BA78),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: FontFam.pressStart,
                        fontSize: 8,
                        color: Color(0xffE5DDD1),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
