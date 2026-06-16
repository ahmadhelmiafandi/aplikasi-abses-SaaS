const supabase = require('../config/supabase');
const logger   = require('../config/logger');
const { DateTime } = require('luxon');

/**
 * Cron job scheduler — dipanggil saat server start.
 * Menggunakan setInterval sebagai pengganti node-cron agar
 * tidak menambah dependensi baru.
 */

// ── 1. Mark Alpha — setiap menit cek apakah sudah 23:59 WIB ─────────────────
let lastAlphaDate = null;

const markAlphaJob = async () => {
  const now = DateTime.now().setZone('Asia/Jakarta');
  const today = now.toISODate();

  // Jalankan hanya sekali per hari, mendekati 23:59
  if (now.hour === 23 && now.minute >= 55 && lastAlphaDate !== today) {
    lastAlphaDate = today;
    logger.info(`[Cron] Menjalankan mark alpha untuk ${today}`);

    try {
      // Ambil semua karyawan aktif yang belum punya record absensi hari ini
      const { data: profiles, error: profErr } = await supabase
        .from('profiles')
        .select('id, id_tenant')
        .eq('status_aktif', true);

      if (profErr) throw profErr;

      const { data: absensiHariIni, error: absErr } = await supabase
        .from('absensi')
        .select('id_karyawan')
        .eq('tanggal', today);

      if (absErr) throw absErr;

      const sudahAbsen = new Set(absensiHariIni.map(a => a.id_karyawan));
      const belumAbsen = profiles.filter(p => !sudahAbsen.has(p.id));

      if (belumAbsen.length === 0) {
        logger.info('[Cron] Semua karyawan sudah absen hari ini.');
        return;
      }

      const records = belumAbsen.map(p => ({
        id_karyawan: p.id,
        tanggal: today,
        status: 'alpha',
        keterangan: 'Otomatis — tidak hadir',
        id_tenant: p.id_tenant,
      }));

      const { error: insertErr } = await supabase
        .from('absensi')
        .upsert(records, { onConflict: 'id_karyawan,tanggal', ignoreDuplicates: true });

      if (insertErr) throw insertErr;

      logger.info(`[Cron] ${belumAbsen.length} karyawan ditandai alpha.`);
    } catch (err) {
      logger.error('[Cron] Gagal mark alpha:', err.message);
    }
  }
};

// ── 2. Cleanup QR Sessions kadaluarsa — setiap jam ──────────────────────────
const cleanupQrSessionsJob = async () => {
  try {
    const now = DateTime.now().toMillis();

    const { error } = await supabase
      .from('qr_sessions')
      .delete()
      .lt('expired_at', now);

    if (error) throw error;
    logger.info('[Cron] QR sessions kadaluarsa dibersihkan.');
  } catch (err) {
    logger.error('[Cron] Gagal cleanup QR sessions:', err.message);
  }
};

// ── 3. Rekap Bulanan — tanggal 1 setiap bulan ───────────────────────────────
let lastRekapMonth = null;

const rekapBulananJob = async () => {
  const now = DateTime.now().setZone('Asia/Jakarta');

  if (now.day === 1 && now.hour >= 1 && lastRekapMonth !== now.month) {
    lastRekapMonth = now.month;
    const bulanLalu = now.minus({ months: 1 });
    const startDate = bulanLalu.startOf('month').toISODate();
    const endDate   = bulanLalu.endOf('month').toISODate();

    logger.info(`[Cron] Menjalankan rekap bulanan ${startDate} s/d ${endDate}`);

    try {
      const { data, error } = await supabase
        .from('absensi')
        .select('id_karyawan, status')
        .gte('tanggal', startDate)
        .lte('tanggal', endDate);

      if (error) throw error;

      // Hitung per karyawan
      const summary = {};
      for (const row of data) {
        if (!summary[row.id_karyawan]) {
          summary[row.id_karyawan] = { hadir: 0, terlambat: 0, izin: 0, alpha: 0 };
        }
        summary[row.id_karyawan][row.status] =
          (summary[row.id_karyawan][row.status] || 0) + 1;
      }

      logger.info(`[Cron] Rekap bulanan selesai — ${Object.keys(summary).length} karyawan diproses.`);
    } catch (err) {
      logger.error('[Cron] Gagal rekap bulanan:', err.message);
    }
  }
};

// ── Start semua cron jobs ────────────────────────────────────────────────────
const startCronJobs = () => {
  logger.info('[Cron] Cron jobs dimulai.');

  // Mark alpha: cek setiap 1 menit
  setInterval(markAlphaJob, 60_000);

  // Cleanup QR: setiap 1 jam
  setInterval(cleanupQrSessionsJob, 3_600_000);

  // Rekap bulanan: cek setiap 1 jam (hanya eksekusi tanggal 1)
  setInterval(rekapBulananJob, 3_600_000);
};

module.exports = { startCronJobs };
