/// Entity domain untuk data Izin
class Izin {
  final String id;
  final String idKaryawan;
  final String jenisIzin;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String keterangan;
  final String status;
  final String? idTenant;
  final DateTime? createdAt;
  final String? namaKaryawan; // Diambil dari join profile jika ada

  const Izin({
    required this.id,
    required this.idKaryawan,
    required this.jenisIzin,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.keterangan,
    required this.status,
    this.idTenant,
    this.createdAt,
    this.namaKaryawan,
  });
}
