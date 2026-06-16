const supabase = require('../config/supabase');
const { successResponse, errorResponse } = require('../utils/response');

const getAllUsers = async (req, res) => {
  const { page = 1, limit = 50, search = '' } = req.query;
  const from = (page - 1) * limit;
  const to   = from + parseInt(limit) - 1;

  try {
    let query = supabase
      .from('profiles')
      .select('id, nama, email, role, status_aktif, id_departemen, departemen(nama_departemen)', { count: 'exact' })
      .eq('id_tenant', req.tenantId)
      .order('nama');

    if (search) {
      query = query.or(`nama.ilike.%${search}%,email.ilike.%${search}%`);
    }

    const { data, count, error } = await query.range(from, to);
    if (error) throw error;

    return successResponse(res, 'Daftar pengguna', {
      data,
      pagination: { total: count, page: parseInt(page), limit: parseInt(limit) },
    });
  } catch (err) {
    return errorResponse(res, 'Gagal mengambil data pengguna');
  }
};

const updateUser = async (req, res) => {
  const { id } = req.params;
  const { nama, email, role, status_aktif } = req.body;
  const validRoles = ['karyawan', 'manajer', 'hrd', 'admin'];

  if (!validRoles.includes(role)) {
    return errorResponse(res, 'Role tidak valid', 400);
  }

  try {
    const { data, error } = await supabase
      .from('profiles')
      .update({ nama, email, role, status_aktif })
      .eq('id', id)
      .eq('id_tenant', req.tenantId)
      .select()
      .single();

    if (error) throw error;
    if (!data) return errorResponse(res, 'Pengguna tidak ditemukan', 404);

    return successResponse(res, 'Data pengguna berhasil diperbarui', data);
  } catch (err) {
    return errorResponse(res, 'Gagal memperbarui data pengguna');
  }
};

// Soft delete — nonaktifkan saja, tidak hapus dari DB
const deactivateUser = async (req, res) => {
  const { id } = req.params;

  try {
    const { data, error } = await supabase
      .from('profiles')
      .update({ status_aktif: false })
      .eq('id', id)
      .eq('id_tenant', req.tenantId)
      .select()
      .single();

    if (error) throw error;
    if (!data) return errorResponse(res, 'Pengguna tidak ditemukan', 404);

    return successResponse(res, 'Akun pengguna dinonaktifkan');
  } catch (err) {
    return errorResponse(res, 'Gagal menonaktifkan pengguna');
  }
};

module.exports = { getAllUsers, updateUser, deactivateUser };
