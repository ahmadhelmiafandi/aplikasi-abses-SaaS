const supabase = require('../config/supabase');
const { successResponse, errorResponse } = require('../utils/response');

// ── TENANTS CRUD ─────────────────────────────────────────────────────────────

/**
 * Buat Tenant baru beserta konfigurasinya.
 */
const createTenant = async (req, res) => {
  const { name, subdomain, id_plan, office_lat, office_lng, geofence_radius_meter } = req.body;

  if (!name || !subdomain) {
    return errorResponse(res, 'Name dan subdomain wajib diisi', 400);
  }

  try {
    // 1. Insert Tenant
    const { data: tenant, error: tenantErr } = await supabase
      .from('tenant')
      .insert({
        name,
        subdomain: subdomain.toLowerCase().trim(),
        id_plan: id_plan || null,
      })
      .select()
      .single();

    if (tenantErr) throw tenantErr;

    // 2. Insert Settings
    const { data: settings, error: settingsErr } = await supabase
      .from('tenant_settings')
      .insert({
        id_tenant: tenant.id,
        office_lat: office_lat || -6.9826,
        office_lng: office_lng || 110.4092,
        geofence_radius_meter: geofence_radius_meter || 100,
      })
      .select()
      .single();

    if (settingsErr) throw settingsErr;

    return successResponse(res, 'Tenant berhasil dibuat', { tenant, settings }, 201);
  } catch (err) {
    return errorResponse(res, `Gagal membuat tenant: ${err.message}`);
  }
};

/**
 * Ambil daftar seluruh tenant.
 */
const getTenants = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('tenant')
      .select('*, tenant_settings(*), subscription_plans(*)');

    if (error) throw error;
    return successResponse(res, 'Daftar tenant berhasil diambil', data);
  } catch (err) {
    return errorResponse(res, 'Gagal mengambil daftar tenant');
  }
};

/**
 * Update plan subscription tenant.
 */
const updateTenantPlan = async (req, res) => {
  const { id } = req.params;
  const { id_plan, status, name, subdomain, office_lat, office_lng, geofence_radius_meter } = req.body;

  try {
    const updates = {};
    if (id_plan !== undefined) updates.id_plan = id_plan;
    if (status !== undefined) updates.subscription_status = status;
    if (name !== undefined) updates.name = name;
    if (subdomain !== undefined) updates.subdomain = subdomain.toLowerCase().trim();

    const { data, error } = await supabase
      .from('tenant')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    // Update settings if latitude, longitude, or radius is updated
    if (office_lat !== undefined || office_lng !== undefined || geofence_radius_meter !== undefined) {
      const settingsUpdates = {};
      if (office_lat !== undefined) settingsUpdates.office_lat = office_lat;
      if (office_lng !== undefined) settingsUpdates.office_lng = office_lng;
      if (geofence_radius_meter !== undefined) settingsUpdates.geofence_radius_meter = geofence_radius_meter;

      await supabase
        .from('tenant_settings')
        .update(settingsUpdates)
        .eq('id_tenant', id);
    }

    return successResponse(res, 'Plan tenant berhasil diperbarui', data);
  } catch (err) {
    return errorResponse(res, `Gagal mengupdate plan tenant: ${err.message}`);
  }
};

/**
 * Hapus Tenant secara permanen.
 */
const deleteTenant = async (req, res) => {
  const { id } = req.params;
  try {
    const { error } = await supabase
      .from('tenant')
      .delete()
      .eq('id', id);

    if (error) throw error;
    return successResponse(res, 'Tenant berhasil dihapus');
  } catch (err) {
    return errorResponse(res, `Gagal menghapus tenant: ${err.message}`);
  }
};

/**
 * Statistik penggunaan/karyawan per tenant.
 */
const getTenantAnalytics = async (req, res) => {
  try {
    const { data: tenants, error: tenantsErr } = await supabase
      .from('tenant')
      .select('id, name, subdomain');

    if (tenantsErr) throw tenantsErr;

    const analytics = [];

    for (const t of tenants) {
      const { count, error } = await supabase
        .from('profiles')
        .select('id', { count: 'exact', head: true })
        .eq('id_tenant', t.id);

      analytics.push({
        tenant_id: t.id,
        name: t.name,
        subdomain: t.subdomain,
        employee_count: error ? 0 : count,
      });
    }

    return successResponse(res, 'Analitik tenant berhasil diambil', analytics);
  } catch (err) {
    return errorResponse(res, 'Gagal mengambil analitik tenant');
  }
};

