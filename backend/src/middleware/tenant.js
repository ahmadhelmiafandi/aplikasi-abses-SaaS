const supabase = require('../config/supabase');
const { errorResponse } = require('../utils/response');

/**
 * Middleware untuk memetakan request ke tenant yang aktif.
 * Meng-inject:
 *   - req.tenantId: UUID tenant
 *   - req.tenant: Objek tenant
 *   - req.tenantSettings: Konfigurasi kantor (lat, lng, radius)
 */
const tenantResolver = async (req, res, next) => {
  let tenantId = req.headers['x-tenant-id'];
  let subdomain = null;

  // Cek subdomain resolver (contoh: companya.localhost:3000 -> companya)
  const host = req.headers.host || '';
  const parts = host.split('.');
  
  if (parts.length > 1) {
    const candidate = parts[0].toLowerCase();
    if (candidate !== 'www' && candidate !== 'localhost' && candidate !== '127' && candidate !== '0') {
      subdomain = candidate;
    }
  }

  try {
    let tenant;

    if (tenantId) {
      // Resolve berdasarkan Tenant ID header (dukung UUID, mock ID pengujian, dan subdomain string)
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      const isUUID = uuidRegex.test(tenantId) || tenantId.startsWith('tenant-');

      const query = supabase
        .from('tenant')
        .select('*, tenant_settings(*), subscription_plans(*)')
        .eq('subscription_status', 'active');

      if (isUUID) {
        query.eq('id', tenantId);
      } else {
        query.eq('subdomain', tenantId.toLowerCase().trim());
      }

      const { data, error } = await query.maybeSingle();

      if (error || !data) {
        return errorResponse(res, 'Tenant tidak aktif atau tidak ditemukan', 400);
      }
      tenant = data;
    } else if (subdomain) {
      // Resolve berdasarkan Subdomain
      const { data, error } = await supabase
        .from('tenant')
        .select('*, tenant_settings(*), subscription_plans(*)')
        .eq('subdomain', subdomain)
        .eq('subscription_status', 'active')
        .maybeSingle();

      if (error || !data) {
        return errorResponse(res, 'Tenant subdomain tidak aktif atau tidak ditemukan', 400);
      }
      tenant = data;
    } else {
      // Fallback default tenant (interia) untuk backward compatibility
      const { data, error } = await supabase
        .from('tenant')
        .select('*, tenant_settings(*), subscription_plans(*)')
        .eq('subdomain', 'interia')
        .maybeSingle();

      if (error || !data) {
        return errorResponse(res, 'Default tenant tidak terkonfigurasi. Silakan jalankan migrasi SQL.', 500);
      }
      tenant = data;
    }

    req.tenantId = tenant.id;
    req.tenant = tenant;
    req.tenantSettings = tenant.tenant_settings || {
      office_lat: -6.9826,
      office_lng: 110.4092,
      geofence_radius_meter: 100,
    };

    next();
  } catch (err) {
    return errorResponse(res, 'Gagal memproses resolver tenant', 500);
  }
};

module.exports = tenantResolver;
