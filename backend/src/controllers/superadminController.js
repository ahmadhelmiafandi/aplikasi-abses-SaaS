const supabase = require('../config/supabase');
const { successResponse, errorResponse } = require('../utils/response');

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
  const { id_plan, status } = req.body;

  try {
    const updates = {};
    if (id_plan !== undefined) updates.id_plan = id_plan;
    if (status !== undefined) updates.subscription_status = status;

    const { data, error } = await supabase
      .from('tenant')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    return successResponse(res, 'Plan tenant berhasil diperbarui', data);
  } catch (err) {
    return errorResponse(res, `Gagal mengupdate plan tenant: ${err.message}`);
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

module.exports = { createTenant, getTenants, updateTenantPlan, getTenantAnalytics };