// ── PLANS CRUD ───────────────────────────────────────────────────────────────

const getPlans = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('subscription_plans')
      .select('*')
      .order('created_at', { ascending: true });
    if (error) throw error;
    return successResponse(res, 'Daftar plan berhasil diambil', data);
  } catch (err) {
    return errorResponse(res, `Gagal mengambil daftar plan: ${err.message}`);
  }
};

const createPlan = async (req, res) => {
  const { name, max_employees, features } = req.body;
  try {
    const { data, error } = await supabase
      .from('subscription_plans')
      .insert({ name, max_employees, features })
      .select()
      .single();
    if (error) throw error;
    return successResponse(res, 'Plan berhasil dibuat', data, 201);
  } catch (err) {
    return errorResponse(res, `Gagal membuat plan: ${err.message}`);
  }
};

const updatePlan = async (req, res) => {
  const { id } = req.params;
  const { name, max_employees, features } = req.body;
  try {
    const { data, error } = await supabase
      .from('subscription_plans')
      .update({ name, max_employees, features })
      .eq('id', id)
      .select()
      .single();
    if (error) throw error;
    return successResponse(res, 'Plan berhasil diperbarui', data);
  } catch (err) {
    return errorResponse(res, `Gagal mengupdate plan: ${err.message}`);
  }
};

const deletePlan = async (req, res) => {
  const { id } = req.params;
  try {
    const { error } = await supabase
      .from('subscription_plans')
      .delete()
      .eq('id', id);
    if (error) throw error;
    return successResponse(res, 'Plan berhasil dihapus');
  } catch (err) {
    return errorResponse(res, `Gagal menghapus plan: ${err.message}`);
  }
};

// ── USERS CRUD ───────────────────────────────────────────────────────────────

const getUsers = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('*, tenant(name)');
    if (error) throw error;
    return successResponse(res, 'Daftar user berhasil diambil', data);
  } catch (err) {
    return errorResponse(res, `Gagal mengambil daftar user: ${err.message}`);
  }
};

const createUser = async (req, res) => {
  const { nama, email, password, role, id_tenant, status_aktif, nomorHp, alamat } = req.body;
  try {
    // 1. Buat user di auth
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: email.trim(),
      password: password,
      email_confirm: true,
      user_metadata: { nama: nama.trim() }
    });
    if (authError) throw authError;

    // 2. Buat profil
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .insert({
        id: authData.user.id,
        nama: nama.trim(),
        email: email.trim(),
        role: role || 'karyawan',
        id_tenant: id_tenant || null,
        status_aktif: status_aktif !== undefined ? status_aktif : true,
        nomor_hp: nomorHp || null,
        alamat: alamat || null
      })
      .select()
      .single();

    if (profileError) {
      // Rollback auth user
      await supabase.auth.admin.deleteUser(authData.user.id);
      throw profileError;
    }

    return successResponse(res, 'User berhasil dibuat', profile, 201);
  } catch (err) {
    return errorResponse(res, `Gagal membuat user: ${err.message}`);
  }
};

const updateUser = async (req, res) => {
  const { id } = req.params;
  const { nama, email, role, id_tenant, status_aktif, nomor_hp, alamat } = req.body;
  try {
    const updates = {};
    if (nama !== undefined) updates.nama = nama;
    if (email !== undefined) updates.email = email;
    if (role !== undefined) updates.role = role;
    if (id_tenant !== undefined) updates.id_tenant = id_tenant;
    if (status_aktif !== undefined) updates.status_aktif = status_aktif;
    if (nomor_hp !== undefined) updates.nomor_hp = nomor_hp;
    if (alamat !== undefined) updates.alamat = alamat;

    const { data, error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', id)
      .select()
      .single();
    if (error) throw error;

    // Update email di auth juga jika diubah
    if (email) {
      await supabase.auth.admin.updateUserById(id, { email: email.trim() });
    }

    return successResponse(res, 'User berhasil diperbarui', data);
  } catch (err) {
    return errorResponse(res, `Gagal mengupdate user: ${err.message}`);
  }
};

const deleteUser = async (req, res) => {
  const { id } = req.params;
  try {
    // Menghapus auth user otomatis mencascade ke profiles
    const { error } = await supabase.auth.admin.deleteUser(id);
    if (error) throw error;
    return successResponse(res, 'User berhasil dihapus');
  } catch (err) {
    return errorResponse(res, `Gagal menghapus user: ${err.message}`);
  }
};

// ── ATTENDANCE CRUD ──────────────────────────────────────────────────────────

const getAbsensi = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('absensi')
      .select('*, profiles(nama, email), tenant(name)')
      .order('tanggal', { ascending: false });
    if (error) throw error;
    return successResponse(res, 'Daftar absensi berhasil diambil', data);
  } catch (err) {
    return errorResponse(res, `Gagal mengambil daftar absensi: ${err.message}`);
  }
};

