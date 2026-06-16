-- ============================================================
-- SUPABASE SCHEMA — Sistem Absensi Karyawan
-- Jalankan di: Supabase Dashboard → SQL Editor
-- Urutan: jalankan dari atas ke bawah
-- ============================================================


-- ============================================================
-- 1. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ============================================================
-- 2. ENUMS
-- ============================================================
DO $$ BEGIN
  CREATE TYPE user_role        AS ENUM ('karyawan', 'manajer', 'hrd', 'admin');
  CREATE TYPE attendance_status AS ENUM ('hadir', 'terlambat', 'izin', 'alpha');
  CREATE TYPE leave_type       AS ENUM ('sakit', 'pribadi', 'cuti');
  CREATE TYPE leave_status     AS ENUM ('pending', 'disetujui', 'ditolak');
  CREATE TYPE overtime_type    AS ENUM ('terencana', 'spontan');
  CREATE TYPE overtime_status  AS ENUM ('pending', 'disetujui', 'ditolak', 'selesai');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ============================================================
-- 3. DEPARTEMEN
-- ============================================================
CREATE TABLE IF NOT EXISTS departemen (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_departemen  VARCHAR(100) NOT NULL,
    id_manajer       UUID,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- 4. PROFILES
-- Tabel ini melengkapi auth.users Supabase.
-- id = UUID yang sama dengan auth.users.id
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
    id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nama           VARCHAR(100)  NOT NULL,
    email          VARCHAR(100)  UNIQUE NOT NULL,
    role           user_role     NOT NULL DEFAULT 'karyawan',
    id_departemen  UUID          REFERENCES departemen(id) ON DELETE SET NULL,
    status_aktif   BOOLEAN       DEFAULT FALSE,  -- false = menunggu approval admin
    nomor_hp       VARCHAR(20),
    alamat         TEXT,
    foto_profil    VARCHAR(500),
    created_at     TIMESTAMPTZ   DEFAULT NOW(),
    updated_at     TIMESTAMPTZ   DEFAULT NOW()
);

-- FK manajer departemen (setelah profiles ada)
ALTER TABLE departemen
    ADD CONSTRAINT fk_departemen_manajer
    FOREIGN KEY (id_manajer) REFERENCES profiles(id) ON DELETE SET NULL;


-- ============================================================
-- 5. SHIFT
-- ============================================================
CREATE TABLE IF NOT EXISTS shift (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_shift       VARCHAR(100) NOT NULL,
    jam_masuk        TIME         NOT NULL,
    jam_keluar       TIME         NOT NULL,
    toleransi_menit  INTEGER      DEFAULT 15,
    is_wfh           BOOLEAN      DEFAULT FALSE,
    is_fleksibel     BOOLEAN      DEFAULT FALSE,
    is_aktif         BOOLEAN      DEFAULT TRUE,
    is_default_global BOOLEAN     DEFAULT FALSE,
    warna_hex        VARCHAR(7)   DEFAULT '#3498DB',
    created_by       UUID         REFERENCES profiles(id),
    created_at       TIMESTAMPTZ  DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  DEFAULT NOW()
);

ALTER TABLE departemen
    ADD COLUMN IF NOT EXISTS default_shift_id UUID REFERENCES shift(id) ON DELETE SET NULL;


-- ============================================================
-- 6. JADWAL KARYAWAN
-- ============================================================
CREATE TABLE IF NOT EXISTS jadwal_karyawan (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_karyawan  UUID         NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    id_shift     UUID         NOT NULL REFERENCES shift(id)    ON DELETE CASCADE,
    tanggal      DATE         NOT NULL,
    is_libur     BOOLEAN      DEFAULT FALSE,
    catatan      VARCHAR(200),
    created_by   UUID         REFERENCES profiles(id),
    created_at   TIMESTAMPTZ  DEFAULT NOW(),
    UNIQUE (id_karyawan, tanggal)
);


-- ============================================================
-- 7. OVERTIME
-- ============================================================
CREATE TABLE IF NOT EXISTS overtime (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_karyawan       UUID           NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    id_absensi        UUID,
    tanggal           DATE           NOT NULL,
    jam_mulai_lembur  TIME,
    jam_selesai_lembur TIME,
    durasi_menit      INTEGER        DEFAULT 0,
    jenis             overtime_type  NOT NULL,
    status            overtime_status DEFAULT 'pending',
    alasan            TEXT,
    id_approver       UUID           REFERENCES profiles(id) ON DELETE SET NULL,
    catatan_approver  TEXT,
    multiplier_tarif  DECIMAL(3,1)   DEFAULT 1.5,
    created_at        TIMESTAMPTZ    DEFAULT NOW(),
    updated_at        TIMESTAMPTZ    DEFAULT NOW()
);


