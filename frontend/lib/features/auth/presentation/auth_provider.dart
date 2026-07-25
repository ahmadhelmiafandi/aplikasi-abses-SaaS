import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_config.dart';
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

      final authUser = SupabaseConfig.auth.currentUser;
      final appMetadata = authUser?.appMetadata;
      final userMetadata = authUser?.userMetadata;
      final appRole  = appMetadata != null ? appMetadata['role']?.toString() : null;
      final userRole = userMetadata != null ? userMetadata['role']?.toString() : null;
      final isSuper  = data['role'] == 'superadmin' ||
                       appRole == 'superadmin' ||
                       userRole == 'superadmin' ||
                       authUser?.email == 'helmikeren211@gmail.com';

      if (isSuper) {
        data['role'] = 'superadmin';
        data['status_aktif'] = true;
      }

      state = AuthState(status: AuthStatus.authenticated, user: data);
      FcmService().registerDeviceToken();
    } catch (e) {
      final authUser = SupabaseConfig.auth.currentUser;
      final appMetadata = authUser?.appMetadata;
      final userMetadata = authUser?.userMetadata;
      final appRole  = appMetadata != null ? appMetadata['role']?.toString() : null;
      final userRole = userMetadata != null ? userMetadata['role']?.toString() : null;
      final isSuper  = appRole == 'superadmin' ||
                       userRole == 'superadmin' ||
                       authUser?.email == 'helmikeren211@gmail.com';

      state = AuthState(
        status: AuthStatus.authenticated,
        user: {
          'id': authUser?.id,
          'email': authUser?.email,
          'nama': authUser?.userMetadata?['nama'] ?? (isSuper ? 'Super Admin' : ''),
          'role': isSuper ? 'superadmin' : 'karyawan',
          'status_aktif': isSuper ? true : false,
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

  // ── Instant Demo Login ───────────────────────────────────────────────────
  void loginDemo(String role) {
    if (role == 'admin') {
      state = const AuthState(
        status: AuthStatus.authenticated,
        user: {
          'id': 'demo-admin-id-12345',
          'email': 'admin.demo@siabsen.com',
          'nama': 'Admin HRD (Demo Mode)',
          'role': 'admin',
          'status_aktif': true,
          'tenant_id': 'demo-tenant-id-001',
          'nama_perusahaan': 'PT SiAbsen Demo Enterprise',
        },
      );
    } else {
      state = const AuthState(
        status: AuthStatus.authenticated,
        user: {
          'id': 'demo-karyawan-id-67890',
          'email': 'karyawan.demo@siabsen.com',
          'nama': 'Ahmad Helmi (Demo Karyawan)',
          'role': 'karyawan',
          'status_aktif': true,
          'tenant_id': 'demo-tenant-id-001',
          'nama_perusahaan': 'PT SiAbsen Demo Enterprise',
        },
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
    String? tenantCode,
  }) async {
    try {
      String? tenantId;
      if (tenantCode != null && tenantCode.trim().isNotEmpty) {
        final codeClean = tenantCode.trim();
        // Lookup tenant via Token Kode Perusahaan (company_code) atau Subdomain
        final tenantRes = await SupabaseConfig.client
            .from('tenants')
            .select('id')
            .or('company_code.ilike.$codeClean,subdomain.ilike.${codeClean.toLowerCase()}')
            .maybeSingle();

        if (tenantRes == null) {
          return 'Kode Token Perusahaan "$tenantCode" tidak ditemukan. Hubungi HRD kantor Anda.';
        }
        tenantId = tenantRes['id']?.toString();
      }

      // 1. Registrasi via Supabase Auth (User metadata tersimpan aman di Supabase)
      final authRes = await SupabaseConfig.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'nama': nama,
          'nomor_hp': nomorHp,
          'alamat': alamat,
          'role': 'karyawan',
          'status_aktif': false,
          'id_tenant': tenantId,
        },
      );

      final user = authRes.user;
      if (user == null) {
        return 'Gagal membuat akun. Silakan coba lagi.';
      }

      // 2. Coba simpan profil ke tabel profiles (terikat ke id_tenant)
      try {
        await SupabaseConfig.client.from('profiles').upsert({
          'id': user.id,
          'email': email.trim(),
          'nama': nama,
          'role': 'karyawan',
          'status_aktif': false, // menunggu approval admin
          'nomor_hp': nomorHp,
          'alamat': alamat,
          'id_tenant': tenantId,
        });
      } catch (_) {
        // Safe to ignore: profile metadata fallback is available
      }

      return null; // null = berhasil
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists') || e.statusCode == '400') {
        return 'Email ini sudah terdaftar. Silakan login atau gunakan email lain.';
      }
      return e.message;
    } catch (e) {
      return 'Gagal membuat akun. Pastikan koneksi internet stabil.';
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
