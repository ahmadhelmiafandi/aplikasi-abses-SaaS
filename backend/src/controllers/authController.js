const supabase = require('../config/supabase');
const { successResponse, errorResponse } = require('../utils/response');

const login = (req, res) =>
  errorResponse(res, 'Login dilakukan melalui Supabase Auth di aplikasi. Endpoint ini tidak aktif.', 410);

const register = async (req, res) => {
  const { nama, email, password, nomorHp, alamat } = req.body;

  if (!nama || !email || !password) {
    return errorResponse(res, 'Nama, email, dan password wajib diisi.', 400);
  }

  try {
    // 1. Buat akun di Supabase Auth via admin client
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: email.trim(),
      password: password,
      email_confirm: true,
      user_metadata: { nama: nama.trim() }
    });

    if (authError) {
      if (authError.message.toLowerCase().includes('already registered') || authError.message.toLowerCase().includes('already exists')) {
        return errorResponse(res, 'Email sudah terdaftar.', 400);
      }
      return errorResponse(res, authError.message, 400);
    }

    const authUser = authData.user;    // 2. Insert profil ke tabel `profiles` dengan status_aktif = false
    const { error: profileError } = await supabase.from('profiles').insert({
      id: authUser.id,
      nama: nama.trim(),
      email: email.trim(),
      nomor_hp: nomorHp || null,
      alamat: alamat || null,
      role: 'karyawan',
      status_aktif: false, // Menunggu approval admin
      id_tenant: req.tenantId,
    });
    if (profileError) {
      // Clean up created auth user if profile creation fails
      await supabase.auth.admin.deleteUser(authUser.id);
      return errorResponse(res, `Gagal membuat profil: ${profileError.message}`, 400);
    }

    return successResponse(res, 'Registrasi berhasil. Menunggu approval admin.', null, 201);
  } catch (err) {
    return errorResponse(res, `Terjadi kesalahan saat registrasi: ${err.message}`, 500);
  }
};

const registerTenant = async (req, res) => {
  const { name, subdomain, adminNama, adminEmail, adminPass, adminHp } = req.body;

  if (!name || !subdomain || !adminEmail || !adminPass || !adminNama) {
    return errorResponse(res, 'Seluruh data wajib diisi.', 400);
  }

  try {
    const subClean = subdomain.toLowerCase().trim();

    // 1. Cek apakah subdomain sudah ada
    const { data: existingTenant } = await supabase
      .from('tenant')
      .select('id')
      .eq('subdomain', subClean)
      .maybeSingle();

    if (existingTenant) {
      return errorResponse(res, `Subdomain "${subClean}" sudah digunakan perusahaan lain.`, 400);
    }

    // 2. Insert record Tenant
    const { data: tenant, error: tenantErr } = await supabase
      .from('tenant')
      .insert({
        name: name.trim(),
        subdomain: subClean,
      })
      .select()
      .single();

    if (tenantErr) throw tenantErr;

    // 3. Insert Tenant Settings
    try {
      await supabase
        .from('tenant_settings')
        .insert({
          id_tenant: tenant.id,
          office_lat: -6.9826,
          office_lng: 110.4092,
          geofence_radius_meter: 100,
        });
    } catch (_) {}

    // 4. Buat akun Admin di Supabase Auth dengan email_confirm: true (agar langsung bisa login)
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: adminEmail.trim(),
      password: adminPass,
      email_confirm: true,
      user_metadata: {
        nama: adminNama.trim(),
        role: 'admin',
        id_tenant: tenant.id,
      }
    });

    if (authError) {
      if (authError.message.toLowerCase().includes('already registered') || authError.message.toLowerCase().includes('already exists')) {
        return errorResponse(res, 'Email admin sudah terdaftar di sistem. Gunakan email lain.', 400);
      }
      throw authError;
    }

    const authUser = authData.user;

    // 5. Insert profile admin di tabel profiles
    await supabase.from('profiles').upsert({
      id: authUser.id,
      nama: adminNama.trim(),
      email: adminEmail.trim(),
      nomor_hp: adminHp || null,
      role: 'admin',
      status_aktif: true,
      id_tenant: tenant.id,
    });

    return successResponse(res, 'Perusahaan dan akun Admin berhasil didaftarkan.', { tenant, user: authUser }, 201);
  } catch (err) {
    return errorResponse(res, `Gagal mendaftarkan perusahaan: ${err.message}`, 400);
  }
};

const refresh = (req, res) =>
  errorResponse(res, 'Token refresh dilakukan otomatis oleh Supabase SDK. Endpoint ini tidak aktif.', 410);

module.exports = { login, register, registerTenant, refresh };

