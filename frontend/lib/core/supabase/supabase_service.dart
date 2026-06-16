import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import '../network/dio_client.dart';

/// Semua operasi database langsung ke Supabase (menggantikan Dio ke backend
/// untuk CRUD biasa). Backend Express hanya dipanggil untuk:
///   - Check-in (geofencing)
///   - Check-out (overtime detection)
///   - Generate QR
///   - Scan QR
class SupabaseService {
  static SupabaseClient get _db => SupabaseConfig.client;

  // ══════════════════════════════════════════════════════════════════════════
  // ABSENSI
  // ══════════════════════════════════════════════════════════════════════════

  /// Status absensi hari ini untuk user yang sedang login.
  static Future<Map<String, dynamic>?> getTodayAbsensi() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return null;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final res = await _db
        .from('absensi')
        .select()
        .eq('id_karyawan', userId)
        .eq('tanggal', today)
        .maybeSingle();

    return res;
  }

  /// Riwayat absensi per bulan (dengan paginasi).
  static Future<Map<String, dynamic>> getAbsensiHistoryPaginated({
    required int bulan,
    required int tahun,
    int page = 1,
    int limit = 31,
  }) async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return {'data': <Map<String, dynamic>>[], 'total': 0, 'page': page, 'limit': limit};

    final startDate = '$tahun-${bulan.toString().padLeft(2, '0')}-01';
    final endDate = bulan < 12
        ? '$tahun-${(bulan + 1).toString().padLeft(2, '0')}-01'
        : '${tahun + 1}-01-01';

    final from = (page - 1) * limit;
    final to = from + limit - 1;

    // Count total (separate query karena Supabase Flutter SDK
    // tidak mengembalikan count bersama data saat pakai .range())
    final countRes = await _db
        .from('absensi')
        .select()
        .eq('id_karyawan', userId)
        .gte('tanggal', startDate)
        .lt('tanggal', endDate);
    final total = (countRes as List).length;

    final res = await _db
        .from('absensi')
        .select()
        .eq('id_karyawan', userId)
        .gte('tanggal', startDate)
        .lt('tanggal', endDate)
        .order('tanggal', ascending: false)
        .range(from, to);

    return {
      'data': List<Map<String, dynamic>>.from(res),
      'total': total,
      'page': page,
      'limit': limit,
    };
  }

  /// Riwayat absensi per bulan (tanpa paginasi — backward compat).
  static Future<List<Map<String, dynamic>>> getAbsensiHistory({
    required int bulan,
    required int tahun,
  }) async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return [];

    final startDate = '$tahun-${bulan.toString().padLeft(2, '0')}-01';
    final endDate = bulan < 12
        ? '$tahun-${(bulan + 1).toString().padLeft(2, '0')}-01'
        : '${tahun + 1}-01-01';

    final res = await _db
        .from('absensi')
        .select()
        .eq('id_karyawan', userId)
        .gte('tanggal', startDate)
        .lt('tanggal', endDate)
        .order('tanggal', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IZIN
  // ══════════════════════════════════════════════════════════════════════════

  /// Izin milik user yang sedang login.
  static Future<List<Map<String, dynamic>>> getMyIzin() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return [];

    final res = await _db
        .from('izin')
        .select()
        .eq('id_karyawan', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  /// Ajukan izin baru.
  static Future<void> ajukanIzin({
    required String tanggalMulai,
    required String tanggalSelesai,
    required String jenisIzin,
    required String alasan,
  }) async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) throw Exception('User tidak terautentikasi');

    // Tentukan approver berdasarkan role
    final profile = await _db
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();
    final role = profile['role'] as String;

    String? currentApproverRole;
    String status = 'pending';

    if (role == 'karyawan') {
      currentApproverRole = 'manajer';
    } else if (role == 'manajer') {
      currentApproverRole = 'hrd';
    } else if (role == 'hrd') {
      status = 'disetujui';
    }

    await _db.from('izin').insert({
      'id_karyawan': userId,
      'tanggal_mulai': tanggalMulai,
      'tanggal_selesai': tanggalSelesai,
      'jenis_izin': jenisIzin,
      'alasan': alasan,
      'status': status,
      'current_approver_role': currentApproverRole,
    });
  }

  /// Izin pending yang menunggu persetujuan role yang sedang login.
  static Future<List<Map<String, dynamic>>> getPendingIzin() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return [];

    final profile = await _db
        .from('profiles')
        .select('role, id_departemen')
        .eq('id', userId)
        .single();
    final role = profile['role'] as String;

    // Join dengan profiles untuk nama karyawan dan departemen
    var query = _db
        .from('izin')
        .select('*, profiles!id_karyawan(nama, email, id_departemen, departemen(nama_departemen))')
        .eq('status', 'pending')
        .eq('current_approver_role', role);

    final res = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Approve atau reject izin.
  static Future<void> reviewIzin({
    required String izinId,
    required String action, // 'approve' | 'reject'
    String? catatan,
  }) async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) throw Exception('User tidak terautentikasi');

    final profile = await _db
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();
    final role = profile['role'] as String;

    String newStatus = 'pending';
    String? nextApprover = role;

    if (action == 'approve') {
      if (role == 'manajer') {
        nextApprover = 'hrd';
      } else if (role == 'hrd') {
        nextApprover = null;
        newStatus = 'disetujui';
      }
    } else {
      newStatus = 'ditolak';
      nextApprover = null;
    }

    // Update izin
    await _db.from('izin').update({
      'status': newStatus,
      'current_approver_role': nextApprover,
      'id_approver': userId,
      'catatan_approver': catatan,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', izinId);

    // Insert approval log
    await _db.from('izin_approval_logs').insert({
      'id_izin': izinId,
      'id_approver': userId,
      'role_approver': role,
      'action': action,
      'note': catatan,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROFIL
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getProfile() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) throw Exception('User tidak terautentikasi');

    final res = await _db
        .from('profiles')
        .select('*, departemen(nama_departemen)')
        .eq('id', userId)
        .single();

    return Map<String, dynamic>.from(res);
  }

  static Future<void> updateProfile({
    required String nama,
    String? nomorHp,
    String? alamat,
  }) async {
    // Lewat backend Express agar RLS tidak memblokir (service_role key)
    // Kirim null untuk field kosong agar Zod tidak reject empty string
    await DioClient().dio.put('/profile', data: {
      'nama': nama,
      'nomor_hp': (nomorHp != null && nomorHp.isNotEmpty) ? nomorHp : null,
      'alamat':   (alamat   != null && alamat.isNotEmpty)   ? alamat   : null,
    });
  }

  static Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final email = SupabaseConfig.auth.currentUser?.email;
    if (email == null) throw Exception('User tidak terautentikasi');

    // Re-authenticate untuk verifikasi password lama sebelum update
    await SupabaseConfig.auth.signInWithPassword(
      email: email,
      password: oldPassword,
    );

    // Jika signIn tidak throw, password lama benar — lanjut update
    await SupabaseConfig.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LAPORAN
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getLaporanBulanan({
    required int bulan,
    required int tahun,
  }) async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) throw Exception('User tidak terautentikasi');

    final profile = await _db
        .from('profiles')
        .select('role, id_departemen')
        .eq('id', userId)
        .single();
    final role = profile['role'] as String;

    final startDate = '$tahun-${bulan.toString().padLeft(2, '0')}-01';
    final endDate = bulan < 12
        ? '$tahun-${(bulan + 1).toString().padLeft(2, '0')}-01'
        : '${tahun + 1}-01-01';

    // Gunakan RPC Supabase untuk aggregate query
    // Fallback: query manual
    var query = _db
        .from('profiles')
        .select('''
          id, nama, email,
          absensi!id_karyawan(status, tanggal, menit_terlambat)
        ''')
        .eq('status_aktif', true);

    // Filter departemen untuk manajer
    if (role == 'manajer' && profile['id_departemen'] != null) {
      query = query.eq('id_departemen', profile['id_departemen']);
    }

    final rawData = await query;
    final details = <Map<String, dynamic>>[];
    int totalHadir = 0, totalTerlambat = 0, totalIzin = 0, totalAlpha = 0;

    for (final emp in rawData) {
      final absensiList = (emp['absensi'] as List<dynamic>? ?? [])
          .where((a) {
            final tgl = a['tanggal'] as String;
            return tgl.compareTo(startDate) >= 0 && tgl.compareTo(endDate) < 0;
          })
          .toList();

      int hadir = 0, terlambat = 0, izin = 0, alpha = 0;
      for (final a in absensiList) {
        switch (a['status'] as String) {
          case 'hadir':
            hadir++;
            totalHadir++;
            break;
          case 'terlambat':
            terlambat++;
            totalTerlambat++;
            break;
          case 'izin':
            izin++;
            totalIzin++;
            break;
          case 'alpha':
            alpha++;
            totalAlpha++;
            break;
        }
      }

      details.add({
        'id': emp['id'],
        'nama': emp['nama'],
        'email': emp['email'],
        'hadir': hadir,
        'terlambat': terlambat,
        'izin': izin,
        'alpha': alpha,
      });
    }

    return {
      'summary': {
        'total_karyawan': details.length,
        'total_hadir': totalHadir,
        'total_terlambat': totalTerlambat,
        'total_izin': totalIzin,
        'total_alpha': totalAlpha,
      },
      'details': details,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ADMIN — USER MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    // Lewat backend Express (service_role key, bisa baca semua profil)
    final res = await DioClient().dio.get('/users');
    // Response shape: { success, message, data: { data: [...], pagination } }
    final wrapper = res.data['data'];
    final List<dynamic> list = (wrapper is Map && wrapper['data'] is List)
        ? wrapper['data'] as List<dynamic>
        : (wrapper is List ? wrapper : []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> getPendingUsers() async {
    final res = await _db
        .from('profiles')
        .select()
        .eq('status_aktif', false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> approveUser(String userId) async {
    await _db
        .from('profiles')
        .update({'status_aktif': true, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  static Future<void> deactivateUser(String userId) async {
    // Lewat backend Express (service_role — bisa update row user lain)
    await DioClient().dio.delete('/users/$userId');
  }

  static Future<void> updateUserByAdmin({
    required String userId,
    required String nama,
    required String email,
    required String role,
    required bool statusAktif,
  }) async {
    // Lewat backend Express (service_role — bisa update row user lain)
    await DioClient().dio.put('/users/$userId', data: {
      'nama': nama,
      'email': email,
      'role': role,
      'status_aktif': statusAktif,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFIKASI
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getNotifikasi() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return [];

    final res = await _db
        .from('notifikasi')
        .select()
        .eq('id_penerima', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(res);
  }

  static Future<int> getUnreadCount() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return 0;

    final res = await _db
        .from('notifikasi')
        .select()
        .eq('id_penerima', userId)
        .eq('status_baca', false);

    return (res as List).length;
  }

  static Future<void> markAllAsRead() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;

    await _db
        .from('notifikasi')
        .update({'status_baca': true})
        .eq('id_penerima', userId)
        .eq('status_baca', false);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REALTIME — Subscribe perubahan absensi hari ini
  // ══════════════════════════════════════════════════════════════════════════

  /// Subscribe realtime untuk absensi hari ini.
  /// Kembalikan channel agar bisa di-unsubscribe saat widget dispose.
  static RealtimeChannel subscribeAbsensiHariIni({
    required String userId,
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    return _db
        .channel('absensi_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'absensi',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_karyawan',
            value: userId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }
}
