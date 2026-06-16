import '../../domain/entities/izin.dart';
import '../../domain/repositories/izin_repository.dart';
import '../datasources/izin_remote_data_source.dart';

/// Implementasi IzinRepository yang memanggil IzinRemoteDataSource.
class IzinRepositoryImpl implements IzinRepository {
  final IzinRemoteDataSource _dataSource;

  IzinRepositoryImpl(this._dataSource);

  @override
  Future<List<Izin>> getDaftarIzin({bool selfOnly = true}) async {
    return await _dataSource.getDaftarIzin(selfOnly: selfOnly);
  }

  @override
  Future<void> ajukanIzin({
    required String jenisIzin,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    required String keterangan,
  }) async {
    await _dataSource.ajukanIzin(
      jenisIzin: jenisIzin,
      tanggalMulai: tanggalMulai,
      tanggalSelesai: tanggalSelesai,
      keterangan: keterangan,
    );
  }

  @override
  Future<void> updateStatusIzin({
    required String id,
    required String status,
  }) async {
    await _dataSource.updateStatusIzin(id: id, status: status);
  }
}
