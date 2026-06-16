import '../entities/izin.dart';

/// Kontrak repository untuk data Izin (Domain Layer)
abstract class IzinRepository {
  Future<List<Izin>> getDaftarIzin({bool selfOnly = true});
  Future<void> ajukanIzin({
    required String jenisIzin,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    required String keterangan,
  });
  Future<void> updateStatusIzin({
    required String id,
    required String status,
  });
}
