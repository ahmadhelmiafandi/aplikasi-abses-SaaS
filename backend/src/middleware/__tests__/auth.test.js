/**
 * Unit tests untuk auth middleware dan rbac middleware.
 */

const mockGetUser = jest.fn();
const mockSingle = jest.fn();

// Mock @supabase/supabase-js sebelum require middleware
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => ({
    auth: {
      getUser: (...args) => mockGetUser(...args),
    },
  })),
}));

// Mock supabase-service (database client)
jest.mock('../supabase-service', () => ({
  from: jest.fn(() => ({
    select: jest.fn().mockReturnThis(),
    eq:     jest.fn().mockReturnThis(),
    single: (...args) => mockSingle(...args),
  })),
}));

const { authMiddleware, rbac } = require('../auth');

// Helper mock req/res/next
const mockReq = (headers = {}, user = null) => ({
  headers,
  user,
  ip: '127.0.0.1',
});
const mockRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json   = jest.fn().mockReturnValue(res);
  return res;
};
const mockNext = jest.fn();

describe('authMiddleware', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('gagal jika Authorization header tidak ada', async () => {
    const req = mockReq({});
    const res = mockRes();

    await authMiddleware(req, res, mockNext);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, message: expect.stringContaining('No token provided') })
    );
    expect(mockNext).not.toHaveBeenCalled();
  });

  test('gagal jika Authorization header tidak diawali dengan Bearer', async () => {
    const req = mockReq({ authorization: 'Token-Salah abc' });
    const res = mockRes();

    await authMiddleware(req, res, mockNext);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(mockNext).not.toHaveBeenCalled();
  });

  test('gagal jika token tidak valid/kadaluarsa', async () => {
    const req = mockReq({ authorization: 'Bearer token-invalid' });
    const res = mockRes();

    mockGetUser.mockResolvedValue({
      data: { user: null },
      error: { message: 'Token invalid' },
    });

    await authMiddleware(req, res, mockNext);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, message: expect.stringContaining('Token tidak valid atau kadaluarsa') })
    );
    expect(mockNext).not.toHaveBeenCalled();
  });

  test('gagal jika profil user tidak ditemukan', async () => {
    const req = mockReq({ authorization: 'Bearer token-valid' });
    const res = mockRes();

    mockGetUser.mockResolvedValue({
      data: { user: { id: 'user-id-123', email: 'test@example.com' } },
      error: null,
    });

    // Mock profiles select query returning null/error
    mockSingle.mockResolvedValue({ data: null, error: { message: 'Profile not found' } });

    await authMiddleware(req, res, mockNext);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, message: expect.stringContaining('Profil tidak ditemukan') })
    );
    expect(mockNext).not.toHaveBeenCalled();
  });

  test('gagal jika akun belum diaktifkan', async () => {
    const req = mockReq({ authorization: 'Bearer token-valid' });
    const res = mockRes();

    mockGetUser.mockResolvedValue({
      data: { user: { id: 'user-id-123', email: 'test@example.com' } },
      error: null,
    });

    mockSingle.mockResolvedValue({
      data: { id: 'user-id-123', role: 'karyawan', id_departemen: 'dept-123', status_aktif: false },
      error: null,
    });

    await authMiddleware(req, res, mockNext);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, message: expect.stringContaining('belum diaktifkan') })
    );
    expect(mockNext).not.toHaveBeenCalled();
  });

  test('berhasil set req.user dan panggil next jika data valid', async () => {
    const req = mockReq({ authorization: 'Bearer token-valid' });
    const res = mockRes();

    mockGetUser.mockResolvedValue({
      data: { user: { id: 'user-id-123', email: 'test@example.com' } },
      error: null,
    });

    mockSingle.mockResolvedValue({
      data: { id: 'user-id-123', role: 'karyawan', id_departemen: 'dept-123', status_aktif: true },
      error: null,
    });

    await authMiddleware(req, res, mockNext);

    expect(mockNext).toHaveBeenCalled();
    expect(req.user).toEqual({
      id: 'user-id-123',
      email: 'test@example.com',
      role: 'karyawan',
      id_departemen: 'dept-123',
    });
  });
});

describe('rbac middleware', () => {
  test('lolos jika role user ada di allowedRoles', () => {
    const req = mockReq({}, { id: 'user-id-123', role: 'manajer' });
    const res = mockRes();
    const next = jest.fn();

    rbac(['manajer', 'hrd'])(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(res.status).not.toHaveBeenCalled();
  });

  test('gagal jika role user tidak ada di allowedRoles', () => {
    const req = mockReq({}, { id: 'user-id-123', role: 'karyawan' });
    const res = mockRes();
    const next = jest.fn();

    rbac(['manajer', 'hrd'])(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(403);
  });
});
