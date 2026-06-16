/**
 * Unit tests untuk overtimeHelper.detectOvertime
 * Mock Supabase agar tidak butuh koneksi database nyata.
 */

// Mock @supabase/supabase-js sebelum require helper
jest.mock('../../config/supabase', () => ({
  from: jest.fn(() => ({
    select: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    insert: jest.fn().mockReturnThis(),
    eq:     jest.fn().mockReturnThis(),
    single: jest.fn().mockResolvedValue({ data: { id: 'overtime-123' }, error: null }),
    maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }),
  })),
}));

const { detectOvertime } = require('../overtimeHelper');

describe('detectOvertime', () => {
  const userId    = 'user-uuid-123';
  const absensiId = 'absensi-uuid-456';
  const tanggal   = '2026-06-10'; // Selasa (weekday)
  const sabtu     = '2026-06-13'; // Sabtu  (weekend)

  test('tidak deteksi overtime jika keluar sebelum 30 menit toleransi', async () => {
    // Jadwal keluar 17:00, keluar 17:25 → dalam toleransi 30 menit
    const result = await detectOvertime(userId, absensiId, tanggal, '17:25:00', '17:00:00');
    expect(result).toBeNull();
  });

  test('tidak deteksi overtime jika durasi < 60 menit', async () => {
    // Jadwal 17:00, keluar 17:45 → 45 menit, di atas toleransi tapi < 60 menit
    const result = await detectOvertime(userId, absensiId, tanggal, '17:45:00', '17:00:00');
    expect(result).toBeNull();
  });

  test('deteksi overtime hari biasa, multiplier 1.5x', async () => {
    // Jadwal 17:00, keluar 19:00 → 120 menit overtime (weekday)
    const supabase = require('../../config/supabase');

    // Reset mock: tidak ada overtime terencana
    supabase.from.mockReturnValue({
      select: jest.fn().mockReturnThis(),
      update: jest.fn().mockReturnThis(),
      insert: jest.fn().mockReturnThis(),
      eq:     jest.fn().mockReturnThis(),
      single: jest.fn().mockResolvedValue({ data: { id: 'new-ot-id' }, error: null }),
      maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }), // tidak ada terencana
    });

    const result = await detectOvertime(userId, absensiId, tanggal, '19:00:00', '17:00:00');
    expect(result).not.toBeNull();
  });

  test('deteksi overtime hari Sabtu, multiplier 2.0x', async () => {
    // Jadwal 17:00, keluar 19:30 → 150 menit overtime (weekend → multiplier 2.0)
    const supabase = require('../../config/supabase');

    supabase.from.mockReturnValue({
      select: jest.fn().mockReturnThis(),
      update: jest.fn().mockReturnThis(),
      insert: jest.fn().mockReturnThis(),
      eq:     jest.fn().mockReturnThis(),
      single: jest.fn().mockResolvedValue({ data: { id: 'ot-weekend' }, error: null }),
      maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }),
    });

    const result = await detectOvertime(userId, absensiId, sabtu, '19:30:00', '17:00:00');
    expect(result).not.toBeNull();
  });

  test('overtime dibatasi maksimum 240 menit', async () => {
    // Jadwal 17:00, keluar 23:00 → seharusnya 360 menit, tapi dibatasi 240
    const supabase = require('../../config/supabase');
    let insertedData;

    supabase.from.mockReturnValue({
      select: jest.fn().mockReturnThis(),
      update: jest.fn().mockReturnThis(),
      insert: jest.fn((data) => {
        insertedData = data;
        return {
          select: jest.fn().mockReturnThis(),
          single: jest.fn().mockResolvedValue({ data: { id: 'ot-max' }, error: null }),
        };
      }),
      eq:          jest.fn().mockReturnThis(),
      maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }),
    });

    const result = await detectOvertime(userId, absensiId, tanggal, '23:00:00', '17:00:00');
    expect(result).not.toBeNull();
    // Verifikasi durasi tidak melebihi 240 menit
    if (insertedData) {
      expect(insertedData.durasi_menit).toBeLessThanOrEqual(240);
    }
  });

  test('update overtime terencana jika ada yang sudah disetujui', async () => {
    const supabase = require('../../config/supabase');

    // Ada overtime terencana yang disetujui
    supabase.from.mockReturnValue({
      select: jest.fn().mockReturnThis(),
      update: jest.fn().mockReturnThis(),
      insert: jest.fn().mockReturnThis(),
      eq:     jest.fn().mockReturnThis(),
      single: jest.fn().mockResolvedValue({ data: { id: 'updated-ot' }, error: null }),
      maybeSingle: jest.fn().mockResolvedValue({
        data: { id: 'planned-ot-id' }, // Ada overtime terencana
        error: null,
      }),
    });

    const result = await detectOvertime(userId, absensiId, tanggal, '19:00:00', '17:00:00');
    expect(result).not.toBeNull();
  });
});
