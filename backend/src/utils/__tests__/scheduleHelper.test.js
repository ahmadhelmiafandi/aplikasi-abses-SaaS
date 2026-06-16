/**
 * Unit tests untuk scheduleHelper.getJadwalAktif
 * Verifikasi 4 kasus fallback: harian → departemen → global → null
 */

const mockShiftHarian    = { id: 'sh-1', nama_shift: 'Shift Harian',    jam_masuk: '08:00', jam_keluar: '17:00', toleransi_menit: 15, is_wfh: false, is_fleksibel: false, is_libur: false };
const mockShiftDept      = { id: 'sh-2', nama_shift: 'Shift Departemen', jam_masuk: '08:30', jam_keluar: '17:30', toleransi_menit: 15, is_wfh: false, is_fleksibel: false };
const mockShiftGlobal    = { id: 'sh-3', nama_shift: 'Shift Global',     jam_masuk: '09:00', jam_keluar: '18:00', toleransi_menit: 15, is_wfh: false, is_fleksibel: false };
const mockProfile        = { id_departemen: 'dept-1', departemen: { default_shift_id: 'sh-2' } };

// Factory untuk mock Supabase chainable
const makeMock = (overrides = {}) => {
  const base = {
    select:      jest.fn().mockReturnThis(),
    eq:          jest.fn().mockReturnThis(),
    limit:       jest.fn().mockReturnThis(),
    maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }),
    ...overrides,
  };
  return base;
};

// Reset dan setup mock Supabase sebelum tiap test
let supabase;

beforeEach(() => {
  jest.resetModules();
  jest.mock('../../config/supabase', () => ({
    from: jest.fn(),
  }));
  supabase = require('../../config/supabase');
});

describe('getJadwalAktif', () => {
  const userId = 'user-uuid-123';
  const date   = '2026-06-10';

  test('Kasus 1 — return jadwal harian spesifik jika ada', async () => {
    // jadwal_karyawan punya data → return jadwal + shift
    supabase.from.mockImplementation((table) => {
      if (table === 'jadwal_karyawan') {
        return {
          select:      jest.fn().mockReturnThis(),
          eq:          jest.fn().mockReturnThis(),
          maybeSingle: jest.fn().mockResolvedValue({
            data: { ...mockShiftHarian, is_libur: false, shift: mockShiftHarian },
            error: null,
          }),
        };
      }
      return makeMock();
    });

    const { getJadwalAktif } = require('../scheduleHelper');
    const result = await getJadwalAktif(userId, date);

    expect(result).not.toBeNull();
    expect(result.id).toBe('sh-1');
  });

  test('Kasus 2 — fallback ke shift default departemen jika tidak ada jadwal harian', async () => {
    supabase.from.mockImplementation((table) => {
      if (table === 'jadwal_karyawan') {
        return { select: jest.fn().mockReturnThis(), eq: jest.fn().mockReturnThis(), maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }) };
      }
      if (table === 'profiles') {
        return { select: jest.fn().mockReturnThis(), eq: jest.fn().mockReturnThis(), maybeSingle: jest.fn().mockResolvedValue({ data: mockProfile, error: null }) };
      }
      if (table === 'shift') {
        return { select: jest.fn().mockReturnThis(), eq: jest.fn().mockReturnThis(), maybeSingle: jest.fn().mockResolvedValue({ data: mockShiftDept, error: null }) };
      }
      return makeMock();
    });

    const { getJadwalAktif } = require('../scheduleHelper');
    const result = await getJadwalAktif(userId, date);

    expect(result).not.toBeNull();
    expect(result.id).toBe('sh-2');
    expect(result.is_libur).toBe(false);
  });

  test('Kasus 3 — fallback ke shift global jika tidak ada departemen shift', async () => {
    supabase.from.mockImplementation((table) => {
      if (table === 'jadwal_karyawan') {
        return { select: jest.fn().mockReturnThis(), eq: jest.fn().mockReturnThis(), maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }) };
      }
      if (table === 'profiles') {
        return { select: jest.fn().mockReturnThis(), eq: jest.fn().mockReturnThis(), maybeSingle: jest.fn().mockResolvedValue({ data: { id_departemen: null, departemen: null }, error: null }) };
      }
      if (table === 'shift') {
        return { select: jest.fn().mockReturnThis(), eq: jest.fn().mockReturnThis(), limit: jest.fn().mockReturnThis(), maybeSingle: jest.fn().mockResolvedValue({ data: mockShiftGlobal, error: null }) };
      }
      return makeMock();
    });

    const { getJadwalAktif } = require('../scheduleHelper');
    const result = await getJadwalAktif(userId, date);

    expect(result).not.toBeNull();
    expect(result.id).toBe('sh-3');
  });

  test('Kasus 4 — return null jika tidak ada jadwal di semua level', async () => {
    supabase.from.mockImplementation(() => makeMock({
      maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }),
    }));

    const { getJadwalAktif } = require('../scheduleHelper');
    const result = await getJadwalAktif(userId, date);

    expect(result).toBeNull();
  });
});
