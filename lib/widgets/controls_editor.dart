import 'package:flutter/material.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/control_settings.dart';

const _paper = Color(0xffE5DDD1);
const _muted = Color(0xffB2A8B4);
const _panel = Color(0xf51D1821);

/// The same persisted controls are edited before a run and while paused.
class ControlsEditor extends StatelessWidget {
  const ControlsEditor({
    super.key,
    required this.layout,
    required this.onChanged,
    required this.onDone,
    required this.onArrange,
    this.showTitle = true,
  });
  final bool showTitle;
  final ControlLayout layout;
  final ValueChanged<ControlLayout> onChanged;
  final VoidCallback onDone, onArrange;
  @override
  Widget build(BuildContext context) => Container(
    width: 620,
    padding: const EdgeInsets.all(16),
    color: _panel,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle)
          const Text(
            'CONTROLS',
            style: TextStyle(
              fontFamily: FontFam.pressStart,
              fontSize: 18,
              color: _paper,
            ),
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final sliders = [
              _slider(
                'Side inset',
                layout.inset,
                64,
                160,
                (v) => layout.copyWith(inset: v),
              ),
              _slider(
                'Height',
                layout.bottom,
                60,
                140,
                (v) => layout.copyWith(bottom: v),
              ),
              _slider(
                'Control size',
                layout.size,
                88,
                112,
                (v) => layout.copyWith(size: v),
              ),
              _slider(
                'Opacity',
                layout.opacity,
                0.25,
                1,
                (v) => layout.copyWith(opacity: v),
              ),
              _slider(
                'Sensitivity',
                layout.sensitivity,
                0.6,
                1.5,
                (v) => layout.copyWith(sensitivity: v),
              ),
              _slider(
                'Dead zone',
                layout.deadZone,
                0.04,
                0.25,
                (v) => layout.copyWith(deadZone: v),
              ),
            ];
            if (constraints.maxWidth < 440) return Column(children: sliders);
            return Column(
              children: [
                for (var i = 0; i < sliders.length; i += 2)
                  Row(
                    children: [
                      Expanded(child: sliders[i]),
                      const SizedBox(width: 24),
                      Expanded(child: sliders[i + 1]),
                    ],
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final mode = Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sticks',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
                PixelOption(
                  label: 'Fixed',
                  width: 80,
                  selected: !layout.floating,
                  onTap: () => onChanged(layout.copyWith(floating: false)),
                ),
                const SizedBox(width: 8),
                PixelOption(
                  label: 'Float',
                  width: 80,
                  selected: layout.floating,
                  onTap: () => onChanged(layout.copyWith(floating: true)),
                ),
              ],
            );
            final hand = HandednessSelector(
              compact: true,
              leftHanded: layout.leftHanded,
              onChanged: (value) =>
                  onChanged(layout.copyWith(leftHanded: value)),
            );
            if (constraints.maxWidth < 500) {
              return Column(children: [mode, const SizedBox(height: 8), hand]);
            }
            return Row(
              children: [
                Expanded(child: mode),
                const SizedBox(width: 24),
                Expanded(child: hand),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: [
            ClickButton(text: 'Done', width: 120, height: 48, onTap: onDone),
            ClickButtonM(
              text: 'Arrange',
              width: 120,
              height: 48,
              onTap: onArrange,
            ),
            ClickButtonM(
              text: 'Reset',
              width: 120,
              height: 48,
              onTap: () => onChanged(const ControlLayout()),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _slider(
    String label,
    double value,
    double minimum,
    double maximum,
    ControlLayout Function(double) update,
  ) => ControlSlider(
    label: label,
    value: value,
    minimum: minimum,
    maximum: maximum,
    onChanged: (v) => onChanged(update(v)),
  );
}
