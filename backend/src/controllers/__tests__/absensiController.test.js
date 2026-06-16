/**
 * Unit tests untuk absensiController.
 */

const mockSingle = jest.fn();
const mockMaybeSingle = jest.fn();
const mockInsert = jest.fn();
const mockUpdate = jest.fn();
const mockSelect = jest.fn();

// Mock Supabase client
jest.mock('../../config/supabase', () => ({
  from: jest.fn(() => ({
    select: mockSelect,
    insert: mockInsert,
    update: mockUpdate,
    eq:     jest.fn().mockReturnThis(),
    gte:    jest.fn().mockReturnThis(),
    lt:     jest.fn().mockReturnThis(),
    order:  jest.fn().mockReturnThis(),
    range:  jest.fn().mockReturnThis(),
    single: mockSingle,
    maybeSingle: mockMaybeSingle,
  })),
}));

// Mock schedule helper
const { getJadwalAktif } = require('../../utils/scheduleHelper');
jest.mock('../../utils/scheduleHelper', () => ({
  getJadwalAktif: jest.fn(),
}));

// Mock overtime helper
const { detectOvertime } = require('../../utils/overtimeHelper');
jest.mock('../../utils/overtimeHelper', () => ({
  detectOvertime: jest.fn(),
}));

// Mock decrypt
const { decrypt } = require('../../utils/crypto');
jest.mock('../../utils/crypto', () => ({
  decrypt: jest.fn(),
}));

// Mock logger
jest.mock('../../config/logger', () => ({
  error: jest.fn(),
  info: jest.fn(),
}));

const { checkIn, checkOut, scanQR, getHistory, getTodayStatus } = require('../absensiController');
const { DateTime } = require('luxon');

// Helper mock req/res
const mockReq = (body = {}, query = {}, user = { id: 'user-123', role: 'karyawan' }) => ({
  body,
  query,
  user,
  ip: '127.0.0.1',
  tenantId: 'interia',
  tenantSettings: {
    office_lat: '-6.9826',
    office_lng: '110.4092',
    geofence_radius_meter: 100,
  },
});

const mockRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json   = jest.fn().mockReturnValue(res);
  return res;
};

