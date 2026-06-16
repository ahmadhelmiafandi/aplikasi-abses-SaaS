const request = require('supertest');
const app = require('../../app');
const { DateTime } = require('luxon');

// Valid UUIDs for database and validation simulation
const ADMIN_UUID = 'e1111111-1111-4111-8111-111111111111';
const MANAGER_UUID = 'e2222222-2222-4222-8222-222222222222';
const HRD_UUID = 'e3333333-3333-4333-8333-333333333333';
const NEW_USER_UUID = 'e4444444-4444-4444-8444-444444444444';

// In-memory mock database state
let mockFakeUsers = [];
let mockFakeTenants = [];
let mockFakeProfiles = [];
let mockFakeAbsensi = [];
let mockFakeIzin = [];
let mockFakeShift = [];
let mockFakeJadwalKaryawan = [];
let mockFakeNotifikasi = [];

// Reset helper
function resetMockDb() {
  mockFakeUsers = [
    { id: ADMIN_UUID, email: 'admin@interia.com', role: 'admin', status_aktif: true, id_tenant: 'tenant-123' },
    { id: MANAGER_UUID, email: 'manager@interia.com', role: 'manajer', status_aktif: true, id_departemen: 'dept-123', id_tenant: 'tenant-123' },
    { id: HRD_UUID, email: 'hrd@interia.com', role: 'hrd', status_aktif: true, id_tenant: 'tenant-123' },
  ];
  mockFakeTenants = [
    {
      id: 'tenant-123',
      subdomain: 'interia',
      subscription_status: 'active',
      tenant_settings: {
        office_lat: -6.9826,
        office_lng: 110.4092,
        geofence_radius_meter: 100
      }
    }
  ];
  mockFakeProfiles = [
    { id: ADMIN_UUID, nama: 'Admin', email: 'admin@interia.com', role: 'admin', status_aktif: true, id_tenant: 'tenant-123' },
    { id: MANAGER_UUID, nama: 'Manager', email: 'manager@interia.com', role: 'manajer', status_aktif: true, id_departemen: 'dept-123', id_tenant: 'tenant-123' },
    { id: HRD_UUID, nama: 'HRD', email: 'hrd@interia.com', role: 'hrd', status_aktif: true, id_tenant: 'tenant-123' },
  ];
  mockFakeAbsensi = [];
  mockFakeIzin = [];
  mockFakeShift = [
    { id: 'shift-123', nama_shift: 'Shift Pagi', jam_masuk: '08:00:00', jam_keluar: '17:00:00', is_aktif: true, is_default_global: true }
  ];
  mockFakeJadwalKaryawan = [];
  mockFakeNotifikasi = [];
}

class MockQueryBuilder {
  constructor(tableName, data) {
    this.tableName = tableName;
    this.data = data;
    this.filtered = [...data];
    this.isSingle = false;
    this.isMaybeSingle = false;
    this.hasCount = false;
    this.updatePayload = null;
  }

  select(fields, options) {
    if (options && options.count === 'exact') {
      this.hasCount = true;
    }
    return this;
  }

  eq(key, value) {
    this.filtered = this.filtered.filter(item => item[key] === value);
    return this;
  }

  in(key, values) {
    this.filtered = this.filtered.filter(item => values.includes(item[key]));
    return this;
  }

  gte(key, value) {
    this.filtered = this.filtered.filter(item => item[key] >= value);
    return this;
  }

  lt(key, value) {
    this.filtered = this.filtered.filter(item => item[key] < value);
    return this;
  }

  order(key, options = { ascending: true }) {
    const asc = options.ascending !== false;
    this.filtered.sort((a, b) => {
      if (a[key] < b[key]) return asc ? -1 : 1;
      if (a[key] > b[key]) return asc ? 1 : -1;
      return 0;
    });
    return this;
  }

  limit(n) {
    this.filtered = this.filtered.slice(0, n);
    return this;
  }

