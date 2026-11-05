import 'package:flutter/services.dart';

const _channel = MethodChannel('regun/controller');

Future<List<double>?> readController() async {
  try {
    final values = await _channel.invokeListMethod<num>('read');
    return values?.map((value) => value.toDouble()).toList();
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}
