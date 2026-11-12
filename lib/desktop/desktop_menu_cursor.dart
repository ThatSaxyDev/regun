import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:regun/desktop/controller_menu.dart';

/// A passive pointer layer above the navigator. Combat claims the pointer
/// only while it supplies its own reticle.
class DesktopMenuCursor extends StatefulWidget {
  const DesktopMenuCursor({super.key, required this.child});

  static final combatPointer = ValueNotifier<Object?>(null);

  final Widget child;

  @override
  State<DesktopMenuCursor> createState() => _DesktopMenuCursorState();
}

class _DesktopMenuCursorState extends State<DesktopMenuCursor> {
  final _position = ValueNotifier<Offset?>(null);

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ControllerMenuMode.of(context)
              ? const SizedBox.shrink()
              : CustomPaint(painter: _MenuPointer(_position)),
        ),
      ),
      Positioned.fill(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: (event) {
            if (event.kind == PointerDeviceKind.mouse) {
              _position.value = event.localPosition;
            }
          },
          child: MouseRegion(
            opaque: false,
            hitTestBehavior: HitTestBehavior.translucent,
            cursor: SystemMouseCursors.none,
            onEnter: (event) => _position.value = event.localPosition,
            onHover: (event) => _position.value = event.localPosition,
            onExit: (_) => _position.value = null,
          ),
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }
}

class _MenuPointer extends CustomPainter {
  _MenuPointer(this.position)
    : super(
        repaint: Listenable.merge([position, DesktopMenuCursor.combatPointer]),
      );

  final ValueNotifier<Offset?> position;
  static final _plate = Path()
    ..moveTo(0, 0)
    ..lineTo(0, 18)
    ..lineTo(5, 13)
    ..lineTo(9, 19)
    ..lineTo(12, 17)
    ..lineTo(8, 11)
    ..lineTo(15, 11)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final point = position.value;
    if (point == null || DesktopMenuCursor.combatPointer.value != null) return;
    canvas.save();
    canvas.translate(point.dx.roundToDouble(), point.dy.roundToDouble());
    canvas.drawPath(
      _plate,
      Paint()
        ..color = const Color(0xff171512)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..isAntiAlias = false,
    );
    canvas.drawPath(
      _plate,
      Paint()
        ..color = const Color(0xffedc587)
        ..isAntiAlias = false,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MenuPointer oldDelegate) =>
      oldDelegate.position != position;
}