  range(from, to) {
    const sliced = this.filtered.slice(from, to + 1);
    return Promise.resolve({
      data: sliced,
      count: this.filtered.length,
      error: null
    });
  }

  single() {
    this.isSingle = true;
    return this;
  }

  maybeSingle() {
    this.isMaybeSingle = true;
    return this;
  }

  or(clause) {
    const match = clause.match(/%([^%]+)%/);
    if (match) {
      const searchStr = match[1].toLowerCase();
      this.filtered = this.filtered.filter(item => {
        return (item.nama && item.nama.toLowerCase().includes(searchStr)) || 
               (item.email && item.email.toLowerCase().includes(searchStr));
      });
    }
    return this;
  }

  insert(obj) {
    const items = Array.isArray(obj) ? obj : [obj];
    const inserted = [];
    for (const item of items) {
      const newId = item.id || require('crypto').randomUUID();
      const newItem = { id: newId, ...item };
      this.data.push(newItem);
      inserted.push(newItem);
    }
    this.filtered = inserted;
    return this;
  }

  update(obj) {
    this.updatePayload = obj;
    return this;
  }

  _mapRelations(item, tableName = this.tableName) {
    if (!item) return null;
    const copy = { ...item };
    if (tableName === 'profiles') {
      copy.departemen = { nama_departemen: 'IT Department', default_shift_id: 'shift-123' };
    }
    if (tableName === 'izin') {
      const profile = mockFakeProfiles.find(p => p.id === item.id_karyawan) || {};
      copy.profiles = this._mapRelations(profile, 'profiles');
    }
    if (tableName === 'tenant') {
      copy.tenant_settings = { office_lat: -6.9826, office_lng: 110.4092, geofence_radius_meter: 100 };
      copy.subscription_plans = { id: 'plan-pro', name: 'Pro', max_employees: 10, features: ['all'] };
    }
    return copy;
  }

  then(onFulfilled, onRejected) {
    if (this.updatePayload) {
      for (const item of this.filtered) {
        Object.assign(item, this.updatePayload);
      }
    }
    let result;
    if (this.isSingle) {
      if (this.filtered.length === 0) {
        result = { data: null, error: new Error('Row not found') };
      } else {
        result = { data: this._mapRelations(this.filtered[0]), error: null };
      }
    } else if (this.isMaybeSingle) {
      result = { data: this.filtered.length > 0 ? this._mapRelations(this.filtered[0]) : null, error: null };
    } else {
      const processed = this.filtered.map(item => this._mapRelations(item));
      result = { data: processed, count: processed.length, error: null };
    }
    return Promise.resolve(result).then(onFulfilled, onRejected);
  }
}

// Mock @supabase/supabase-js library
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => ({
    auth: {
      getUser: jest.fn(async (token) => {
        const cleanedToken = token.replace('Bearer ', '');
        const user = mockFakeProfiles.find(u => u.id === cleanedToken || u.email.startsWith(cleanedToken.replace('-token', '')));
        if (user) {
          return { data: { user: { id: user.id, email: user.email } }, error: null };
        }
        return { data: { user: null }, error: new Error('Token tidak valid') };
      }),
      admin: {
        createUser: jest.fn(async ({ email, password, user_metadata }) => {
          const id = NEW_USER_UUID;
          const newUser = { id, email, user_metadata };
          mockFakeUsers.push(newUser);
          return { data: { user: newUser }, error: null };
        }),
        deleteUser: jest.fn(async (id) => {
          mockFakeUsers = mockFakeUsers.filter(u => u.id !== id);
          return { data: {}, error: null };
        })
      }
    },
    from: jest.fn((tableName) => {
      let sourceArray;
      if (tableName === 'tenant') sourceArray = mockFakeTenants;
      else if (tableName === 'profiles') sourceArray = mockFakeProfiles;
      else if (tableName === 'absensi') sourceArray = mockFakeAbsensi;
      else if (tableName === 'izin') sourceArray = mockFakeIzin;
      else if (tableName === 'shift') sourceArray = mockFakeShift;
      else if (tableName === 'jadwal_karyawan') sourceArray = mockFakeJadwalKaryawan;
      else if (tableName === 'notifikasi') sourceArray = mockFakeNotifikasi;
      else sourceArray = [];
      return new MockQueryBuilder(tableName, sourceArray);
    })
  }))
}));

