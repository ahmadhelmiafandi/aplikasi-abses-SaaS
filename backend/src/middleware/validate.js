const { z } = require('zod');
const xss   = require('xss');
const { errorResponse } = require('../utils/response');

/**
 * Sanitasi string dari XSS sebelum validasi.
 * Gunakan sebagai preprocessor untuk field string.
 */
const sanitizeString = z.string().transform((s) => xss(s.trim()));

/**
 * Middleware validasi input dengan Zod.
 * Jika validasi gagal, kembalikan 400 dengan detail error per field.
 * Jika lolos, `req.body` diganti dengan data yang sudah di-parse & sanitasi.
 */
const validate = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.body);
  if (!result.success) {
    const errors = result.error.issues.map((issue) => ({
      field:   issue.path.join('.') || 'body',
      message: issue.message,
    }));
    return res.status(400).json({
      success: false,
      message: 'Validasi gagal',
      errors,
    });
  }
  req.body = result.data;
  next();
};

// ── UUID format validation helper ─────────────────────────────────────────────
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const validateUUID = (paramName = 'id') => (req, res, next) => {
  const value = req.params[paramName];
  if (value && !UUID_REGEX.test(value)) {
    return errorResponse(res, `Parameter '${paramName}' bukan UUID yang valid`, 400);
  }
  next();
};

// ── Schemas ───────────────────────────────────────────────────────────────────

const checkInSchema = z.object({
  latitude:  z.number({ required_error: 'latitude wajib diisi' }).min(-90).max(90),
  longitude: z.number({ required_error: 'longitude wajib diisi' }).min(-180).max(180),
});

const scanQrSchema = z.object({
  qr_data:      z.string().min(1, 'qr_data wajib diisi'),
  lat_karyawan: z.number().min(-90).max(90),
  lng_karyawan: z.number().min(-180).max(180),
});

const applyIzinSchema = z.object({
  tanggal_mulai:   z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Format tanggal: YYYY-MM-DD'),
  tanggal_selesai: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Format tanggal: YYYY-MM-DD'),
  jenis_izin:      z.enum(['sakit', 'pribadi', 'cuti'], { errorMap: () => ({ message: 'Jenis izin tidak valid' }) }),
  alasan:          sanitizeString.pipe(z.string().min(5, 'Alasan minimal 5 karakter').max(500)).optional(),
});

const reviewIzinSchema = z.object({
  action:  z.enum(['approve', 'reject'], { errorMap: () => ({ message: 'Action harus approve atau reject' }) }),
  catatan: sanitizeString.pipe(z.string().max(500)).optional(),
});

const updateProfileSchema = z.object({
  nama:     sanitizeString.pipe(z.string().min(2, 'Nama minimal 2 karakter').max(100)),
  nomor_hp: z.union([z.string().max(20), z.null()]).optional().transform(v => v || null),
  alamat:   z.union([
    sanitizeString.pipe(z.string().max(500)),
    z.null(),
  ]).optional().transform(v => v || null),
});

// Password policy: min 8 karakter + minimal 1 huruf kapital + minimal 1 angka
const passwordSchema = z.string()
  .min(8, 'Password minimal 8 karakter')
  .regex(/[A-Z]/, 'Password harus mengandung minimal 1 huruf kapital')
  .regex(/[0-9]/, 'Password harus mengandung minimal 1 angka');

const updateUserSchema = z.object({
  nama:         sanitizeString.pipe(z.string().min(2).max(100)),
  email:        z.string().email('Email tidak valid').max(100),
  role:         z.enum(['karyawan', 'manajer', 'hrd', 'admin']),
  status_aktif: z.boolean(),
});

module.exports = {
  validate,
  validateUUID,
  checkInSchema,
  scanQrSchema,
  applyIzinSchema,
  reviewIzinSchema,
  updateProfileSchema,
  updateUserSchema,
  passwordSchema,
};
