import 'package:flutter/material.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/control_settings.dart';
import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/settings_section.dart';

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
  Widget build(BuildContext context) => SizedBox(
    width: 620,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle) ...[
          const Text(
            'CONTROLS',
            style: TextStyle(
              fontFamily: FontFam.pressStart,
              fontSize: 18,
              color: Color(0xffE5DDD1),
            ),
          ),
          const SizedBox(height: 24),
        ],
        SettingsSection(
          title: 'Thumb layout',
          children: [
            HandednessSelector(
              leftHanded: layout.leftHanded,
              onChanged: (v) => onChanged(layout.copyWith(leftHanded: v)),
            ),
            SettingsChoice(
              label: 'Sticks',
              options: [
                PixelOption(
                  label: 'Fixed',
                  selected: !layout.floating,
                  onTap: () => onChanged(layout.copyWith(floating: false)),
                ),
                PixelOption(
                  label: 'Float',
                  selected: layout.floating,
                  onTap: () => onChanged(layout.copyWith(floating: true)),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ClickButtonM(
                text: 'Arrange',
                width: 160,
                height: 48,
                onTap: onArrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SettingsSection(
          title: 'Position & visibility',
          children: [
            MenuCardGrid(
              minColumnWidth: 240,
              maxColumns: 2,
              children: [
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
                  .25,
                  1,
                  (v) => layout.copyWith(opacity: v),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        SettingsSection(
          title: 'Stick response',
          children: [
            MenuCardGrid(
              minColumnWidth: 240,
              maxColumns: 2,
              children: [
                _slider(
                  'Sensitivity',
                  layout.sensitivity,
                  .6,
                  1.5,
                  (v) => layout.copyWith(sensitivity: v),
                ),
                _slider(
                  'Dead zone',
                  layout.deadZone,
                  .04,
                  .25,
                  (v) => layout.copyWith(deadZone: v),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ClickButton(text: 'Done', width: 120, height: 48, onTap: onDone),
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
