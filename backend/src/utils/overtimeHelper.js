const supabase = require('../config/supabase');
const { DateTime } = require('luxon');

const detectOvertime = async (userId, absensiId, tanggal, jamKeluar, jamKeluarJadwal) => {
  const keluar = DateTime.fromFormat(jamKeluar, 'HH:mm:ss');
  const jadwal = DateTime.fromFormat(jamKeluarJadwal, 'HH:mm:ss');
  const limit  = jadwal.plus({ minutes: 30 });

  if (keluar <= limit) return null;

  const durasiMenit = Math.floor(keluar.diff(jadwal, 'minutes').minutes);
  if (durasiMenit < 60) return null;          // Minimum 60 menit
  const durasi = Math.min(durasiMenit, 240);  // Maximum 4 jam

  // weekday: 1=Sen … 6=Sab, 7=Min
  const day = DateTime.fromISO(tanggal).weekday;
  const multiplier = (day === 6 || day === 7) ? 2.0 : 1.5;

  // Cek lembur terencana
  const { data: planned } = await supabase
    .from('overtime')
    .select('id')
    .eq('id_karyawan', userId)
    .eq('tanggal', tanggal)
    .eq('status', 'disetujui')
    .eq('jenis', 'terencana')
    .maybeSingle();

  let overtimeId;

  if (planned) {
    const { data } = await supabase
      .from('overtime')
      .update({
        status:             'selesai',
        id_absensi:         absensiId,
        jam_selesai_lembur: jamKeluar,
        durasi_menit:       durasi,
      })
      .eq('id', planned.id)
      .select('id')
      .single();
    overtimeId = data?.id;
  } else {
    const { data } = await supabase
      .from('overtime')
      .insert({
        id_karyawan:        userId,
        id_absensi:         absensiId,
        tanggal,
        jam_mulai_lembur:   jamKeluarJadwal,
        jam_selesai_lembur: jamKeluar,
        durasi_menit:       durasi,
        jenis:              'spontan',
        status:             'selesai',
        multiplier_tarif:   multiplier,
      })
      .select('id')
      .single();
    overtimeId = data?.id;
  }

  if (overtimeId) {
    await supabase
      .from('absensi')
      .update({ is_overtime: true, id_overtime: overtimeId })
      .eq('id', absensiId);
  }

  return overtimeId;
};

module.exports = { detectOvertime };
