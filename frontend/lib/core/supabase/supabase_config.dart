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
    defaultValue: 'https://bjcozlqatjmpxtepqjpr.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJqY296bHFhdGptcHh0ZXBxanByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ4MTc3NjAsImV4cCI6MjEwMDM5Mzc2MH0.7rQJgMGP2K3Alu0t6by7vZMbsUyFgqRnLuDqF7nCIo8',
  );

  /// Shortcut global client
  static SupabaseClient get client => Supabase.instance.client;

  /// Shortcut auth
  static GoTrueClient get auth => Supabase.instance.client.auth;
}
