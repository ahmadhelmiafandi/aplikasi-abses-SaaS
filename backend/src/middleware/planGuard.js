const { errorResponse } = require('../utils/response');
const supabase = require('../config/supabase');

/**
 * Middleware untuk membatasi akses berdasarkan fitur plan subscription.
 */
const planGuard = (requiredFeature) => (req, res, next) => {
  const plan = req.tenant?.subscription_plans;
  
  if (!plan) {
    return errorResponse(res, 'Plan subscription tidak aktif', 403);
  }

  const features = plan.features || [];
  if (!features.includes(requiredFeature)) {
    return errorResponse(
      res, 
      `Fitur "${requiredFeature}" tidak didukung oleh paket subscription Anda (${plan.name}). Silakan upgrade plan.`, 
      403
    );
  }

  next();
};

/**
 * Middleware untuk membatasi penambahan karyawan melebihi kapasitas limit plan.
 */
const karyawanLimitGuard = async (req, res, next) => {
  const plan = req.tenant?.subscription_plans;
  
  if (!plan) {
    return errorResponse(res, 'Plan subscription tidak aktif', 403);
  }

  try {
    // Hitung jumlah karyawan terdaftar di tenant ini
    const { count, error } = await supabase
      .from('profiles')
      .select('id', { count: 'exact', head: true })
      .eq('id_tenant', req.tenantId);

    if (error) throw error;

    if (count >= plan.max_employees) {
      return errorResponse(
        res,
        `Batas maksimum karyawan untuk paket ${plan.name} (${plan.max_employees} orang) telah terpenuhi. Silakan upgrade plan Anda.`,
        403
      );
    }

    next();
  } catch (err) {
    return errorResponse(res, 'Gagal memverifikasi limitasi karyawan', 500);
  }
};

module.exports = { planGuard, karyawanLimitGuard };
