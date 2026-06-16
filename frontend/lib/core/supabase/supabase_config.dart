import 'package:supabase_flutter/supabase_flutter.dart';

/// Konfigurasi Supabase.
///
/// Untuk production, override via `--dart-define`:
/// ```
/// flutter build web \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your-anon-key
/// ```
///
/// Untuk development, gunakan nilai default di bawah (tanpa --dart-define).
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ppdutshsvguxgtyclaxj.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_W-HkCWET_mQyaOMs0T0WIg_ZB-HereA',
  );

  /// Shortcut global client
  static SupabaseClient get client => Supabase.instance.client;

  /// Shortcut auth
  static GoTrueClient get auth => Supabase.instance.client.auth;
}
