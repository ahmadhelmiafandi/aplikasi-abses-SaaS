const supabase = require('../config/supabase');
const logger = require('../config/logger');
const { successResponse, errorResponse } = require('../utils/response');
const { DateTime } = require('luxon');

// ── Ajukan izin ──────────────────────────────────────────────────────────────
const applyIzin = async (req, res) => {
  const user = req.user;
  const { tanggal_mulai, tanggal_selesai, jenis_izin, alasan } = req.body;

  if (!tanggal_mulai || !tanggal_selesai || !jenis_izin) {
    return errorResponse(res, 'tanggal_mulai, tanggal_selesai, dan jenis_izin wajib diisi', 400);
  }

  if (DateTime.fromISO(tanggal_selesai) < DateTime.fromISO(tanggal_mulai)) {
    return errorResponse(res, 'tanggal_selesai tidak boleh sebelum tanggal_mulai', 400);
  }

  if (DateTime.fromISO(tanggal_mulai) < DateTime.now().startOf('day')) {
    return errorResponse(res, 'Tanggal mulai tidak boleh hari yang sudah lewat', 400);
  }

  let status = 'pending';
  let current_approver_role = null;

  if (user.role === 'karyawan')    current_approver_role = 'manajer';
  else if (user.role === 'manajer') current_approver_role = 'hrd';
  else if (user.role === 'hrd')     status = 'disetujui';

  try {
    const { data, error } = await supabase
      .from('izin')
      .insert({
        id_karyawan:          user.id,
        tanggal_mulai,
        tanggal_selesai,
        jenis_izin,
        alasan,
        status,
        current_approver_role,
        id_tenant:            req.tenantId,
      })
      .select()
      .single();

    if (error) throw error;
    return successResponse(res, 'Pengajuan izin berhasil terkirim', data, 201);
  } catch (err) {
    logger.error('[applyIzin]', err);
    return errorResponse(res, 'Gagal mengajukan izin');
  }
};

// ── Izin milik karyawan yang sedang login ────────────────────────────────────
const getMyIzin = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('izin')
      .select('*')
      .eq('id_karyawan', req.user.id)
      .eq('id_tenant', req.tenantId)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return successResponse(res, 'Daftar izin saya', data);
  } catch (err) {
    return errorResponse(res, 'Gagal mengambil data izin');
  }
};

// ── Izin pending untuk approver ──────────────────────────────────────────────
const getPendingIzin = async (req, res) => {
  const { role, id_departemen } = req.user;

  try {
    // Base query — join ke profiles untuk nama & departemen
    let query = supabase
      .from('izin')
      .select(`
        *,
        profiles!id_karyawan (
          nama,
          email,
          id_departemen,
          departemen ( nama_departemen )
        )
      `)
      .eq('status', 'pending')
      .eq('current_approver_role', role)
      .eq('id_tenant', req.tenantId)
      .order('created_at', { ascending: false });

    // Manajer hanya lihat departemennya sendiri
    if (role === 'manajer' && id_departemen) {
      // Filter di sisi aplikasi setelah fetch (Supabase tidak support filter di nested relation langsung)
      const { data, error } = await query;
      if (error) throw error;

      const filtered = data.filter(
        (item) => item.profiles?.id_departemen === id_departemen
      );
      return successResponse(res, 'Daftar izin pending', filtered);
    }

    const { data, error } = await query;
    if (error) throw error;
    return successResponse(res, 'Daftar izin pending', data);
  } catch (err) {
    logger.error('[getPendingIzin]', err);
    return errorResponse(res, 'Gagal mengambil data izin pending');
  }
};

// ── Review izin (approve / reject) ──────────────────────────────────────────
const reviewIzin = async (req, res) => {
  const { id } = req.params;
  const { action, catatan } = req.body;
  const user = req.user;

  if (!['approve', 'reject'].includes(action)) {
    return errorResponse(res, 'Aksi tidak valid. Gunakan "approve" atau "reject"', 400);
  }

  try {
    // Ambil data izin
    const { data: izin, error: fetchErr } = await supabase
      .from('izin')
      .select('*')
      .eq('id', id)
      .eq('id_tenant', req.tenantId)
      .single();

    if (fetchErr || !izin) return errorResponse(res, 'Izin tidak ditemukan', 404);

    if (izin.status !== 'pending' || izin.current_approver_role !== user.role) {
      return errorResponse(res, 'Anda tidak berhak memproses izin ini atau izin sudah final', 403);
    }

    // Tentukan status & next approver
    let newStatus    = 'pending';
    let nextApprover = izin.current_approver_role;

    if (action === 'approve') {
      if (user.role === 'manajer') {
        nextApprover = 'hrd';           // Lanjut ke HRD
      } else if (user.role === 'hrd') {
        nextApprover = null;
        newStatus    = 'disetujui';    // Final approval
      }
    } else {
      newStatus    = 'ditolak';
      nextApprover = null;
    }

    // Update izin
    const { data: updated, error: updateErr } = await supabase
      .from('izin')
      .update({
        status:               newStatus,
        current_approver_role: nextApprover,
        id_approver:          user.id,
        catatan_approver:     catatan || null,
      })
      .eq('id', id)
      .eq('id_tenant', req.tenantId)
      .select()
      .single();

    if (updateErr) throw updateErr;

    // Insert log
    await supabase.from('izin_approval_logs').insert({
      id_izin:      id,
      id_approver:  user.id,
      role_approver: user.role,
      action,
      note:         catatan || null,
      id_tenant:    req.tenantId,
    });

    // Kirim notifikasi ke karyawan
    await supabase.from('notifikasi').insert({
      id_penerima: izin.id_karyawan,
      judul:       `Izin ${newStatus === 'disetujui' ? 'Disetujui ✓' : newStatus === 'ditolak' ? 'Ditolak ✗' : 'Diproses'}`,
      pesan:       `Izin ${izin.jenis_izin} Anda (${izin.tanggal_mulai} – ${izin.tanggal_selesai}) telah ${newStatus}.${catatan ? ' Catatan: ' + catatan : ''}`,
      jenis:       'izin',
      id_tenant:    req.tenantId,
    });

    const label = action === 'approve' ? 'disetujui' : 'ditolak';
    return successResponse(res, `Izin berhasil ${label}`, updated);
  } catch (err) {
    logger.error('[reviewIzin]', err);
    return errorResponse(res, 'Gagal memproses izin');
  }
};

module.exports = { applyIzin, getMyIzin, getPendingIzin, reviewIzin };