-- ============================================================
-- 8. ABSENSI
-- ============================================================
CREATE TABLE IF NOT EXISTS absensi (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_karyawan      UUID              NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    id_shift         UUID              REFERENCES shift(id) ON DELETE SET NULL,
    tanggal          DATE              NOT NULL,
    jam_masuk        TIME,
    jam_keluar       TIME,
    status           attendance_status NOT NULL DEFAULT 'hadir',
    menit_terlambat  INTEGER           DEFAULT 0,
    keterangan       TEXT,
    is_overtime      BOOLEAN           DEFAULT FALSE,
    id_overtime      UUID              REFERENCES overtime(id) ON DELETE SET NULL,
    created_at       TIMESTAMPTZ       DEFAULT NOW(),
    updated_at       TIMESTAMPTZ       DEFAULT NOW(),
    CONSTRAINT unique_karyawan_tanggal UNIQUE (id_karyawan, tanggal)
);

-- FK overtime ↔ absensi
ALTER TABLE overtime
    ADD CONSTRAINT fk_overtime_absensi
    FOREIGN KEY (id_absensi) REFERENCES absensi(id) ON DELETE SET NULL;


-- ============================================================
-- 9. QR SESSIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS qr_sessions (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_unik        VARCHAR(32)  UNIQUE NOT NULL,
    payload_encrypted TEXT         NOT NULL,
    lokasi_lat        DECIMAL      NOT NULL,
    lokasi_lng        DECIMAL      NOT NULL,
    berlaku_hingga    TIMESTAMPTZ  NOT NULL,
    sudah_dipakai     BOOLEAN      DEFAULT FALSE,
    created_at        TIMESTAMPTZ  DEFAULT NOW()
);


-- ============================================================
-- 10. IZIN
-- ============================================================
CREATE TABLE IF NOT EXISTS izin (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_karyawan           UUID         NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    tanggal_mulai         DATE         NOT NULL,
    tanggal_selesai       DATE         NOT NULL,
    jenis_izin            leave_type   NOT NULL,
    alasan                TEXT,
    status                leave_status NOT NULL DEFAULT 'pending',
    id_approver           UUID         REFERENCES profiles(id) ON DELETE SET NULL,
    catatan_approver      TEXT,
    current_approver_role VARCHAR(20),
    created_at            TIMESTAMPTZ  DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS izin_approval_logs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_izin       UUID         NOT NULL REFERENCES izin(id) ON DELETE CASCADE,
    id_approver   UUID         REFERENCES profiles(id) ON DELETE SET NULL,
    role_approver VARCHAR(20),
    action        VARCHAR(20)  NOT NULL,
    note          TEXT,
    created_at    TIMESTAMPTZ  DEFAULT NOW()
);


-- ============================================================
-- 11. NOTIFIKASI
-- ============================================================
CREATE TABLE IF NOT EXISTS notifikasi (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_penerima  UUID         NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    judul        VARCHAR(200) NOT NULL,
    pesan        TEXT         NOT NULL,
    jenis        VARCHAR(50),
    status_baca  BOOLEAN      DEFAULT FALSE,
    created_at   TIMESTAMPTZ  DEFAULT NOW()
);


-- ============================================================
-- 12. LOG AKTIVITAS
-- ============================================================
CREATE TABLE IF NOT EXISTS log_aktivitas (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_user    UUID         REFERENCES profiles(id) ON DELETE SET NULL,
    aksi       VARCHAR(100) NOT NULL,
    detail     TEXT,
    ip_address VARCHAR(50),
    created_at TIMESTAMPTZ  DEFAULT NOW()
);


-- ============================================================
-- 13. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_profiles_email          ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_absensi_tanggal         ON absensi(tanggal);
CREATE INDEX IF NOT EXISTS idx_absensi_karyawan_tgl    ON absensi(id_karyawan, tanggal DESC);
CREATE INDEX IF NOT EXISTS idx_jadwal_karyawan_tanggal ON jadwal_karyawan(tanggal);
CREATE INDEX IF NOT EXISTS idx_jadwal_karyawan_id_tgl  ON jadwal_karyawan(id_karyawan, tanggal);
CREATE INDEX IF NOT EXISTS idx_izin_status             ON izin(status);
CREATE INDEX IF NOT EXISTS idx_izin_karyawan           ON izin(id_karyawan);
CREATE INDEX IF NOT EXISTS idx_overtime_status         ON overtime(status);
CREATE INDEX IF NOT EXISTS idx_notifikasi_penerima     ON notifikasi(id_penerima, status_baca);


