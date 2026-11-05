import 'dart:js_interop';

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator(JSObject _) implements JSObject {
  external JSArray<_Gamepad?> getGamepads();
}

extension type _Gamepad(JSObject _) implements JSObject {
  external JSString get mapping;
  external JSArray<JSNumber> get axes;
  external JSArray<_Button> get buttons;
}

extension type _Button(JSObject _) implements JSObject {
  external JSNumber get value;
}

Future<List<double>?> readController() async {
  try {
    for (final pad in _navigator.getGamepads().toDart) {
      if (pad == null || pad.mapping.toDart != 'standard') continue;
      final axes = pad.axes.toDart;
      final buttons = pad.buttons.toDart;
      if (axes.length < 4 || buttons.length < 16) continue;
      return [
        for (final axis in axes.take(4)) axis.toDartDouble,
        for (final button in buttons.take(16)) button.value.toDartDouble,
      ];
    }
  } catch (_) {
    // Gamepad access may be blocked by the browser or embedding policy.
  }
  return null;
}
