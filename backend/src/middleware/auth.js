const { createClient } = require('@supabase/supabase-js');
const { errorResponse } = require('../utils/response');
require('dotenv').config();

// Client anon untuk verifikasi JWT (tidak perlu service key)
const supabaseAuth = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

/**
 * Middleware autentikasi — verifikasi Supabase JWT.
 * Attach req.user = { id, role, id_departemen, email }
 */
const authMiddleware = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return errorResponse(res, 'Unauthorized: No token provided', 401);
  }

  const token = authHeader.split(' ')[1];

  try {
    // Verifikasi token ke Supabase Auth
    const { data: { user }, error } = await supabaseAuth.auth.getUser(token);

    if (error || !user) {
      return errorResponse(res, 'Unauthorized: Token tidak valid atau kadaluarsa', 401);
    }

    // Ambil role & departemen dari tabel profiles
    const supabase = require('./supabase-service');
    const { data: profile, error: profileErr } = await supabase
      .from('profiles')
      .select('id, role, id_departemen, status_aktif')
      .eq('id', user.id)
      .single();

    if (profileErr || !profile) {
      return errorResponse(res, 'Unauthorized: Profil tidak ditemukan', 401);
    }

    if (!profile.status_aktif) {
      return errorResponse(res, 'Akun Anda belum diaktifkan oleh admin', 403);
    }

    req.user = {
      id:            user.id,
      email:         user.email,
      role:          profile.role,
      id_departemen: profile.id_departemen,
    };

    next();
  } catch (err) {
    console.error('[Auth] Error:', err.message);
    return errorResponse(res, 'Unauthorized: Token tidak valid', 401);
  }
};

/**
 * RBAC middleware — cek role yang diizinkan.
 */
const rbac = (allowedRoles) => (req, res, next) => {
  if (!req.user || !allowedRoles.includes(req.user.role)) {
    return errorResponse(res, 'Forbidden: Anda tidak memiliki akses', 403);
  }
  next();
};

module.exports = { authMiddleware, rbac };
