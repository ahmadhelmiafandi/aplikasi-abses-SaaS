/**
 * Unit tests untuk izinController.
 */

const mockSingle = jest.fn();
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
    order:  jest.fn().mockReturnThis(),
    single: mockSingle,
  })),
}));

// Mock logger
jest.mock('../../config/logger', () => ({
  error: jest.fn(),
  info: jest.fn(),
}));

const { applyIzin, getMyIzin, getPendingIzin, reviewIzin } = require('../izinController');
const { DateTime } = require('luxon');

// Helper mock req/res
const mockReq = (body = {}, params = {}, user = { id: 'user-123', role: 'karyawan', id_departemen: 'dept-1' }) => ({
  body,
  params,
  user,
  ip: '127.0.0.1',
});

const mockRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json   = jest.fn().mockReturnValue(res);
  return res;
};

describe('izinController', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockSelect.mockReturnValue({
      eq: jest.fn().mockReturnThis(),
      order: jest.fn().mockResolvedValue({ data: [], error: null }),
      single: mockSingle,
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

  describe('applyIzin', () => {
    test('gagal jika parameter tidak lengkap', async () => {
      const req = mockReq({ jenis_izin: 'sakit' });
      const res = mockRes();

      await applyIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: expect.stringContaining('wajib diisi') })
      );
    });

    test('gagal jika tanggal_selesai sebelum tanggal_mulai', async () => {
      const today = DateTime.now().toISODate();
      const yesterday = DateTime.now().minus({ days: 1 }).toISODate();
      const req = mockReq({
        tanggal_mulai: today,
        tanggal_selesai: yesterday,
        jenis_izin: 'sakit',
        alasan: 'Sakit gigi',
      });
      const res = mockRes();

      await applyIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: expect.stringContaining('tidak boleh sebelum') })
      );
    });

    test('gagal jika tanggal_mulai di masa lalu', async () => {
      const yesterday = DateTime.now().minus({ days: 1 }).toISODate();
      const req = mockReq({
        tanggal_mulai: yesterday,
        tanggal_selesai: yesterday,
        jenis_izin: 'sakit',
        alasan: 'Sakit gigi',
      });
      const res = mockRes();

      await applyIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: expect.stringContaining('tidak boleh hari yang sudah lewat') })
      );
    });

    test('berhasil membuat pengajuan izin untuk karyawan (status pending, approver manajer)', async () => {
      const futureDate = DateTime.now().plus({ days: 2 }).toISODate();
      const req = mockReq({
        tanggal_mulai: futureDate,
        tanggal_selesai: futureDate,
        jenis_izin: 'sakit',
        alasan: 'Sakit demam',
      });
      const res = mockRes();

      mockSingle.mockResolvedValue({
        data: { id: 'izin-123', status: 'pending', current_approver_role: 'manajer' },
        error: null,
      });

      await applyIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Pengajuan izin berhasil terkirim',
          data: expect.objectContaining({ status: 'pending', current_approver_role: 'manajer' }),
        })
      );
    });

    test('berhasil membuat pengajuan izin untuk manajer (approver hrd)', async () => {
      const futureDate = DateTime.now().plus({ days: 2 }).toISODate();
      const req = mockReq({
        tanggal_mulai: futureDate,
        tanggal_selesai: futureDate,
        jenis_izin: 'cuti',
        alasan: 'Cuti tahunan',
      }, {}, { id: 'manajer-123', role: 'manajer', id_departemen: 'dept-1' });
      const res = mockRes();

      mockSingle.mockResolvedValue({
        data: { id: 'izin-123', status: 'pending', current_approver_role: 'hrd' },
        error: null,
      });

      await applyIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({ current_approver_role: 'hrd' }),
        })
      );
    });
  });

  describe('getMyIzin', () => {
    test('berhasil mengambil data izin milik sendiri', async () => {
      const mockList = [{ id: '1', jenis_izin: 'sakit' }];
      mockSelect.mockReturnValue({
        eq: jest.fn().mockReturnThis(),
        order: jest.fn().mockResolvedValue({ data: mockList, error: null }),
      });

      const req = mockReq();
      const res = mockRes();

      await getMyIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, data: mockList })
      );
    });
  });

  describe('getPendingIzin', () => {
    test('manajer hanya dapat melihat izin pending di departemennya sendiri', async () => {
      const mockData = [
        { id: 'izin-1', profiles: { id_departemen: 'dept-1', nama: 'Karyawan A' } },
        { id: 'izin-2', profiles: { id_departemen: 'dept-2', nama: 'Karyawan B' } },
      ];

      mockSelect.mockReturnValue({
        eq: jest.fn().mockReturnThis(),
        order: jest.fn().mockResolvedValue({ data: mockData, error: null }),
      });

      // User manajer departemen 'dept-1'
      const req = mockReq({}, {}, { id: 'manajer-123', role: 'manajer', id_departemen: 'dept-1' });
      const res = mockRes();

      await getPendingIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      const resBody = res.json.mock.calls[0][0];
      expect(resBody.data).toHaveLength(1);
      expect(resBody.data[0].id).toBe('izin-1');
    });

    test('hrd dapat melihat semua izin pending', async () => {
      const mockData = [
        { id: 'izin-1', profiles: { id_departemen: 'dept-1', nama: 'Karyawan A' } },
        { id: 'izin-2', profiles: { id_departemen: 'dept-2', nama: 'Karyawan B' } },
      ];

      mockSelect.mockReturnValue({
        eq: jest.fn().mockReturnThis(),
        order: jest.fn().mockResolvedValue({ data: mockData, error: null }),
      });

      const req = mockReq({}, {}, { id: 'hrd-123', role: 'hrd' });
      const res = mockRes();

      await getPendingIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      const resBody = res.json.mock.calls[0][0];
      expect(resBody.data).toHaveLength(2);
    });
  });

  describe('reviewIzin', () => {
    test('gagal jika action review tidak valid', async () => {
      const req = mockReq({ action: 'cancel' }, { id: 'izin-123' });
      const res = mockRes();

      await reviewIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: expect.stringContaining('Aksi tidak valid') })
      );
    });

    test('gagal jika izin tidak ditemukan', async () => {
      mockSingle.mockResolvedValue({ data: null, error: { message: 'Not found' } });

      const req = mockReq({ action: 'approve' }, { id: 'izin-123' }, { id: 'manajer-123', role: 'manajer' });
      const res = mockRes();

      await reviewIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: 'Izin tidak ditemukan' })
      );
    });

    test('gagal jika approver role tidak cocok', async () => {
      // Izin butuh approval hrd
      mockSingle.mockResolvedValue({
        data: { id: 'izin-123', status: 'pending', current_approver_role: 'hrd' },
        error: null,
      });

      // User yang me-review adalah manajer
      const req = mockReq({ action: 'approve' }, { id: 'izin-123' }, { id: 'manajer-123', role: 'manajer' });
      const res = mockRes();

      await reviewIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: expect.stringContaining('tidak berhak memproses') })
      );
    });

    test('manajer menyetujui izin akan meneruskan status pending ke hrd', async () => {
      mockSingle
        // Fetch izin
        .mockResolvedValueOnce({
          data: { id: 'izin-123', id_karyawan: 'kar-1', status: 'pending', current_approver_role: 'manajer', jenis_izin: 'sakit' },
          error: null,
        })
        // Update izin
        .mockResolvedValueOnce({
          data: { id: 'izin-123', status: 'pending', current_approver_role: 'hrd' },
          error: null,
        });

      const req = mockReq({ action: 'approve', catatan: 'Ok silakan' }, { id: 'izin-123' }, { id: 'manajer-123', role: 'manajer' });
      const res = mockRes();

      await reviewIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Izin berhasil disetujui',
          data: expect.objectContaining({ current_approver_role: 'hrd', status: 'pending' }),
        })
      );
    });

    test('hrd menyetujui izin akan mengubah status menjadi disetujui (final)', async () => {
      mockSingle
        .mockResolvedValueOnce({
          data: { id: 'izin-123', id_karyawan: 'kar-1', status: 'pending', current_approver_role: 'hrd', jenis_izin: 'sakit' },
          error: null,
        })
        .mockResolvedValueOnce({
          data: { id: 'izin-123', status: 'disetujui', current_approver_role: null },
          error: null,
        });

      const req = mockReq({ action: 'approve' }, { id: 'izin-123' }, { id: 'hrd-123', role: 'hrd' });
      const res = mockRes();

      await reviewIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({ status: 'disetujui', current_approver_role: null }),
        })
      );
    });

    test('review ditolak (reject) oleh siapapun langsung membatalkan izin', async () => {
      mockSingle
        .mockResolvedValueOnce({
          data: { id: 'izin-123', id_karyawan: 'kar-1', status: 'pending', current_approver_role: 'manajer', jenis_izin: 'sakit' },
          error: null,
        })
        .mockResolvedValueOnce({
          data: { id: 'izin-123', status: 'ditolak', current_approver_role: null },
          error: null,
        });

      const req = mockReq({ action: 'reject', catatan: 'Tidak boleh' }, { id: 'izin-123' }, { id: 'manajer-123', role: 'manajer' });
      const res = mockRes();

      await reviewIzin(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Izin berhasil ditolak',
          data: expect.objectContaining({ status: 'ditolak' }),
        })
      );
    });
  });
});