describe('absensiController', () => {
  // Set OFFICE_LAT and OFFICE_LNG env vars for testing
  beforeAll(() => {
    process.env.OFFICE_LAT = '-6.9826';
    process.env.OFFICE_LNG = '110.4092';
    process.env.GEOFENCE_RADIUS_METER = '100';
  });

  beforeEach(() => {
    jest.clearAllMocks();
    // Default mock query returns chainable self
    mockSelect.mockReturnValue({
      eq: jest.fn().mockReturnThis(),
      gte: jest.fn().mockReturnThis(),
      lt: jest.fn().mockReturnThis(),
      order: jest.fn().mockReturnThis(),
      range: jest.fn().mockResolvedValue({ data: [], error: null, count: 0 }),
      single: mockSingle,
      maybeSingle: mockMaybeSingle,
    });
    mockInsert.mockReturnValue({
      select: jest.fn().mockReturnThis(),
      single: mockSingle,
    });
    mockUpdate.mockReturnValue({
      eq: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      single: mockSingle,
    });
  });

  describe('checkIn', () => {
    test('gagal jika hari libur atau jadwal belum diatur', async () => {
      getJadwalAktif.mockResolvedValue(null);
      const req = mockReq({ latitude: -6.9826, longitude: 110.4092 });
      const res = mockRes();

      await checkIn(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: expect.stringContaining('libur atau jadwal belum diatur') })
      );
    });

    test('gagal jika di luar radius geofence kantor', async () => {
      // Shift WFO (bukan WFH)
      getJadwalAktif.mockResolvedValue({
        id: 'shift-1',
        is_libur: false,
        is_wfh: false,
        is_fleksibel: false,
        jam_masuk: '08:00:00',
        toleransi_menit: 15,
      });

      // Koordinat jauh (misal Jakarta, padahal kantor di Semarang)
      const req = mockReq({ latitude: -6.2088, longitude: 106.8456 });
      const res = mockRes();

      await checkIn(req, res);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: expect.stringContaining('Di luar radius kantor') })
      );
    });

    test('gagal jika sudah check-in hari ini', async () => {
      getJadwalAktif.mockResolvedValue({
        id: 'shift-1',
        is_libur: false,
        is_wfh: true, // WFH skip geofence
        is_fleksibel: true,
      });

      // Mock sudah ada record absensi
      mockMaybeSingle.mockResolvedValue({ data: { id: 'absensi-123' }, error: null });

      const req = mockReq({ latitude: 0, longitude: 0 });
      const res = mockRes();

      await checkIn(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: 'Sudah check-in hari ini' })
      );
    });

    test('berhasil check-in (hadir) untuk WFH fleksibel', async () => {
      getJadwalAktif.mockResolvedValue({
        id: 'shift-1',
        is_libur: false,
        is_wfh: true,
        is_fleksibel: true,
      });

      mockMaybeSingle.mockResolvedValue({ data: null, error: null });
      mockSingle.mockResolvedValue({
        data: { id: 'new-absensi-123', status: 'hadir', menit_terlambat: 0 },
        error: null,
      });

      const req = mockReq({ latitude: 0, longitude: 0 });
      const res = mockRes();

      await checkIn(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, message: 'Check-in Berhasil' })
      );
    });
  });

  describe('checkOut', () => {
    test('gagal jika belum check-in hari ini', async () => {
      mockMaybeSingle.mockResolvedValue({ data: null, error: null });

      const req = mockReq();
      const res = mockRes();

      await checkOut(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: 'Belum check-in hari ini' })
      );
    });

    test('gagal jika sudah check-out hari ini', async () => {
      mockMaybeSingle.mockResolvedValue({
        data: { id: 'absensi-123', jam_masuk: '08:00:00', jam_keluar: '17:00:00' },
        error: null,
      });

      const req = mockReq();
      const res = mockRes();

      await checkOut(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: 'Sudah check-out hari ini' })
      );
    });

    test('berhasil check-out dan mendeteksi overtime', async () => {
      mockMaybeSingle.mockResolvedValue({
        data: { id: 'absensi-123', jam_masuk: '08:00:00', jam_keluar: null },
        error: null,
      });

      mockSingle.mockResolvedValue({
        data: { id: 'absensi-123', jam_masuk: '08:00:00', jam_keluar: '17:30:00' },
        error: null,
      });

      getJadwalAktif.mockResolvedValue({
        id: 'shift-1',
        is_libur: false,
        jam_keluar: '17:00:00',
      });

      const req = mockReq();
      const res = mockRes();

      await checkOut(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, message: 'Check-out Berhasil' })
      );
      expect(detectOvertime).toHaveBeenCalled();
    });
  });

  describe('scanQR', () => {
    test('gagal jika QR code sudah kadaluarsa', async () => {
      const expiredMs = DateTime.now().minus({ minutes: 1 }).toMillis();
      decrypt.mockReturnValue(JSON.stringify({ token_unik: 'tok-123', expired_at: expiredMs }));

      const req = mockReq({ qr_data: 'encrypted-string', lat_karyawan: -6.9826, lng_karyawan: 110.4092 });
      const res = mockRes();

      await scanQR(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: 'QR Code sudah kadaluarsa' })
      );
    });

    test('gagal jika QR session tidak ada atau sudah digunakan', async () => {
      const futureMs = DateTime.now().plus({ minutes: 5 }).toMillis();
      decrypt.mockReturnValue(JSON.stringify({ token_unik: 'tok-123', expired_at: futureMs }));

      // Mock session sudah dipakai
      mockMaybeSingle.mockResolvedValue({ data: { id: 'sess-123', sudah_dipakai: true }, error: null });

      const req = mockReq({ qr_data: 'encrypted-string', lat_karyawan: -6.9826, lng_karyawan: 110.4092 });
      const res = mockRes();

      await scanQR(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: 'QR Code tidak valid atau sudah digunakan' })
      );
    });

    test('gagal jika lokasi karyawan terlalu jauh dari scanner QR', async () => {
      const futureMs = DateTime.now().plus({ minutes: 5 }).toMillis();
      decrypt.mockReturnValue(JSON.stringify({ token_unik: 'tok-123', expired_at: futureMs }));

      // QR session valid tapi terdaftar di lat/lng tertentu
      mockMaybeSingle.mockResolvedValue({
        data: { id: 'sess-123', sudah_dipakai: false, lokasi_lat: -6.9826, lokasi_lng: 110.4092 },
        error: null,
      });

      // Karyawan berada jauh
      const req = mockReq({ qr_data: 'encrypted-string', lat_karyawan: -6.2088, lng_karyawan: 106.8456 });
      const res = mockRes();

      await scanQR(req, res);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: expect.stringContaining('Terlalu jauh') })
      );
    });
  });

  describe('getHistory', () => {
    test('berhasil mengambil riwayat absensi dengan pagination info', async () => {
      const mockAbsensiList = [
        { id: '1', tanggal: '2026-06-01', status: 'hadir' },
        { id: '2', tanggal: '2026-06-02', status: 'hadir' },
      ];

      // Custom mock chain to resolve data with count
      mockSelect.mockReturnValue({
        eq: jest.fn().mockReturnThis(),
        gte: jest.fn().mockReturnThis(),
        lt: jest.fn().mockReturnThis(),
        order: jest.fn().mockReturnThis(),
        range: jest.fn().mockResolvedValue({ data: mockAbsensiList, error: null, count: 2 }),
      });

      const req = mockReq({}, { bulan: '6', tahun: '2026', page: '1', limit: '10' });
      const res = mockRes();

      await getHistory(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Riwayat absensi',
          data: expect.objectContaining({
            data: mockAbsensiList,
            pagination: { total: 2, page: 1, limit: 10 },
          }),
        })
      );
    });
  });

  describe('getTodayStatus', () => {
    test('berhasil mendapatkan status hari ini', async () => {
      mockMaybeSingle.mockResolvedValue({
        data: { id: 'absensi-123', status: 'hadir', tanggal: DateTime.now().toISODate() },
        error: null,
      });

      const req = mockReq();
      const res = mockRes();

      await getTodayStatus(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Status hari ini',
          data: expect.objectContaining({ id: 'absensi-123' }),
        })
      );
    });
  });
});