-- ============================================================
-- 14. ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Aktifkan RLS di semua tabel
ALTER TABLE profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE absensi          ENABLE ROW LEVEL SECURITY;
ALTER TABLE izin              ENABLE ROW LEVEL SECURITY;
ALTER TABLE izin_approval_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifikasi       ENABLE ROW LEVEL SECURITY;
ALTER TABLE jadwal_karyawan  ENABLE ROW LEVEL SECURITY;
ALTER TABLE overtime         ENABLE ROW LEVEL SECURITY;
ALTER TABLE shift             ENABLE ROW LEVEL SECURITY;
ALTER TABLE departemen        ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_sessions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE log_aktivitas     ENABLE ROW LEVEL SECURITY;


-- ── Helper function: ambil role user yang sedang login ──────────────────────
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT AS $$
  SELECT role::TEXT FROM profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ── Helper function: cek apakah user aktif ──────────────────────────────────
CREATE OR REPLACE FUNCTION is_active_user()
RETURNS BOOLEAN AS $$
  SELECT status_aktif FROM profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;


-- ── PROFILES policies ────────────────────────────────────────────────────────
-- User bisa baca profil sendiri
CREATE POLICY "profiles: read own"
  ON profiles FOR SELECT
  USING (id = auth.uid());

-- Admin & HRD bisa baca semua profil
CREATE POLICY "profiles: admin hrd read all"
  ON profiles FOR SELECT
  USING (get_my_role() IN ('admin', 'hrd'));

-- Manajer bisa baca profil di departemennya
CREATE POLICY "profiles: manajer read dept"
  ON profiles FOR SELECT
  USING (
    get_my_role() = 'manajer'
    AND id_departemen = (
      SELECT id_departemen FROM profiles WHERE id = auth.uid()
    )
  );

-- User bisa update profil sendiri (nama, nomor_hp, alamat saja)
CREATE POLICY "profiles: update own"
  ON profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Admin bisa update semua profil (untuk approval/role change)
CREATE POLICY "profiles: admin update all"
  ON profiles FOR UPDATE
  USING (get_my_role() = 'admin');

-- Insert profil baru hanya saat register (auth.uid() = id baru)
CREATE POLICY "profiles: insert own on register"
  ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());


-- ── ABSENSI policies ─────────────────────────────────────────────────────────
-- Karyawan bisa baca absensi sendiri
CREATE POLICY "absensi: read own"
  ON absensi FOR SELECT
  USING (id_karyawan = auth.uid());

-- Admin & HRD bisa baca semua absensi
CREATE POLICY "absensi: admin hrd read all"
  ON absensi FOR SELECT
  USING (get_my_role() IN ('admin', 'hrd'));

-- Manajer bisa baca absensi departemennya
CREATE POLICY "absensi: manajer read dept"
  ON absensi FOR SELECT
  USING (
    get_my_role() = 'manajer'
    AND id_karyawan IN (
      SELECT id FROM profiles
      WHERE id_departemen = (
        SELECT id_departemen FROM profiles WHERE id = auth.uid()
      )
    )
  );

-- Insert absensi — hanya backend Express via service_role key yang boleh
-- (Check-in/out dilakukan melalui backend, bukan langsung dari client)
CREATE POLICY "absensi: backend insert"
  ON absensi FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "absensi: backend update"
  ON absensi FOR UPDATE
  USING (auth.role() = 'service_role');


-- ── IZIN policies ────────────────────────────────────────────────────────────
-- Karyawan bisa baca izin sendiri
CREATE POLICY "izin: read own"
  ON izin FOR SELECT
  USING (id_karyawan = auth.uid());

-- Manajer/HRD bisa baca izin yang ditujukan ke mereka
CREATE POLICY "izin: approver read pending"
  ON izin FOR SELECT
  USING (
    current_approver_role = get_my_role()
    OR get_my_role() IN ('admin', 'hrd')
  );

-- Karyawan bisa insert izin sendiri
CREATE POLICY "izin: insert own"
  ON izin FOR INSERT
  WITH CHECK (id_karyawan = auth.uid() AND is_active_user());

-- Approver bisa update izin yang ditujukan ke mereka
CREATE POLICY "izin: approver update"
  ON izin FOR UPDATE
  USING (
    current_approver_role = get_my_role()
    OR get_my_role() = 'admin'
  );


-- ── IZIN APPROVAL LOGS policies ──────────────────────────────────────────────
CREATE POLICY "izin_logs: read own izin"
  ON izin_approval_logs FOR SELECT
  USING (
    id_izin IN (SELECT id FROM izin WHERE id_karyawan = auth.uid())
    OR get_my_role() IN ('admin', 'hrd', 'manajer')
  );