// Mock Schedule & Overtime Helpers to control E2E outcomes
jest.mock('../../utils/scheduleHelper', () => ({
  getJadwalAktif: jest.fn(async () => ({
    id: 'shift-123',
    nama_shift: 'Shift Pagi',
    jam_masuk: '08:00:00',
    jam_keluar: '17:00:00',
    is_aktif: true,
    is_libur: false,
    is_wfh: false,
    is_fleksibel: false,
    toleransi_menit: 15,
  }))
}));

jest.mock('../../utils/overtimeHelper', () => ({
  detectOvertime: jest.fn(async () => null)
}));

describe('SiAbsen Backend - End to End Flow Integration Test', () => {
  beforeEach(() => {
    resetMockDb();
    jest.clearAllMocks();
  });

  test('E2E Flow: Register → Admin Approval → User Login → Check-In → Ajukan Izin → Review Izin → Get Laporan', async () => {
    const tenantId = 'tenant-123';

    // ─────────────────────────────────────────────────────────────────────────────
    // 1. REGISTER KARYAWAN BARU
    // ─────────────────────────────────────────────────────────────────────────────
    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .set('x-tenant-id', tenantId)
      .send({
        nama: 'Karyawan Baru',
        email: 'karyawan.baru@interia.com',
        password: 'Password123!',
        nomorHp: '08123456789',
        alamat: 'Jl. Merdeka No. 10'
      });

    expect(registerResponse.status).toBe(201);
    expect(registerResponse.body.success).toBe(true);
    expect(registerResponse.body.message).toContain('Registrasi berhasil');

    // Pastikan user baru terdaftar di profiles dengan status_aktif = false
    const newKaryawanProfile = mockFakeProfiles.find(p => p.email === 'karyawan.baru@interia.com');
    expect(newKaryawanProfile).toBeDefined();
    expect(newKaryawanProfile.status_aktif).toBe(false);
    expect(newKaryawanProfile.role).toBe('karyawan');
    expect(newKaryawanProfile.id).toBe(NEW_USER_UUID);

    // ─────────────────────────────────────────────────────────────────────────────
    // 2. ADMIN LIST USERS & APPROVE KARYAWAN BARU
    // ─────────────────────────────────────────────────────────────────────────────
    // Admin list users to find pending profiles
    const listResponse = await request(app)
      .get('/api/v1/users')
      .set('x-tenant-id', tenantId)
      .set('Authorization', `Bearer ${ADMIN_UUID}`); // Bearer admin token

    expect(listResponse.status).toBe(200);
    expect(listResponse.body.data.data).toHaveLength(4); // 3 original + 1 new

    // Admin approve karyawan baru
    const approveResponse = await request(app)
      .put(`/api/v1/users/${newKaryawanProfile.id}`)
      .set('x-tenant-id', tenantId)
      .set('Authorization', `Bearer ${ADMIN_UUID}`)
      .send({
        nama: 'Karyawan Baru',
        email: 'karyawan.baru@interia.com',
        role: 'karyawan',
        status_aktif: true
      });

    expect(approveResponse.status).toBe(200);
    expect(approveResponse.body.success).toBe(true);
    expect(approveResponse.body.data.status_aktif).toBe(true);
    expect(newKaryawanProfile.status_aktif).toBe(true); // verify in DB

    // Set department to the new employee to support supervisor approval hierarchy
    newKaryawanProfile.id_departemen = 'dept-123';

    // ─────────────────────────────────────────────────────────────────────────────
    // 3. KARYAWAN BARU MELAKUKAN CHECK-IN (Geofencing WFO)
    // ─────────────────────────────────────────────────────────────────────────────
    // Check-in dengan koordinat valid (-6.9826, 110.4092)
    const checkinResponse = await request(app)
      .post('/api/v1/absensi/checkin')
      .set('x-tenant-id', tenantId)
      .set('Authorization', `Bearer ${NEW_USER_UUID}`)
      .send({
        latitude: -6.9826,
        longitude: 110.4092
      });

    expect(checkinResponse.status).toBe(200);
    expect(checkinResponse.body.success).toBe(true);
    expect(checkinResponse.body.message).toContain('Check-in Berhasil');

    // Verifikasi data absensi tersimpan
    expect(mockFakeAbsensi).toHaveLength(1);
    expect(mockFakeAbsensi[0].id_karyawan).toBe(NEW_USER_UUID);
    expect(mockFakeAbsensi[0].status).toBe('hadir');

    // ─────────────────────────────────────────────────────────────────────────────
    // 4. KARYAWAN BARU MENGAJUKAN IZIN UNTUK MASA DEPAN
    // ─────────────────────────────────────────────────────────────────────────────
    const futureDate = DateTime.now().plus({ days: 3 }).toISODate();
    const applyIzinResponse = await request(app)
      .post('/api/v1/izin/ajukan')
      .set('x-tenant-id', tenantId)
      .set('Authorization', `Bearer ${NEW_USER_UUID}`)
      .send({
        tanggal_mulai: futureDate,
        tanggal_selesai: futureDate,
        jenis_izin: 'sakit',
        alasan: 'Sakit flu demam'
      });

    expect(applyIzinResponse.status).toBe(201);
    expect(applyIzinResponse.body.success).toBe(true);
    expect(applyIzinResponse.body.data.status).toBe('pending');
    expect(applyIzinResponse.body.data.current_approver_role).toBe('manajer');

    const newIzin = mockFakeIzin[0];
    expect(newIzin).toBeDefined();
    expect(newIzin.id_karyawan).toBe(NEW_USER_UUID);

    // ─────────────────────────────────────────────────────────────────────────────
    // 5. MANAJER ME-REVIEW & MENYETUJUI IZIN (Level 1)
    // ─────────────────────────────────────────────────────────────────────────────
    const managerReviewResponse = await request(app)
      .put(`/api/v1/izin/${newIzin.id}/review`)
      .set('x-tenant-id', tenantId)
      .set('Authorization', `Bearer ${MANAGER_UUID}`)
      .send({
        action: 'approve',
        catatan: 'Disetujui dari sisi manajer'
      });

    expect(managerReviewResponse.status).toBe(200);
    expect(managerReviewResponse.body.data.status).toBe('pending');
    expect(managerReviewResponse.body.data.current_approver_role).toBe('hrd');

    // ─────────────────────────────────────────────────────────────────────────────
    // 6. HRD ME-REVIEW & MENYETUJUI IZIN (Level 2 - Final)
    // ─────────────────────────────────────────────────────────────────────────────
    const hrdReviewResponse = await request(app)
      .put(`/api/v1/izin/${newIzin.id}/review`)
      .set('x-tenant-id', tenantId)
      .set('Authorization', `Bearer ${HRD_UUID}`)
      .send({
        action: 'approve',
        catatan: 'Disetujui final'
      });

    expect(hrdReviewResponse.status).toBe(200);
    expect(hrdReviewResponse.body.data.status).toBe('disetujui');
    expect(hrdReviewResponse.body.data.current_approver_role).toBeNull();

    // ─────────────────────────────────────────────────────────────────────────────
    // 7. GET LAPORAN BULANAN
    // ─────────────────────────────────────────────────────────────────────────────
    const reportResponse = await request(app)
      .get('/api/v1/laporan/bulanan')
      .set('x-tenant-id', tenantId)
      .set('Authorization', `Bearer ${HRD_UUID}`);

    expect(reportResponse.status).toBe(200);
    expect(reportResponse.body.success).toBe(true);
    expect(reportResponse.body.data.details).toBeDefined();
  });
});
