import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../l10n/translations.dart';
import 'web_utils_stub.dart'
    if (dart.library.js_interop) 'web_utils_web.dart';

// ── Result types ─────────────────────────────────────────────────────────────

sealed class LocationResult {}

class LocationSuccess extends LocationResult {
  final Position position;
  LocationSuccess(this.position);
}

class LocationDenied extends LocationResult {
  final String message;
  final bool isPermanent;
  LocationDenied({required this.message, this.isPermanent = false});
}

class LocationServiceDisabled extends LocationResult {}

class LocationError extends LocationResult {
  final String message;
  LocationError(this.message);
}

// ── Service ───────────────────────────────────────────────────────────────────

class LocationService {

  // ── Ambil posisi ──────────────────────────────────────────────────────────
  /// Di Flutter Web (khususnya Safari iOS), navigator.permissions.query()
  /// tidak reliable — bisa salah baca meski sudah di-Allow di browser.
  /// Solusi: bypass checkPermission() di web, langsung panggil
  /// getCurrentPosition() dan biarkan browser yang handle permission-nya.
  static Future<LocationResult> requestAndGet() async {
    // Native: cek service enabled
    if (!kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return LocationServiceDisabled();

      // Native: flow permission normal
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return LocationDenied(
          message: 'Izin lokasi ditolak.',
          isPermanent: false,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationDenied(
          message: 'Akses lokasi diblokir permanen.',
          isPermanent: true,
        );
      }
    }

    // Web & native (setelah lolos permission check): langsung ambil posisi
    return _getPosition();
  }

  // ── Ambil posisi GPS ──────────────────────────────────────────────────────
  static Future<LocationResult> _getPosition() async {
    // Di web: pakai JS native langsung (bypass Flutter CanvasKit worker)
    // agar Safari iOS tidak blokir karena dianggap bukan dari user gesture.
    if (kIsWeb) {
      try {
        final loc = await getLocationJS();
        // Buat Position dari koordinat JS
        final position = Position(
          latitude: loc.lat,
          longitude: loc.lng,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        return LocationSuccess(position);
      } catch (e) {
        final raw = e.toString();
        final msg = raw.toLowerCase();
        debugPrint('[LocationService] JS error: $raw');

        if (msg.contains('1') || msg.contains('denied') ||
            msg.contains('permission') || msg.contains('not allowed')) {
          return LocationDenied(
            message: 'Izin lokasi ditolak di browser.',
            isPermanent: false,
          );
        }
        if (msg.contains('2')) {
          return LocationError('Posisi tidak tersedia. Pastikan GPS aktif.');
        }
        if (msg.contains('3') || msg.contains('timeout')) {
          return LocationError('Waktu habis. Pastikan GPS aktif dan coba lagi.');
        }
        return LocationError('Gagal mendapatkan lokasi: $raw');
      }
    }

    // Native: pakai Geolocator biasa
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      return LocationSuccess(position);
    } catch (e) {
      final raw = e.toString();
      final msg = raw.toLowerCase();
      debugPrint('[LocationService] native error: $raw');
      if (msg.contains('denied') || msg.contains('permission')) {
        return LocationDenied(message: 'Izin lokasi ditolak.', isPermanent: false);
      }
      if (msg.contains('timeout')) {
        return LocationError('Waktu habis. Pastikan GPS aktif dan coba lagi.');
      }
      return LocationError('Gagal mendapatkan lokasi: $raw');
    }
  }