CREATE POLICY "izin_logs: insert by approver"
  ON izin_approval_logs FOR INSERT
  WITH CHECK (id_approver = auth.uid());


-- ── NOTIFIKASI policies ──────────────────────────────────────────────────────
CREATE POLICY "notifikasi: read own"
  ON notifikasi FOR SELECT
  USING (id_penerima = auth.uid());

CREATE POLICY "notifikasi: update own"
  ON notifikasi FOR UPDATE
  USING (id_penerima = auth.uid());

-- Insert notifikasi hanya dari backend (service_role)
CREATE POLICY "notifikasi: backend insert"
  ON notifikasi FOR INSERT
  WITH CHECK (auth.role() = 'service_role');


-- ── JADWAL KARYAWAN policies ─────────────────────────────────────────────────
CREATE POLICY "jadwal: read own"
  ON jadwal_karyawan FOR SELECT
  USING (id_karyawan = auth.uid());

CREATE POLICY "jadwal: admin hrd read all"
  ON jadwal_karyawan FOR SELECT
  USING (get_my_role() IN ('admin', 'hrd'));

CREATE POLICY "jadwal: admin hrd manage"
  ON jadwal_karyawan FOR ALL
  USING (get_my_role() IN ('admin', 'hrd'));


-- ── SHIFT policies ───────────────────────────────────────────────────────────
-- Semua user aktif bisa baca shift (untuk info jadwal)
CREATE POLICY "shift: all active read"
  ON shift FOR SELECT
  USING (is_active_user() = true);

CREATE POLICY "shift: admin hrd manage"
  ON shift FOR ALL
  USING (get_my_role() IN ('admin', 'hrd'));


-- ── DEPARTEMEN policies ──────────────────────────────────────────────────────
CREATE POLICY "departemen: all active read"
  ON departemen FOR SELECT
  USING (is_active_user() = true);

CREATE POLICY "departemen: admin manage"
  ON departemen FOR ALL
  USING (get_my_role() = 'admin');


-- ── QR SESSIONS policies ─────────────────────────────────────────────────────
-- Generate QR hanya dari backend (service_role)
CREATE POLICY "qr: backend manage"
  ON qr_sessions FOR ALL
  USING (auth.role() = 'service_role');

-- HRD/Admin bisa lihat status QR
CREATE POLICY "qr: hrd admin read"
  ON qr_sessions FOR SELECT
  USING (get_my_role() IN ('admin', 'hrd'));


-- ── OVERTIME policies ────────────────────────────────────────────────────────
CREATE POLICY "overtime: read own"
  ON overtime FOR SELECT
  USING (id_karyawan = auth.uid());

CREATE POLICY "overtime: admin hrd read all"
  ON overtime FOR SELECT
  USING (get_my_role() IN ('admin', 'hrd'));

CREATE POLICY "overtime: backend manage"
  ON overtime FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "overtime: backend update"
  ON overtime FOR UPDATE
  USING (auth.role() = 'service_role');


-- ── LOG AKTIVITAS policies ───────────────────────────────────────────────────
CREATE POLICY "log: admin read"
  ON log_aktivitas FOR SELECT
  USING (get_my_role() = 'admin');

CREATE POLICY "log: backend insert"
  ON log_aktivitas FOR INSERT
  WITH CHECK (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);


-- ============================================================
-- 15. REALTIME — aktifkan untuk tabel yang perlu update live
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE absensi;
ALTER PUBLICATION supabase_realtime ADD TABLE notifikasi;
ALTER PUBLICATION supabase_realtime ADD TABLE izin;


-- ============================================================
-- 16. TRIGGER — auto update `updated_at`
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_absensi_updated_at
  BEFORE UPDATE ON absensi
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_izin_updated_at
  BEFORE UPDATE ON izin
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_overtime_updated_at
  BEFORE UPDATE ON overtime
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ============================================================
-- 17. SEED — shift default global
-- ============================================================
INSERT INTO shift (nama_shift, jam_masuk, jam_keluar, toleransi_menit, is_default_global, warna_hex)
VALUES ('Shift Reguler', '08:00', '17:00', 15, TRUE, '#2563EB')
ON CONFLICT DO NOTHING;


-- ============================================================
-- SELESAI
-- Langkah selanjutnya:
-- 1. Buka Supabase Dashboard → Authentication → Providers
--    Pastikan Email provider aktif
-- 2. Buka Authentication → URL Configuration
--    Set Site URL ke URL app Anda
-- 3. Jalankan backend Express dengan SUPABASE_SERVICE_KEY
--    (Settings → API → service_role key) di .env
-- ============================================================
