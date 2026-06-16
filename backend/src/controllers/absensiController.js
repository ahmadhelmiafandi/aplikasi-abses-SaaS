const supabase = require('../config/supabase');
const logger = require('../config/logger');
const { successResponse, errorResponse } = require('../utils/response');
const { DateTime } = require('luxon');
const { decrypt } = require('../utils/crypto');
const { getJadwalAktif } = require('../utils/scheduleHelper');
const { detectOvertime } = require('../utils/overtimeHelper');

// ── Geofencing helper ────────────────────────────────────────────────────────
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3;
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const dPhi = ((lat2 - lat1) * Math.PI) / 180;
  const dLam = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dPhi / 2) ** 2 +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(dLam / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── Check In ─────────────────────────────────────────────────────────────────
const checkIn = async (req, res) => {
  const userId = req.user.id;
  const { latitude, longitude } = req.body;
  const today   = DateTime.now().toISODate();
  const nowTime = DateTime.now().toFormat('HH:mm:ss');

  try {
    // 1. Jadwal aktif
    const shift = await getJadwalAktif(userId, today);
    if (!shift || shift.is_libur) {
      return errorResponse(res, 'Hari ini adalah hari libur atau jadwal belum diatur', 400);
    }

    // 2. Geofencing (skip WFH)
    if (!shift.is_wfh) {
      const officeLat = parseFloat(req.tenantSettings.office_lat);
      const officeLng = parseFloat(req.tenantSettings.office_lng);
      const radius    = parseInt(req.tenantSettings.geofence_radius_meter) || 100;
      const distance  = calculateDistance(latitude, longitude, officeLat, officeLng);
      if (distance > radius) {
        return errorResponse(res, `Di luar radius kantor (${Math.round(distance)}m dari ${radius}m)`, 403);
      }
    }

    // 3. Cek duplikasi
    const { data: existing } = await supabase
      .from('absensi')
      .select('id')
      .eq('id_karyawan', userId)
      .eq('tanggal', today)
      .eq('id_tenant', req.tenantId)
      .maybeSingle();

    if (existing) return errorResponse(res, 'Sudah check-in hari ini', 400);

    // 4. Hitung keterlambatan
    let status = 'hadir';
    let lateMinutes = 0;

    if (!shift.is_fleksibel) {
      const checkInDt = DateTime.fromFormat(nowTime, 'HH:mm:ss');
      const limitDt   = DateTime.fromFormat(shift.jam_masuk, 'HH:mm:ss')
                          .plus({ minutes: shift.toleransi_menit });
      if (checkInDt > limitDt) {
        status = 'terlambat';
        lateMinutes = Math.floor(
          checkInDt.diff(DateTime.fromFormat(shift.jam_masuk, 'HH:mm:ss'), 'minutes').minutes
        );
      }
    }

    // 5. Insert absensi
    const { data: absensi, error } = await supabase
      .from('absensi')
      .insert({
        id_karyawan:     userId,
        id_shift:        shift.id,
        tanggal:         today,
        jam_masuk:       nowTime,
        status,
        menit_terlambat: lateMinutes,
        keterangan:      shift.is_wfh ? 'WFH' : 'WFO',
        id_tenant:       req.tenantId,
      })
      .select()
      .single();

    if (error) throw error;

    // 6. Log aktivitas
    await supabase.from('log_aktivitas').insert({
      id_user: userId,
      aksi:    'CHECK_IN',
      detail:  `Check-in (${shift.is_wfh ? 'WFH' : 'WFO'}) — ${status}`,
      ip_address: req.ip,
      id_tenant: req.tenantId,
    });

    return successResponse(res, 'Check-in Berhasil', absensi);
  } catch (err) {
    logger.error('[checkIn]', err);
    return errorResponse(res, 'Gagal check-in');
  }
};

// ── Check Out ────────────────────────────────────────────────────────────────
const checkOut = async (req, res) => {
  const userId  = req.user.id;
  const today   = DateTime.now().toISODate();
  const nowTime = DateTime.now().toFormat('HH:mm:ss');

  try {
    const { data: existing, error: fetchErr } = await supabase
      .from('absensi')
      .select('*')
      .eq('id_karyawan', userId)
      .eq('tanggal', today)
      .eq('id_tenant', req.tenantId)
      .maybeSingle();

    if (fetchErr) throw fetchErr;
    if (!existing)            return errorResponse(res, 'Belum check-in hari ini', 400);
    if (existing.jam_keluar)  return errorResponse(res, 'Sudah check-out hari ini', 400);

    const { data: updated, error: updateErr } = await supabase
      .from('absensi')
      .update({ jam_keluar: nowTime })
      .eq('id', existing.id)
      .eq('id_tenant', req.tenantId)
      .select()
      .single();

    if (updateErr) throw updateErr;

    // Deteksi overtime
    const shift = await getJadwalAktif(userId, today);
    if (shift && shift.jam_keluar) {
      await detectOvertime(userId, existing.id, today, nowTime, shift.jam_keluar);
    }

    return successResponse(res, 'Check-out Berhasil', updated);
  } catch (err) {
    logger.error('[checkOut]', err);
    return errorResponse(res, 'Gagal check-out');
  }
};

// ── Scan QR ──────────────────────────────────────────────────────────────────
const scanQR = async (req, res) => {
  const { qr_data, lat_karyawan, lng_karyawan } = req.body;
  const userId = req.user.id;

  try {
    const decrypted = JSON.parse(decrypt(qr_data));
    const { token_unik, expired_at } = decrypted;

    if (DateTime.now().toMillis() > expired_at) {
      return errorResponse(res, 'QR Code sudah kadaluarsa', 400);
    }

    const { data: qrSession, error: qrErr } = await supabase
      .from('qr_sessions')
      .select('*')
      .eq('token_unik', token_unik)
      .eq('id_tenant', req.tenantId)
      .maybeSingle();

    if (qrErr) throw qrErr;
    if (!qrSession || qrSession.sudah_dipakai) {
      return errorResponse(res, 'QR Code tidak valid atau sudah digunakan', 400);
    }

    const distance = calculateDistance(
      lat_karyawan, lng_karyawan,
      qrSession.lokasi_lat, qrSession.lokasi_lng
    );
    if (distance > 100) {
      return errorResponse(res, `Terlalu jauh dari lokasi scanner (${Math.round(distance)}m)`, 403);
    }

    await supabase
      .from('qr_sessions')
      .update({ sudah_dipakai: true })
      .eq('id', qrSession.id)
      .eq('id_tenant', req.tenantId);

    req.body.latitude  = lat_karyawan;
    req.body.longitude = lng_karyawan;
    return await checkIn(req, res);
  } catch (err) {
    logger.error('[scanQR]', err);
    return errorResponse(res, 'Data QR tidak dapat diproses', 400);
  }
};

// ── Riwayat absensi (dengan paginasi) ───────────────────────────────────────
const getHistory = async (req, res) => {
  const userId = req.user.id;
  const bulan  = parseInt(req.query.bulan)  || DateTime.now().month;
  const tahun  = parseInt(req.query.tahun)  || DateTime.now().year;
  const page   = Math.max(1, parseInt(req.query.page)  || 1);
  const limit  = Math.min(50, parseInt(req.query.limit) || 31); // max 31 per bulan
  const from   = (page - 1) * limit;
  const to     = from + limit - 1;

  const startDate = `${tahun}-${String(bulan).padStart(2, '0')}-01`;
  const endDate   = bulan < 12
    ? `${tahun}-${String(bulan + 1).padStart(2, '0')}-01`
    : `${tahun + 1}-01-01`;

  try {
    const { data, error, count } = await supabase
      .from('absensi')
      .select('*', { count: 'exact' })
      .eq('id_karyawan', userId)
      .eq('id_tenant', req.tenantId)
      .gte('tanggal', startDate)
      .lt('tanggal', endDate)
      .order('tanggal', { ascending: false })
      .range(from, to);

    if (error) throw error;
    return successResponse(res, 'Riwayat absensi', {
      data,
      pagination: { total: count, page, limit },
    });
  } catch (err) {
    logger.error('[getHistory]', err);
    return errorResponse(res, 'Gagal mengambil riwayat absensi');
  }
};

// ── Status hari ini ──────────────────────────────────────────────────────────
const getTodayStatus = async (req, res) => {
  const userId = req.user.id;
  const today  = DateTime.now().toISODate();

  try {
    const { data, error } = await supabase
      .from('absensi')
      .select('*')
      .eq('id_karyawan', userId)
      .eq('tanggal', today)
      .eq('id_tenant', req.tenantId)
      .maybeSingle();

    if (error) throw error;
    return successResponse(res, 'Status hari ini', data || null);
  } catch (err) {
    return errorResponse(res, 'Gagal mengambil status hari ini');
  }
};

module.exports = { checkIn, checkOut, scanQR, getHistory, getTodayStatus };
