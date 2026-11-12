import 'dart:js_interop';

import 'package:web/web.dart' as web;

void Function() watchAvailabilityFocus(void Function() onFocus) {
  final listener = ((web.Event _) => onFocus()).toJS;
  web.window.addEventListener('focus', listener);
  return () => web.window.removeEventListener('focus', listener);
}