const updateAbsensi = async (req, res) => {
  const { id } = req.params;
  const { tanggal, jam_masuk, jam_keluar, status, menit_terlambat, keterangan } = req.body;
  try {
    const updates = {};
    if (tanggal !== undefined) updates.tanggal = tanggal;
    if (jam_masuk !== undefined) updates.jam_masuk = jam_masuk;
    if (jam_keluar !== undefined) updates.jam_keluar = jam_keluar;
    if (status !== undefined) updates.status = status;
    if (menit_terlambat !== undefined) updates.menit_terlambat = menit_terlambat;
    if (keterangan !== undefined) updates.keterangan = keterangan;

    const { data, error } = await supabase
      .from('absensi')
      .update(updates)
      .eq('id', id)
      .select()
      .single();
    if (error) throw error;
    return successResponse(res, 'Absensi berhasil diperbarui', data);
  } catch (err) {
    return errorResponse(res, `Gagal mengupdate absensi: ${err.message}`);
  }
};

const deleteAbsensi = async (req, res) => {
  const { id } = req.params;
  try {
    const { error } = await supabase
      .from('absensi')
      .delete()
      .eq('id', id);
    if (error) throw error;
    return successResponse(res, 'Absensi berhasil dihapus');
  } catch (err) {
    return errorResponse(res, `Gagal menghapus absensi: ${err.message}`);
  }
};

// ── LEAVE REQUESTS CRUD ──────────────────────────────────────────────────────

const getIzin = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('izin')
      .select('*, profiles(nama, email), tenant(name)')
      .order('created_at', { ascending: false });
    if (error) throw error;
    return successResponse(res, 'Daftar izin berhasil diambil', data);
  } catch (err) {
    return errorResponse(res, `Gagal mengambil daftar izin: ${err.message}`);
  }
};

const updateIzin = async (req, res) => {
  const { id } = req.params;
  const { status, tanggal_mulai, tanggal_selesai, jenis_izin, alasan, catatan_approver } = req.body;
  try {
    const updates = {};
    if (status !== undefined) updates.status = status;
    if (tanggal_mulai !== undefined) updates.tanggal_mulai = tanggal_mulai;
    if (tanggal_selesai !== undefined) updates.tanggal_selesai = tanggal_selesai;
    if (jenis_izin !== undefined) updates.jenis_izin = jenis_izin;
    if (alasan !== undefined) updates.alasan = alasan;
    if (catatan_approver !== undefined) updates.catatan_approver = catatan_approver;

    const { data, error } = await supabase
      .from('izin')
      .update(updates)
      .eq('id', id)
      .select()
      .single();
    if (error) throw error;
    return successResponse(res, 'Izin berhasil diperbarui', data);
  } catch (err) {
    return errorResponse(res, `Gagal mengupdate izin: ${err.message}`);
  }
};

const deleteIzin = async (req, res) => {
  const { id } = req.params;
  try {
    const { error } = await supabase
      .from('izin')
      .delete()
      .eq('id', id);
    if (error) throw error;
    return successResponse(res, 'Izin berhasil dihapus');
  } catch (err) {
    return errorResponse(res, `Gagal menghapus izin: ${err.message}`);
  }
};

module.exports = {
  createTenant,
  getTenants,
  updateTenantPlan,
  deleteTenant,
  getTenantAnalytics,
  
  getPlans,
  createPlan,
  updatePlan,
  deletePlan,

  getUsers,
  createUser,
  updateUser,
  deleteUser,

  getAbsensi,
  updateAbsensi,
  deleteAbsensi,

  getIzin,
  updateIzin,
  deleteIzin
};