  // ── Dialog rationale + langsung request (fix Safari iOS) ─────────────────
  /// Safari/iOS: Geolocation harus dipanggil dalam scope user gesture.
  /// Panggil requestAndGet() di dalam onPressed tombol "Izinkan".
  static Future<LocationResult> showRationaleAndRequest(
      BuildContext context, {String lang = 'id'}) async {
    final completer = Completer<LocationResult>();

    final titleText  = Tr.get('loc_required_title', lang);
    final bodyText   = lang == 'id'
        ? 'Aplikasi membutuhkan akses lokasi untuk memverifikasi kehadiran di area kantor.\n\nLokasi hanya digunakan saat proses absensi.'
        : 'The app needs location access to verify attendance at the office area.\n\nLocation is only used during check-in.';
    final noLabel    = Tr.get('loc_no',    lang);
    final allowLabel = Tr.get('loc_allow', lang);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF2563EB),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                bodyText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        completer.complete(LocationDenied(
                          message: lang == 'id'
                              ? 'Izin lokasi diperlukan untuk absensi.'
                              : 'Location permission is required for check-in.',
                          isPermanent: false,
                        ));
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Text(noLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final result = await requestAndGet();
                        completer.complete(result);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(allowLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return completer.future;
  }

  // ── Dialog error lokasi ───────────────────────────────────────────────────
  static Future<void> showLocationErrorDialog(
    BuildContext context,
    LocationResult result, {
    String lang = 'id',
  }) async {
    final String title;
    final String message;
    final String? primaryLabel;
    final VoidCallback? primaryAction;
    final bool showClose;

    if (result is LocationServiceDisabled) {
      title = Tr.get('loc_service_off', lang);
      message = lang == 'id'
          ? 'Aktifkan GPS di pengaturan perangkat, lalu coba lagi.'
          : 'Enable GPS in device settings, then try again.';
      primaryLabel = Tr.get('loc_open_settings', lang);
      primaryAction = () async {
        Navigator.pop(context);
        await Geolocator.openLocationSettings();
      };
      showClose = true;
    } else if (result is LocationDenied && result.isPermanent) {
      title = Tr.get('loc_blocked', lang);
      message = kIsWeb
          ? (lang == 'id'
              ? 'Ketuk ikon "aA" atau 🔒 di address bar Safari\n→ Izin Situs Web → Lokasi → Izinkan\n\nAtau: Pengaturan iPhone → Safari → Lokasi → Izinkan.'
              : 'Tap the "aA" or 🔒 icon in Safari\'s address bar\n→ Website Settings → Location → Allow\n\nOr: iPhone Settings → Safari → Location → Allow.')
          : (lang == 'id'
              ? 'Buka Pengaturan → Aplikasi → SiAbsen → Izin → Lokasi → Izinkan.'
              : 'Go to Settings → Apps → SiAbsen → Permissions → Location → Allow.');
      primaryLabel = kIsWeb
          ? Tr.get('loc_understand', lang)
          : Tr.get('loc_open_settings', lang);
      primaryAction = kIsWeb
          ? () => Navigator.pop(context)
          : () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            };
      showClose = false;
    } else if (result is LocationDenied) {
      title = Tr.get('loc_denied', lang);
      message = kIsWeb
          ? (lang == 'id'
              ? 'Safari memblokir akses lokasi.\n\n1. Ketuk ikon "aA" di address bar\n2. Pilih "Izin Situs Web"\n3. Ubah Lokasi → "Izinkan"\n4. Ketuk Selesai lalu refresh halaman'
              : 'Safari blocked location access.\n\n1. Tap the "aA" icon in the address bar\n2. Select "Website Settings"\n3. Change Location → "Allow"\n4. Tap Done then refresh the page')
          : (lang == 'id'
              ? 'Absensi memerlukan akses lokasi untuk memverifikasi kehadiran.'
              : 'Check-in requires location access to verify attendance.');
      primaryLabel = kIsWeb ? Tr.get('loc_refresh', lang) : null;
      primaryAction = kIsWeb
          ? () {
              Navigator.pop(context);
              _reloadPage();
            }
          : null;
      showClose = true;
    } else if (result is LocationError) {
      title = Tr.get('loc_failed', lang);
      message = result.message;
      primaryLabel = null;
      primaryAction = null;
      showClose = true;
    } else {
      return;
    }

    final closeLabel = Tr.get('close', lang);

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              if (primaryLabel != null && primaryAction != null && showClose)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Text(closeLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: primaryAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(primaryLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ],
                )
              else if (primaryLabel != null &&
                  primaryAction != null &&
                  !showClose)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: primaryAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(primaryLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Text(closeLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cek apakah perlu tampilkan rationale ─────────────────────────────────
  static Future<bool> shouldShowRationale() async {
    // Di web, selalu tampilkan rationale karena checkPermission tidak reliable
    if (kIsWeb) return true;
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.denied;
  }

  // ── Reload halaman ────────────────────────────────────────────────────────
  static void _reloadPage() {
    if (kIsWeb) {
      reloadPage();
    }
  }
}
