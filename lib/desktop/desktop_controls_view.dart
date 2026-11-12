import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regun/desktop/desktop_bindings.dart';
import 'package:regun/desktop/desktop_combat_input.dart';
import 'package:regun/desktop/desktop_controller.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/control_settings.dart';
import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/settings_section.dart';

class DesktopControlsView extends StatefulWidget {
  const DesktopControlsView({super.key});

  @override
  State<DesktopControlsView> createState() => _DesktopControlsViewState();
}

class _DesktopControlsViewState extends State<DesktopControlsView> {
  final bindings = DesktopBindings.shared;
  bool controller = false;
  String? issue;

  Future<void> _change(VoidCallback change) async {
    setState(change);
    try {
      await bindings.save();
    } catch (_) {
      if (mounted) setState(() => issue = 'Could not save controls.');
    }
  }

  Future<void> _key(DesktopAction action, {bool alternate = false}) async {
    final input = await showDialog<KeyDownEvent>(
      context: context,
      builder: (context) => Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
          } else if (!HardwareKeyboard.instance.isControlPressed &&
              !HardwareKeyboard.instance.isMetaPressed &&
              !HardwareKeyboard.instance.isAltPressed) {
            Navigator.pop(context, event);
          }
          return KeyEventResult.handled;
        },
        child: AlertDialog(
          title: Text(
            alternate ? 'Alternate ${action.name}' : 'Bind ${action.name}',
          ),
          content: const Text('Press a key. Esc cancels.'),
          actions: [
            ClickButton(text: 'Cancel', onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
    if (!mounted || input == null) return;
    final key = input.physicalKey;
    if (bindings.matchesKey(action, key)) return;
    final conflict = DesktopAction.values
        .where((other) => other != action && bindings.matchesKey(other, key))
        .firstOrNull;
    if (conflict != null) {
      if (alternate || bindings.alternateKeys[conflict] == key) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Key already assigned'),
            content: Text('This key is assigned to ${conflict.name}.'),
            actions: [
              ClickButton(
                text: 'Back',
                autofocus: true,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        return;
      }
      if (!await _swap(conflict.name)) return;
    }
    if (!mounted) return;
    await _change(() {
      if (conflict != null) bindings.keys[conflict] = bindings.key(action);
      final label = input.logicalKey.keyLabel.trim();
      if (label.isNotEmpty) bindings.keyLabels[key.usbHidUsage] = label;
      if (alternate) {
        bindings.alternateKeys[action] = key;
      } else {
        bindings.keys[action] = key;
      }
    });
  }

  Future<void> _button(ControllerAction action) async {
    final button = await showDialog<int>(
      context: context,
      builder: (context) => _ControllerCapture(action: action),
    );
    if (!mounted || button == null || button == bindings.button(action)) return;
    final conflict = ControllerAction.values
        .where((other) => other != action && bindings.button(other) == button)
        .firstOrNull;
    if (conflict != null && !await _swap(conflict.name)) return;
    if (!mounted) return;
    await _change(() {
      if (conflict != null) {
        bindings.buttons[conflict] = bindings.button(action);
      }
      bindings.buttons[action] = button;
    });
  }

  Future<bool> _swap(String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Swap bindings?'),
          content: Text('This input is assigned to $action.'),
          actions: [
            ClickButton(text: 'Cancel', onTap: () => Navigator.pop(context)),
            ClickButton(
              text: 'Swap',
              autofocus: true,
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final profile = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        PixelOption(
          label: 'Keyboard & Mouse',
          width: 210,
          selected: !controller,
          onTap: () => setState(() => controller = false),
        ),
        PixelOption(
          label: 'Controller',
          width: 140,
          selected: controller,
          onTap: () => setState(() => controller = true),
        ),
      ],
    );
    final actions = SettingsSection(
      title: controller ? 'Controller bindings' : 'Key bindings',
      children: [
        if (controller) ...[
          for (final action in ControllerAction.values)
            ClickButton(
              text:
                  '${action.name} · ${desktopControllerButtons[bindings.button(action)]}',
              onTap: () => _button(action),
            ),
        ] else ...[
          for (final action in DesktopAction.values)
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    action.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: FontFam.orbitron,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffe5ddd1),
                    ),
                  ),
                ),
                Expanded(
                  child: ClickButton(
                    height: 40,
                    text: bindings.label(bindings.key(action)),
                    onTap: () => _key(action),
                  ),
                ),
                Expanded(
                  child: ClickButton(
                    height: 40,
                    text:
                        'Alt · ${bindings.label(bindings.alternateKeys[action])}',
                    onTap: () => _key(action, alternate: true),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: bindings.alternateKeys.containsKey(action)
                      ? ClickButton(
                          height: 36,
                          text: 'Clear alt',
                          iconOnly: true,
                          glyph: PixelGlyph.cross,
                          onTap: () => _change(
                            () => bindings.alternateKeys.remove(action),
                          ),
                        )
                      : null,
                ),
              ],
            ),
        ],
      ],
    );
    final tuning = SettingsSection(
      title: controller ? 'Stick response' : 'Mouse and crosshair',
      children: [
        if (controller) ...[
          ControlSlider(
            label: 'Stick dead zone',
            value: bindings.deadZone,
            minimum: .08,
            maximum: .4,
            onChanged: (value) => _change(() => bindings.deadZone = value),
          ),
          ControlSlider(
            label: 'Sensitivity',
            value: bindings.sensitivity,
            minimum: .5,
            maximum: 2,
            onChanged: (value) => _change(() => bindings.sensitivity = value),
          ),
          ClickButton(
            text: bindings.swapSticks ? 'Sticks swapped' : 'Sticks standard',
            onTap: () =>
                _change(() => bindings.swapSticks = !bindings.swapSticks),
          ),
        ] else ...[
          ClickButton(
            text: bindings.swapMouseButtons
                ? 'Mouse fire · Right'
                : 'Mouse fire · Left',
            onTap: () => _change(
              () => bindings.swapMouseButtons = !bindings.swapMouseButtons,
            ),
          ),
          ClickButton(
            text:
                'Crosshair size · ${(bindings.crosshairScale * 100).round()}%',
            onTap: () => _change(
              () => bindings.crosshairScale = bindings.crosshairScale >= 1.75
                  ? .75
                  : bindings.crosshairScale + .25,
            ),
          ),
          ClickButton(
            text: bindings.highContrast ? 'Contrast high' : 'Contrast standard',
            onTap: () =>
                _change(() => bindings.highContrast = !bindings.highContrast),
          ),
        ],
        Text(
          controller
              ? 'Hold Grenade. Push the aim stick farther for a longer throw.'
              : 'Hold ${bindings.swapMouseButtons ? 'left' : 'right'} click or the grenade key. Move the cursor to set range.',
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: 12,
            height: 1.5,
            color: Color(0xffc7b9a6),
          ),
        ),
        ClickButton(
          text: 'Reset defaults',
          onTap: () => _change(() {
            if (controller) {
              bindings.buttons.clear();
              bindings.deadZone = .18;
              bindings.sensitivity = 1;
              bindings.swapSticks = false;
            } else {
              bindings.keys.clear();
              bindings.keyLabels.clear();
              bindings.alternateKeys.clear();
              bindings.swapMouseButtons = false;
              bindings.crosshairScale = 1;
              bindings.highContrast = false;
            }
          }),
        ),
        if (issue case final message?)
          Text(message, style: const TextStyle(color: Color(0xffe1ba78))),
      ],
    );
    return MenuPage(
      title: 'CONTROLS',
      desktopMaxWidth: 980,
      navigation: profile,
      body: MenuScrollBody(
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth < 690) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 28,
                children: [actions, tuning],
              );
            }
            return Row(
              spacing: 32,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: actions),
                Expanded(flex: 2, child: tuning),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ControllerCapture extends StatefulWidget {
  const _ControllerCapture({required this.action});

  final ControllerAction action;

  @override
  State<_ControllerCapture> createState() => _ControllerCaptureState();
}

class _ControllerCaptureState extends State<_ControllerCapture> {
  bool armed = false;
  bool done = false;
  late final ControllerHandler handler = _capture;

  bool _capture(ControllerFrame? frame) {
    if (frame == null || done) return true;
    final held = [
      for (var i = 0; i < desktopControllerButtons.length; i++)
        if (frame.pressed(i)) i,
    ];
    if (held.isEmpty) armed = true;
    if (armed && held.length == 1) {
      done = true;
      Navigator.pop(context, held.single == 1 ? null : held.single);
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    DesktopController.handlers.add(handler);
  }

  @override
  void dispose() {
    DesktopController.handlers.remove(handler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Bind ${widget.action.name}'),
    content: const Text('Press a controller button. B / Circle cancels.'),
    actions: [
      ClickButton(
        text: 'Cancel',
        autofocus: true,
        onTap: () => Navigator.pop(context),
      ),
    ],
  );
}
