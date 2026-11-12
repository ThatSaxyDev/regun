import 'package:flutter/services.dart';
import 'package:regun/desktop/controller_device.dart';

const _channel = MethodChannel('regun/controller');
const _events = EventChannel('regun/controller/connections');

Stream<void> controllerConnectionChanges() =>
    _events.receiveBroadcastStream().map<void>((_) {});

Future<List<ControllerDevice>?> readControllerDevices() async {
  try {
    final devices = await _channel.invokeListMethod<Object?>('read');
    if (devices == null) return null;
    return [
      for (final device in devices.cast<Map<Object?, Object?>>())
        ControllerDevice(
          device['id'] as String,
          device['name'] as String,
          (device['values'] as List)
              .cast<num>()
              .map((n) => n.toDouble())
              .toList(),
        ),
    ];
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  } on TypeError {
    return null;
  }
}
