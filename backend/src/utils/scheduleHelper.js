const supabase = require('../config/supabase');

/**
 * Ambil jadwal aktif karyawan untuk tanggal tertentu.
 * Urutan fallback:
 *  1. jadwal_karyawan spesifik harian
 *  2. shift default departemen
 *  3. shift default global
 */
const getJadwalAktif = async (userId, date) => {
  // 1. Jadwal spesifik harian
  const { data: jadwal } = await supabase
    .from('jadwal_karyawan')
    .select('*, shift(*)')
    .eq('id_karyawan', userId)
    .eq('tanggal', date)
    .maybeSingle();

  if (jadwal) {
    return { ...jadwal.shift, is_libur: jadwal.is_libur };
  }

  // 2. Shift default departemen
  const { data: profile } = await supabase
    .from('profiles')
    .select('id_departemen, departemen(default_shift_id)')
    .eq('id', userId)
    .maybeSingle();

  if (profile?.departemen?.default_shift_id) {
    const { data: deptShift } = await supabase
      .from('shift')
      .select('*')
      .eq('id', profile.departemen.default_shift_id)
      .eq('is_aktif', true)
      .maybeSingle();

    if (deptShift) return { ...deptShift, is_libur: false };
  }

  // 3. Shift default global
  const { data: globalShift } = await supabase
    .from('shift')
    .select('*')
    .eq('is_default_global', true)
    .eq('is_aktif', true)
    .limit(1)
    .maybeSingle();

  if (globalShift) return { ...globalShift, is_libur: false };

  return null;
};

module.exports = { getJadwalAktif };
