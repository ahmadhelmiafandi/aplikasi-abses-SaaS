const supabase = require('../config/supabase');
const { successResponse, errorResponse } = require('../utils/response');

const getProfile = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('*, departemen(nama_departemen)')
      .eq('id', req.user.id)
      .eq('id_tenant', req.tenantId)
      .single();

    if (error) throw error;
    return successResponse(res, 'Profil user', data);
  } catch (err) {
    return errorResponse(res, 'Gagal mengambil profil');
  }
};

const updateProfile = async (req, res) => {
  const { nama, nomor_hp, alamat } = req.body;
  if (!nama) return errorResponse(res, 'Nama tidak boleh kosong', 400);

  try {
    const { data, error } = await supabase
      .from('profiles')
      .update({
        nama,
        nomor_hp: nomor_hp ?? null,
        alamat:   alamat   ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', req.user.id)
      .eq('id_tenant', req.tenantId)
      .select()
      .single();

    if (error) throw error;
    return successResponse(res, 'Profil berhasil diperbarui', data);
  } catch (err) {
    return errorResponse(res, 'Gagal memperbarui profil');
  }
};

// Ganti password — dilakukan via Supabase Auth (bukan custom bcrypt)
// Endpoint ini sebagai proxy jika dibutuhkan dari backend
const changePassword = async (req, res) => {
  return errorResponse(
    res,
    'Ganti password dilakukan langsung via Supabase Auth SDK di aplikasi.',
    410
  );
};

module.exports = { getProfile, updateProfile, changePassword };
