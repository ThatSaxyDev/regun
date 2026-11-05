import 'dart:js_interop';

@JS('document')
external _Document get _document;

extension type _Document(JSObject _) implements JSObject {
  external JSObject? get fullscreenElement;
  external _Element get documentElement;
  external JSPromise<JSAny?> exitFullscreen();
}

extension type _Element(JSObject _) implements JSObject {
  external JSPromise<JSAny?> requestFullscreen();
}

Future<bool> toggleDesktopFullscreen() async {
  if (_document.fullscreenElement != null) {
    await _document.exitFullscreen().toDart;
  } else {
    await _document.documentElement.requestFullscreen().toDart;
  }
  return true;
}
