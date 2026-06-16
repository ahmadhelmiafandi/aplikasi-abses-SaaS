import 'dart:async';

/// Stub untuk platform non-web.
void reloadPage() {
  // no-op di non-web
}

/// Stub — tidak dipakai di non-web, native pakai Geolocator langsung.
Future<({double lat, double lng})> getLocationJS() {
  throw UnsupportedError('getLocationJS hanya tersedia di Flutter Web');
}
