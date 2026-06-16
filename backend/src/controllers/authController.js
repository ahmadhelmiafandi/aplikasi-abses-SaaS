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

const refresh = (req, res) =>
  errorResponse(res, 'Token refresh dilakukan otomatis oleh Supabase SDK. Endpoint ini tidak aktif.', 410);

module.exports = { login, register, refresh };

