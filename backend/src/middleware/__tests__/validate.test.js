/**
 * Unit tests untuk validate middleware dan validateUUID
 */
const { validate, validateUUID, checkInSchema, applyIzinSchema, scanQrSchema } = require('../validate');

// Helper: buat mock req/res/next
const mockReq  = (body = {}, params = {}) => ({ body, params });
const mockRes  = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json   = jest.fn().mockReturnValue(res);
  return res;
};
const mockNext = jest.fn();

beforeEach(() => {
  mockNext.mockClear();
});

// ── validate() ────────────────────────────────────────────────────────────────
describe('validate middleware', () => {
  describe('checkInSchema', () => {
    test('lolos dengan latitude dan longitude valid', () => {
      const req = mockReq({ latitude: -6.9826, longitude: 110.4092 });
      const res = mockRes();
      validate(checkInSchema)(req, res, mockNext);
      expect(mockNext).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
    });

    test('gagal jika latitude tidak ada', () => {
      const req = mockReq({ longitude: 110.4092 });
      const res = mockRes();
      validate(checkInSchema)(req, res, mockNext);
      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, message: 'Validasi gagal' })
      );
      expect(mockNext).not.toHaveBeenCalled();
    });

    test('gagal jika latitude di luar range -90 sampai 90', () => {
      const req = mockReq({ latitude: -91, longitude: 110.4092 });
      const res = mockRes();
      validate(checkInSchema)(req, res, mockNext);
      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('gagal jika longitude di luar range -180 sampai 180', () => {
      const req = mockReq({ latitude: -6.9826, longitude: 181 });
      const res = mockRes();
      validate(checkInSchema)(req, res, mockNext);
      expect(res.status).toHaveBeenCalledWith(400);
    });
  });

  describe('applyIzinSchema', () => {
    const validBody = {
      tanggal_mulai:   '2026-06-15',
      tanggal_selesai: '2026-06-17',
      jenis_izin:      'sakit',
      alasan:          'Demam tinggi',
    };

    test('lolos dengan data izin valid', () => {
      const req = mockReq(validBody);
      const res = mockRes();
      validate(applyIzinSchema)(req, res, mockNext);
      expect(mockNext).toHaveBeenCalled();
    });

    test('gagal jika jenis_izin tidak valid', () => {
      const req = mockReq({ ...validBody, jenis_izin: 'liburan' });
      const res = mockRes();
      validate(applyIzinSchema)(req, res, mockNext);
      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('gagal jika format tanggal salah', () => {
      const req = mockReq({ ...validBody, tanggal_mulai: '15-06-2026' });
      const res = mockRes();
      validate(applyIzinSchema)(req, res, mockNext);
      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('gagal jika alasan kurang dari 5 karakter', () => {
      const req = mockReq({ ...validBody, alasan: 'ok' });
      const res = mockRes();
      validate(applyIzinSchema)(req, res, mockNext);
      expect(res.status).toHaveBeenCalledWith(400);
    });
  });
});

// ── validateUUID() ────────────────────────────────────────────────────────────
describe('validateUUID middleware', () => {
  test('lolos dengan UUID v4 valid', () => {
    const req = mockReq({}, { id: '550e8400-e29b-41d4-a716-446655440000' });
    const res = mockRes();
    validateUUID('id')(req, res, mockNext);
    expect(mockNext).toHaveBeenCalled();
  });

  test('gagal dengan ID yang bukan UUID', () => {
    const req = mockReq({}, { id: 'bukan-uuid' });
    const res = mockRes();
    validateUUID('id')(req, res, mockNext);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false })
    );
  });

  test('gagal dengan SQL injection attempt', () => {
    const req = mockReq({}, { id: "1; DROP TABLE profiles; --" });
    const res = mockRes();
    validateUUID('id')(req, res, mockNext);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  test('lolos jika param tidak ada (opsional)', () => {
    const req = mockReq({}, {});
    const res = mockRes();
    validateUUID('id')(req, res, mockNext);
    expect(mockNext).toHaveBeenCalled();
  });
});
