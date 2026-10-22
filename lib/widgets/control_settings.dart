import 'package:regun/presentation/game_layout.dart';
import 'package:flutter/material.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';

const _accent = Color(0xffE1BA78);
const _ink = Color(0xffDED4C5);

class HandednessSelector extends StatelessWidget {
  const HandednessSelector({
    super.key,
    required this.leftHanded,
    required this.onChanged,
    this.compact = false,
  });
  final bool leftHanded, compact;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SettingsChoice(
    label: 'Aim hand',
    options: [
      PixelOption(
        label: 'Right',
        width: compact ? 80 : 104,
        selected: !leftHanded,
        onTap: () => onChanged(false),
      ),
      PixelOption(
        label: 'Left',
        width: compact ? 80 : 104,
        selected: leftHanded,
        onTap: () => onChanged(true),
      ),
    ],
  );
}

/// Labels keep their own line when the available width or larger text needs it.
class SettingsChoice extends StatelessWidget {
  const SettingsChoice({super.key, required this.label, required this.options});
  final String label;
  final List<Widget> options;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final text = Text(
        label,
        style: const TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: 13,
          height: 1.5,
          color: _ink,
        ),
      );
      final choices = Wrap(spacing: 8, runSpacing: 8, children: options);
      if (box.maxWidth <
          420 * MediaQuery.textScalerOf(context).scale(12) / 12) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [text, const SizedBox(height: 12), choices],
        );
      }
      return Row(
        children: [
          Expanded(child: text),
          const SizedBox(width: 16),
          choices,
        ],
      );
    },
  );
}

class PixelOption extends StatefulWidget {
  const PixelOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.width = 104,
  });
  final String label;
  final double width;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<PixelOption> createState() => PixelOptionState();
}

class PixelOptionState extends State<PixelOption> {
  bool _pressed = false;
  bool _focused = false;
  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    button: true,
    selected: widget.selected,
    onTap: widget.onTap,
    child: SizedBox(
      width: widget.width,
      height: 48,
      child: InkWell(
        excludeFromSemantics: true,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onFocusChange: (value) => setState(() => _focused = value),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: CustomPaint(
          painter: _SelectionPlate(
            selected: widget.selected,
            pressed: _pressed,
            focused: _focused,
          ),
          child: ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.only(left: 14, top: _pressed ? 3 : 0),
              child: Center(
                child: Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: FontFam.pressStart,
                    fontSize: 9,
                    color: widget.selected ? _accent : _ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SelectionPlate extends CustomPainter {
  const _SelectionPlate({
    required this.selected,
    required this.pressed,
    required this.focused,
  });
  final bool selected, pressed, focused;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      1,
      pressed ? 3 : 1,
      size.width - 2,
      size.height - 5,
    );
    canvas.drawPath(
      controlPlate(rect.shift(const Offset(0, 3))),
      Paint()..color = const Color(0xff100D14),
    );
    canvas.drawPath(
      controlPlate(rect),
      Paint()
        ..color = selected ? const Color(0xff3B3027) : const Color(0xff241F29),
    );
    canvas.drawPath(
      controlPlate(rect.deflate(0.75)),
      Paint()
        ..color = selected || focused ? _accent : const Color(0xff665A68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 2 : 1.5,
    );
    final mark = Rect.fromLTWH(10, rect.center.dy - 4, 8, 8);
    canvas.drawRect(
      mark,
      Paint()..color = selected ? _accent : const Color(0xff151219),
    );
    if (selected) {
      canvas.drawRect(
        Rect.fromLTWH(mark.left + 2, mark.top + 3, 2, 3),
        Paint()..color = const Color(0xff30251D),
      );
      canvas.drawRect(
        Rect.fromLTWH(mark.left + 4, mark.top + 1, 2, 5),
        Paint()..color = const Color(0xff30251D),
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left + 9, rect.top + 4, rect.width - 18, 2),
        Paint()..color = _accent,
      );
    }
  }

  @override
  bool shouldRepaint(_SelectionPlate oldDelegate) =>
      selected != oldDelegate.selected ||
      pressed != oldDelegate.pressed ||
      focused != oldDelegate.focused;
}

class ControlSlider extends StatelessWidget {
  const ControlSlider({
    super.key,
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });
  final String label;
  final double value, minimum, maximum;
  final ValueChanged<double> onChanged;

  String _format(double v, {double displayScale = 1}) => maximum <= 1
      ? '${(v * 100).round()}%'
      : label == 'Sensitivity'
      ? '${v.toStringAsFixed(2)}×'
      : '${(v * displayScale).round()} px';
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: FontFam.orbitron,
                color: _ink,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _format(
              value,
              displayScale: GameLayout.uiScale(MediaQuery.sizeOf(context)),
            ),
            style: const TextStyle(
              fontFamily: FontFam.orbitron,
              color: _accent,
              fontSize: 12,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 48,
        child: Semantics(
          label: label,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: _accent,
              inactiveTrackColor: const Color(0xff4A3D48),
              thumbColor: _accent,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const _PixelSliderThumb(),
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              value: value,
              min: minimum,
              max: maximum,
              onChanged: onChanged,
              semanticFormatterCallback: (v) => _format(
                v,
                displayScale: GameLayout.uiScale(MediaQuery.sizeOf(context)),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _PixelSliderThumb extends SliderComponentShape {
  const _PixelSliderThumb();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(18, 22);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final rect = Rect.fromCenter(center: center, width: 18, height: 22);
    context.canvas.drawPath(
      controlPlate(rect, cut: 3),
      Paint()..color = const Color(0xff30252A),
    );
    context.canvas.drawPath(
      controlPlate(rect.deflate(1), cut: 2),
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final x in [-3.0, 2.0]) {
      context.canvas.drawRect(
        Rect.fromLTWH(center.dx + x, center.dy - 5, 2, 10),
        Paint()..color = _accent,
      );
    }
  }
}
