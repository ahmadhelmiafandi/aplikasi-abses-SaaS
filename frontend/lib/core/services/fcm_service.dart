import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../supabase/supabase_config.dart';

/// Service untuk menangani Firebase Cloud Messaging (FCM) push notifications.
///
/// Memiliki penanganan error/graceful degradation jika kredensial
/// Firebase (google-services.json/GoogleService-Info.plist) belum disiapkan.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;

  FcmService._internal();

  bool _isInitialized = false;

  /// Inisialisasi Firebase & FCM.
  /// Panggil di `main.dart` saat app startup.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Inisialisasi Firebase Core
      // Catch error jika file konfigurasi google-services.json tidak ada
      await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;

      // 2. Request Permission (iOS / Android 13+)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('[FCM] Notification authorization status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _isInitialized = true;

        // 3. Ambil Device Token untuk dikirim ke backend
        final token = await messaging.getToken();
        if (token != null) {
          await _saveTokenToSupabase(token);
        }

        // Auto-refresh token if it updates
        messaging.onTokenRefresh.listen((newToken) async {
          await _saveTokenToSupabase(newToken);
        });

        // 4. Handle Foreground Messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('[FCM] Received foreground message: ${message.notification?.title}');
          // Tampilkan local notification atau banner dialog jika dibutuhkan
        });

        // 5. Handle Background/Terminated Message click
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('[FCM] App opened via notification click: ${message.data}');
        });
      }
    } catch (e) {
      debugPrint('[FCM WARNING] Firebase gagal diinisialisasi: $e');
      debugPrint('[FCM WARNING] Pastikan google-services.json (Android) / GoogleService-Info.plist (iOS) sudah disiapkan.');
    }
  }

  /// Kirim/simpan FCM token ke profil user di Supabase agar backend bisa mengirim push notifications.
  Future<void> _saveTokenToSupabase(String token) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user != null) {
        await SupabaseConfig.client.from('profiles').update({
          'fcm_token': token,
        }).eq('id', user.id);
        debugPrint('[FCM] Device token berhasil disimpan ke Supabase.');
      }
    } catch (e) {
      debugPrint('[FCM ERROR] Gagal menyimpan token ke Supabase: $e');
    }
  }

  /// Panggil setelah user login sukses agar token disimpan.
  Future<void> registerDeviceToken() async {
    if (!_isInitialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('[FCM] Gagal registrasi token setelah login: $e');
    }
  }
}
