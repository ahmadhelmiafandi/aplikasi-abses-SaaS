import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../models/izin_model.dart';

/// Datasource remote untuk operasi tabel `izin` di Supabase.
class IzinRemoteDataSource {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<IzinModel>> getDaftarIzin({required bool selfOnly}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    var query = _client
        .from('izin')
        .select('*, profiles(nama)');

    if (selfOnly) {
      query = query.eq('id_karyawan', user.id);
    }

    final res = await query.order('created_at', ascending: false);
    return res.map((json) => IzinModel.fromJson(json)).toList();
  }

  Future<void> ajukanIzin({
    required String jenisIzin,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    required String keterangan,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Ambil profil user untuk mendapatkan id_tenant
    final profile = await _client
        .from('profiles')
        .select('id_tenant')
        .eq('id', user.id)
        .single();

    final idTenant = profile['id_tenant']?.toString();

    await _client.from('izin').insert({
      'id_karyawan': user.id,
      'jenis_izin': jenisIzin,
      'tanggal_mulai': tanggalMulai.toIso8601String().split('T')[0],
      'tanggal_selesai': tanggalSelesai.toIso8601String().split('T')[0],
      'keterangan': keterangan,
      'status': 'pending',
      'id_tenant': idTenant,
    });
  }

  Future<void> updateStatusIzin({
    required String id,
    required String status,
  }) async {
    await _client.from('izin').update({
      'status': status,
    }).eq('id', id);
  }
}
