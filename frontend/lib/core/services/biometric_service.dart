import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Mengelola autentikasi biometrik (sidik jari Android / Face ID iOS)
/// dan penyimpanan kredensial terenkripsi.
class BiometricService {
  static const _keyEmail    = 'biometric_email';
  static const _keyPassword = 'biometric_password';
  static const _keyEnabled  = 'biometric_enabled';

  static final LocalAuthentication _auth = LocalAuthentication();

  static FlutterSecureStorage get _storage {
    // Android: gunakan EncryptedSharedPreferences
    const androidOpts = AndroidOptions(
      encryptedSharedPreferences: true,
    );
    return const FlutterSecureStorage(aOptions: androidOpts);
  }

  // ── Cek ketersediaan biometrik di device ─────────────────────────────────

  /// True jika device mendukung biometrik DAN sudah ada enrolling sidik jari/face
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Daftar biometrik yang tersedia (fingerprint, face, iris)
  static Future<List<BiometricType>> getAvailableTypes() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  // ── Autentikasi ──────────────────────────────────────────────────────────

  /// Tampilkan prompt biometrik. Kembalikan true jika berhasil.
  static Future<bool> authenticate({
    String reason = 'Verifikasi identitas Anda untuk masuk',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,       // hanya biometrik, tanpa PIN fallback
          stickyAuth: true,          // lanjutkan jika app di-background sementara
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] authenticate error: ${e.code} ${e.message}');
      return false;
    }
  }

  // ── Simpan & baca kredensial ─────────────────────────────────────────────

  /// Simpan email+password agar bisa dipakai untuk biometric login
  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    if (kIsWeb) return;
    await _storage.write(key: _keyEmail,    value: email);
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyEnabled,  value: 'true');
  }

  /// Hapus kredensial yang tersimpan (mis. saat logout atau user matikan fitur)
  static Future<void> clearCredentials() async {
    if (kIsWeb) return;
    await _storage.deleteAll();
  }

  /// Baca email yang tersimpan
  static Future<String?> getSavedEmail() async {
    if (kIsWeb) return null;
    return _storage.read(key: _keyEmail);
  }

  /// Baca password yang tersimpan
  static Future<String?> getSavedPassword() async {
    if (kIsWeb) return null;
    return _storage.read(key: _keyPassword);
  }

  /// Cek apakah biometric login sudah diaktifkan user sebelumnya
  static Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    final val = await _storage.read(key: _keyEnabled);
    return val == 'true';
  }

  // ── Helper: label biometrik sesuai device ───────────────────────────────

  /// Kembalikan label human-readable, mis. "Sidik Jari" atau "Face ID"
  static Future<String> getBiometricLabel({String lang = 'id'}) async {
    final types = await getAvailableTypes();
    final hasFace        = types.contains(BiometricType.face);
    final hasFingerprint = types.contains(BiometricType.fingerprint);

    if (lang == 'en') {
      if (hasFace)        return 'Face ID';
      if (hasFingerprint) return 'Fingerprint';
      return 'Biometric';
    } else {
      if (hasFace)        return 'Face ID';
      if (hasFingerprint) return 'Sidik Jari';
      return 'Biometrik';
    }
  }

  /// Kembalikan icon yang sesuai
  static Future<BiometricIconInfo> getIconInfo() async {
    final types = await getAvailableTypes();
    if (types.contains(BiometricType.face)) {
      return const BiometricIconInfo(
        icon: 0xe90c, // face_retouching_natural, pakai Icons.face_retouching_natural
        fontFamily: 'MaterialIcons',
      );
    }
    return const BiometricIconInfo(
      icon: 0xe89e, // fingerprint
      fontFamily: 'MaterialIcons',
    );
  }
}

class BiometricIconInfo {
  final int icon;
  final String fontFamily;
  const BiometricIconInfo({required this.icon, required this.fontFamily});
}
