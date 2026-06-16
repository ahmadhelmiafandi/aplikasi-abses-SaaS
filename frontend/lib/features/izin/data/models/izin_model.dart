import '../../domain/entities/izin.dart';

/// Model data Izin (Data Layer) dengan parsing JSON
class IzinModel extends Izin {
  const IzinModel({
    required super.id,
    required super.idKaryawan,
    required super.jenisIzin,
    required super.tanggalMulai,
    required super.tanggalSelesai,
    required super.keterangan,
    required super.status,
    super.idTenant,
    super.createdAt,
    super.namaKaryawan,
  });

  factory IzinModel.fromJson(Map<String, dynamic> json) {
    // Parsing join profile
    String? namaKaryawan;
    if (json['profiles'] != null && json['profiles'] is Map) {
      namaKaryawan = json['profiles']['nama']?.toString();
    }

    return IzinModel(
      id: json['id']?.toString() ?? '',
      idKaryawan: json['id_karyawan']?.toString() ?? '',
      jenisIzin: json['jenis_izin']?.toString() ?? '',
      tanggalMulai: DateTime.tryParse(json['tanggal_mulai']?.toString() ?? '') ?? DateTime.now(),
      tanggalSelesai: DateTime.tryParse(json['tanggal_selesai']?.toString() ?? '') ?? DateTime.now(),
      keterangan: json['keterangan']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      idTenant: json['id_tenant']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      namaKaryawan: namaKaryawan,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_karyawan': idKaryawan,
      'jenis_izin': jenisIzin,
      'tanggal_mulai': tanggalMulai.toIso8601String().split('T')[0],
      'tanggal_selesai': tanggalSelesai.toIso8601String().split('T')[0],
      'keterangan': keterangan,
      'status': status,
      'id_tenant': idTenant,
    };
  }
}
