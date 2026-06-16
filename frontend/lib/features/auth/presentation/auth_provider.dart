import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/fcm_service.dart';

// ---------------------------------------------------------------------------
// Auth State
// ---------------------------------------------------------------------------

enum AuthStatus { authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;

  /// Data profil karyawan dari tabel `profiles` (bukan dari auth.users).
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({required this.status, this.user, this.error});

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

// ---------------------------------------------------------------------------
// AuthNotifier — menggunakan Supabase Auth
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(status: AuthStatus.loading)) {
    _init();
  }

  // ── Inisialisasi: dengarkan perubahan sesi dari Supabase ──────────────────
  void _init() {
    // Cek sesi yang sudah ada (mis. app di-restart)
    final session = SupabaseConfig.auth.currentSession;
    if (session != null) {
      _loadProfile(session.user.id);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    // Subscribe perubahan auth (login, logout, token refresh otomatis)
    SupabaseConfig.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        _loadProfile(session.user.id);
      } else if (event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.tokenRefreshed && session == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  // ── Ambil profil dari tabel `profiles` ───────────────────────────────────
  Future<void> _loadProfile(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      state = AuthState(status: AuthStatus.authenticated, user: data);
      FcmService().registerDeviceToken();
    } catch (e) {
      // Profil belum ada (baru daftar, menunggu approval) — tetap auth
      // agar bisa ditampilkan halaman "menunggu verifikasi"
      final authUser = SupabaseConfig.auth.currentUser;
      state = AuthState(
        status: AuthStatus.authenticated,
        user: {
          'id': authUser?.id,
          'email': authUser?.email,
          'nama': authUser?.userMetadata?['nama'] ?? '',
          'role': 'karyawan',
          'status_aktif': false,
        },
      );
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await SupabaseConfig.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      // _init() listener akan handle state setelah signIn berhasil
    } on AuthException catch (e) {
      String msg;
      switch (e.statusCode) {
        case '400':
          msg = 'Email atau password salah.';
          break;
        case '403':
          msg = 'Akun belum diaktifkan oleh admin.';
          break;
        default:
          msg = e.message;
      }
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
    } catch (_) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Gagal terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<String?> register({
    required String nama,
    required String email,
    required String password,
    String? nomorHp,
    String? alamat,
  }) async {
    try {
      final response = await DioClient().dio.post(
        '/auth/register',
        data: {
          'nama': nama,
          'email': email.trim(),
          'password': password,
          'nomorHp': nomorHp,
          'alamat': alamat,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        return null; // null = berhasil
      }
      return response.data?['message'] ?? 'Gagal membuat akun.';
    } on DioException catch (e) {
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
      }
      return 'Terjadi kesalahan: ${e.message}';
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  // ── Reload profil (dipakai dari pending approval screen) ─────────────────
  Future<void> reloadProfile() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;
    await _loadProfile(userId);
  }

  // ── Forgot Password ────────────────────────────────────────────────────────
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await SupabaseConfig.auth.resetPasswordForEmail(email.trim());
      return null; // null = berhasil
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Gagal mengirim email reset password: $e';
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await SupabaseConfig.auth.signOut();
    // onAuthStateChange listener akan set state ke unauthenticated
  }

  // ── Update cached user (setelah update profil) ────────────────────────────
  void updateCachedUser(Map<String, dynamic> updatedData) {
    if (state.user == null) return;
    state = state.copyWith(user: {...state.user!, ...updatedData});
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

/// Shortcut: hanya rebuild saat data user berubah
final currentUserProvider = Provider<Map<String, dynamic>?>((ref) {
  return ref.watch(authProvider).user;
});

/// Shortcut: role user
final currentRoleProvider = Provider<String>((ref) {
  return ref.watch(currentUserProvider)?['role']?.toString() ?? '';
});
