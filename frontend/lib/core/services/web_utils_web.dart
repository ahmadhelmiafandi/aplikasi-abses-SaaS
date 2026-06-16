import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Reload halaman browser saat ini.
void reloadPage() {
  web.window.location.reload();
}

// ── JS interop declarations ───────────────────────────────────────────────────

/// Tipe callback sukses: dipanggil dengan lat dan lng
typedef _SuccessCallback = void Function(JSNumber lat, JSNumber lng);

/// Tipe callback error: dipanggil dengan code dan message
typedef _ErrorCallback = void Function(JSNumber code, JSString message);

@JS('getLocationForFlutter')
external void _getLocationForFlutter(
  JSFunction successCallback,
  JSFunction errorCallback,
);

/// Ambil lokasi GPS via JS native (melewati Flutter CanvasKit worker).
/// Safari iOS hanya mengizinkan Geolocation dari main thread JS.
Future<({double lat, double lng})> getLocationJS() {
  final completer = Completer<({double lat, double lng})>();

  final onSuccess = (JSNumber lat, JSNumber lng) {
    if (!completer.isCompleted) {
      completer.complete((lat: lat.toDartDouble, lng: lng.toDartDouble));
    }
  }.toJS;

  final onError = (JSNumber code, JSString message) {
    if (!completer.isCompleted) {
      completer.completeError(
        Exception('${code.toDartInt}:${message.toDart}'),
      );
    }
  }.toJS;

  _getLocationForFlutter(onSuccess, onError);

  return completer.future;
}
