import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:regun/desktop/desktop_combat_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ControllerAction {
  fire(7),
  grenade(6),
  dash(4),
  reload(2),
  pause(9);

  const ControllerAction(this.defaultButton);
  final int defaultButton;
}

const desktopControllerButtons = [
  'A / Cross',
  'B / Circle',
  'X / Square',
  'Y / Triangle',
  'LB / L1',
  'RB / R1',
  'LT / L2',
  'RT / R2',
  'View / Share',
  'Menu / Options',
  'L3',
  'R3',
  'D-pad up',
  'D-pad down',
  'D-pad left',
  'D-pad right',
];

class DesktopBindings {
  static final shared = DesktopBindings();
  static const _storageKey = 'regun.desktop.controls.v1';

  final revision = ValueNotifier<int>(0);

  final keys = <DesktopAction, PhysicalKeyboardKey>{};
  final keyLabels = <int, String>{};
  String label(PhysicalKeyboardKey? key) {
    if (key == null) return 'None';
    final id = key.usbHidUsage;
    if (keyLabels[id] case final label?) return label;
    final letter = id - PhysicalKeyboardKey.keyA.usbHidUsage;
    if (letter >= 0 && letter < 26) return String.fromCharCode(65 + letter);
    return key == PhysicalKeyboardKey.space
        ? 'Space'
        : key.debugName ?? 'Key ${id.toRadixString(16)}';
  }

  final alternateKeys = <DesktopAction, PhysicalKeyboardKey>{};
  bool swapMouseButtons = false;
  int get mouseFire =>
      swapMouseButtons ? kSecondaryMouseButton : kPrimaryMouseButton;
  int get mouseGrenade =>
      swapMouseButtons ? kPrimaryMouseButton : kSecondaryMouseButton;
  bool matchesKey(DesktopAction action, PhysicalKeyboardKey input) =>
      key(action) == input || alternateKeys[action] == input;
  bool held(DesktopAction action, Set<PhysicalKeyboardKey> pressed) =>
      pressed.contains(key(action)) || pressed.contains(alternateKeys[action]);

  final buttons = <ControllerAction, int>{};
  double deadZone = .18;
  double sensitivity = 1;
  double crosshairScale = 1;
  bool highContrast = false;
  bool swapSticks = false;
  int frameCeiling = 120;
  static const textBaseline = 1.25;
  final uiScale = ValueNotifier<double>(1);
  PhysicalKeyboardKey key(DesktopAction action) =>
      keys[action] ?? action.defaultKey;
  int button(ControllerAction action) =>
      buttons[action] ?? action.defaultButton;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(prefs.getString(_storageKey) ?? '{}') as Map;
      for (final action in DesktopAction.values) {
        final code = (data['keys'] as Map?)?[action.name];
        if (code is int) keys[action] = PhysicalKeyboardKey(code);
      }
      for (final action in DesktopAction.values) {
        final code = (data['alternates'] as Map?)?[action.name];
        if (code is int) alternateKeys[action] = PhysicalKeyboardKey(code);
      }
      if (data['keyLabels'] case final Map labels) {
        for (final entry in labels.entries) {
          final code = int.tryParse(entry.key.toString());
          if (code != null && entry.value is String && entry.value.isNotEmpty) {
            keyLabels[code] = entry.value as String;
          }
        }
      }
      swapMouseButtons = data['swapMouseButtons'] == true;
      for (final action in ControllerAction.values) {
        final index = (data['buttons'] as Map?)?[action.name];
        if (index is int && index >= 0 && index <= 15) buttons[action] = index;
      }
      double read(String key, double fallback, double low, double high) {
        final value = data[key];
        return value is num && value.isFinite
            ? value.toDouble().clamp(low, high)
            : fallback;
      }

      deadZone = read('deadZone', .18, .08, .4);
      sensitivity = read('sensitivity', 1, .5, 2);
      crosshairScale = read('crosshairScale', 1, .75, 1.75);
      highContrast = data['highContrast'] == true;
      swapSticks = data['swapSticks'] == true;
      frameCeiling = data['frameCeiling'] == 60 ? 60 : 120;
      uiScale.value = read('uiScale', 1, .85, 1.35);
    } catch (_) {
      // A missing or invalid settings record leaves the defaults available.
    }
  }

  Future<void> save() async {
    revision.value++;
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _storageKey,
      jsonEncode({
        'keys': {
          for (final entry in keys.entries)
            entry.key.name: entry.value.usbHidUsage,
        },
        'alternates': {
          for (final entry in alternateKeys.entries)
            entry.key.name: entry.value.usbHidUsage,
        },
        'keyLabels': {
          for (final entry in keyLabels.entries)
            entry.key.toString(): entry.value,
        },
        'swapMouseButtons': swapMouseButtons,
        'buttons': {
          for (final entry in buttons.entries) entry.key.name: entry.value,
        },
        'deadZone': deadZone,
        'sensitivity': sensitivity,
        'crosshairScale': crosshairScale,
        'highContrast': highContrast,
        'swapSticks': swapSticks,
        'frameCeiling': frameCeiling,
        'uiScale': uiScale.value,
      }),
    );
    if (!saved) throw StateError('Controls storage unavailable');
  }
}
