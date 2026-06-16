-- ============================================================
-- SUPABASE SAAS MIGRATION — Multi-Tenancy & Subscriptions
-- Jalankan di: Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. SUBSCRIPTION PLANS
CREATE TABLE IF NOT EXISTS subscription_plans (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name           VARCHAR(50) UNIQUE NOT NULL,
    max_employees  INTEGER NOT NULL,
    features       TEXT[] NOT NULL,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Seed Plans
INSERT INTO subscription_plans (name, max_employees, features) VALUES
('Free', 5, ARRAY['absensi', 'izin']),
('Pro', 50, ARRAY['absensi', 'izin', 'lembur', 'laporan_excel', 'laporan_pdf']),
('Enterprise', 9999, ARRAY['absensi', 'izin', 'lembur', 'laporan_excel', 'laporan_pdf', 'custom_geofence', 'api_access'])
ON CONFLICT (name) DO UPDATE SET
    max_employees = EXCLUDED.max_employees,
    features = EXCLUDED.features;

-- 2. TENANT
CREATE TABLE IF NOT EXISTS tenant (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                 VARCHAR(100) NOT NULL,
    subdomain            VARCHAR(50) UNIQUE NOT NULL,
    id_plan              UUID REFERENCES subscription_plans(id) ON DELETE SET NULL,
    subscription_status  VARCHAR(20) DEFAULT 'active',
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TENANT SETTINGS
CREATE TABLE IF NOT EXISTS tenant_settings (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_tenant             UUID UNIQUE REFERENCES tenant(id) ON DELETE CASCADE,
    office_lat            DECIMAL(10, 8) DEFAULT -6.9826,
    office_lng            DECIMAL(11, 8) DEFAULT 110.4092,
    geofence_radius_meter INTEGER DEFAULT 100,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- 4. SEED DEFAULT TENANT (Untuk backward compatibility)
DO $$
DECLARE
    default_plan_id UUID;
    default_tenant_id UUID;
BEGIN
    SELECT id INTO default_plan_id FROM subscription_plans WHERE name = 'Free' LIMIT 1;
    
    INSERT INTO tenant (name, subdomain, id_plan)
    VALUES ('Interia Corp', 'interia', default_plan_id)
    ON CONFLICT (subdomain) DO NOTHING;

    SELECT id INTO default_tenant_id FROM tenant WHERE subdomain = 'interia' LIMIT 1;

    INSERT INTO tenant_settings (id_tenant, office_lat, office_lng, geofence_radius_meter)
    VALUES (default_tenant_id, -6.9826, 110.4092, 100)
    ON CONFLICT (id_tenant) DO NOTHING;
END $$;

-- 5. TAMBAH KOLOM id_tenant KE 11 TABEL BISNIS
-- Kita tetapkan default value ke default tenant 'interia' agar data lama otomatis ter-link.

DO $$
DECLARE
    def_tenant_id UUID;
BEGIN
    SELECT id INTO def_tenant_id FROM tenant WHERE subdomain = 'interia' LIMIT 1;

    -- A. departemen
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='departemen' AND column_name='id_tenant') THEN
        ALTER TABLE departemen ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;

    -- B. profiles
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='id_tenant') THEN
        ALTER TABLE profiles ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;

    -- C. shift
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='shift' AND column_name='id_tenant') THEN
        ALTER TABLE shift ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;

    -- D. jadwal_karyawan
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='jadwal_karyawan' AND column_name='id_tenant') THEN
        ALTER TABLE jadwal_karyawan ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;

    -- E. overtime
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='overtime' AND column_name='id_tenant') THEN
        ALTER TABLE overtime ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;

    -- F. absensi
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='absensi' AND column_name='id_tenant') THEN
        ALTER TABLE absensi ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;

    -- G. izin
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='izin' AND column_name='id_tenant') THEN
        ALTER TABLE izin ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;

    -- H. notifikasi
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifikasi' AND column_name='id_tenant') THEN
        ALTER TABLE notifikasi ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;

    -- I. log_aktivitas
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='log_aktivitas' AND column_name='id_tenant') THEN
        ALTER TABLE log_aktivitas ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;

    -- J. qr_sessions
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='qr_sessions' AND column_name='id_tenant') THEN
        ALTER TABLE qr_sessions ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;

    -- K. izin_approval_logs
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='izin_approval_logs' AND column_name='id_tenant') THEN
        ALTER TABLE izin_approval_logs ADD COLUMN id_tenant UUID REFERENCES tenant(id) ON DELETE CASCADE DEFAULT def_tenant_id;
    END IF;
END $$;
