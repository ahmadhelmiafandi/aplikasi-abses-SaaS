# SiAbsen — Sistem Absensi Karyawan

> Flutter Web + Node.js/Express + Supabase PostgreSQL

---

## Stack

| Komponen | Teknologi |
|---|---|
| Frontend | Flutter Web (Dart) |
| Backend | Node.js v20 + Express v5 |
| Database | Supabase PostgreSQL (cloud) |
| Auth | Supabase Auth |
| Realtime | Supabase Realtime |
| State Management | Riverpod |
| Routing | GoRouter |
| HTTP Client | Dio (hanya untuk backend Express) |

---

## Fitur

- **Absensi GPS** — check-in/out dengan geofencing Haversine
- **QR Scan** — kamera scan QR untuk check-in tanpa GPS
- **Riwayat Absensi** — history per bulan dengan summary
- **Overtime Detection** — otomatis saat checkout (min 60 menit, multiplier 1.5x/2.0x)
- **Izin & Cuti** — pengajuan + approval multi-level (Manajer → HRD)
- **Laporan Bulanan** — KPI cards + export PDF & Excel
- **Notifikasi** — in-app dengan badge counter
- **Role-based UI** — karyawan / manajer / hrd / admin
- **Dark Mode** + **Bilingual ID/EN**

---

## Setup

### Prasyarat

- Node.js v20+
- Flutter 3.x
- Akun Supabase (free tier cukup)

### 1. Clone & Install

```bash
# Backend
cd backend
npm install

# Frontend
cd frontend
flutter pub get
```

### 2. Konfigurasi Backend

Buat file `backend/.env` dari template:

```bash
cp backend/.env.example backend/.env
```

Isi nilai berikut di `.env`:

```env
PORT=3000
NODE_ENV=development

SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_KEY=your_service_role_key   # Settings → API → service_role

QR_SECRET_KEY=ganti_dengan_string_acak_32_karakter_minimal

ALLOWED_ORIGINS=http://localhost:3000,http://localhost:4000

OFFICE_LAT=-6.9826
OFFICE_LNG=110.4092
GEOFENCE_RADIUS_METER=100
```

> `SUPABASE_SERVICE_KEY` ada di: Supabase Dashboard → Settings → API → service_role

### 3. Setup Database

1. Buka **Supabase Dashboard → SQL Editor**
2. Jalankan seluruh isi file `SUPABASE_SCHEMA.sql`
3. Buka **Authentication → Email** → nonaktifkan email confirmation
4. Buka **Authentication → URL Configuration** → set Site URL ke `http://localhost:4000`

### 4. Buat Akun Admin Pertama

Jalankan query berikut di Supabase SQL Editor setelah schema terpasang:

```sql
-- 1. Buat user via Supabase Auth dashboard (Authentication → Users → Add user)
--    Email: admin@interia.com | Password: Admin123!

-- 2. Insert profile (ganti UUID dengan ID dari auth.users)
INSERT INTO profiles (id, nama, email, role, status_aktif)
VALUES (
  'UUID-dari-auth-users',
  'Admin SiAbsen',
  'admin@interia.com',
  'admin',
  true
);
```

### 5. Jalankan

```bash
# Terminal 1 — Backend
cd backend
npm run dev
# → http://localhost:3000

# Terminal 2 — Frontend
cd frontend
flutter run -d chrome --web-port 4000
# → http://localhost:4000
```

---

## Akses Development

| | URL |
|---|---|
| Frontend | http://localhost:4000 |
| Backend | http://localhost:3000 |
| Health Check | http://localhost:3000/health |
| Supabase Dashboard | https://supabase.com/dashboard/project/ppdutshsvguxgtyclaxj |

**Akun admin default:**
```
Email    : admin@interia.com
Password : Admin123!
```

---

## Struktur Proyek

```
uts apbo/
├── backend/
│   ├── src/
│   │   ├── app.js                  # Express app, middleware, routes
│   │   ├── server.js               # Entry point, listen port
│   │   ├── config/
│   │   │   ├── supabase.js         # Supabase client (service role)
│   │   │   └── logger.js           # Winston structured logging
│   │   ├── controllers/
│   │   │   ├── absensiController.js
│   │   │   ├── izinController.js
│   │   │   ├── laporanController.js  # Export Excel + PDF
│   │   │   ├── profileController.js
│   │   │   ├── qrController.js
│   │   │   └── userController.js
│   │   ├── middleware/
│   │   │   ├── auth.js             # Supabase JWT verify + RBAC
│   │   │   ├── validate.js         # Zod schemas + validateUUID
│   │   │   └── supabase-service.js
│   │   ├── routes/                 # Express routers
│   │   └── utils/
│   │       ├── crypto.js           # AES encrypt/decrypt QR
│   │       ├── overtimeHelper.js   # Overtime detection logic
│   │       ├── scheduleHelper.js   # Shift fallback logic
│   │       └── response.js         # successResponse / errorResponse
│   ├── .env.example
│   └── package.json
│
├── frontend/
│   └── lib/
│       ├── main.dart               # GoRouter + Supabase init
│       ├── core/
│       │   ├── config/app_config.dart
│       │   ├── l10n/translations.dart   # ID/EN strings
│       │   ├── network/dio_client.dart  # Dio + auto token refresh
│       │   ├── providers/theme_provider.dart
│       │   ├── supabase/
│       │   │   ├── supabase_config.dart
│       │   │   └── supabase_service.dart  # CRUD langsung ke Supabase
│       │   ├── theme/
│       │   │   ├── app_colors.dart
│       │   │   └── app_theme.dart
│       │   └── widgets/app_widgets.dart   # Komponen reusable
│       └── features/
│           ├── absensi/      # Check-in/out, QR scan, riwayat
│           ├── admin/        # Approval akun, kelola karyawan
│           ├── auth/         # Login, register, auth provider
│           ├── izin/         # Daftar izin, form izin, approval
│           ├── laporan/      # Dashboard laporan + export
│           ├── notifikasi/   # Notifikasi screen
│           └── profile/      # Profil + ganti password
│
├── SUPABASE_SCHEMA.sql       # Schema lengkap — jalankan di SQL Editor
├── MASTER_CHECKLIST.md       # Progress tracking
└── ACTIVITY_DIAGRAM.md       # 12 diagram alur sistem (Mermaid)
```

---

## API Endpoints

### Auth
| Method | Path | Keterangan |
|---|---|---|
| GET | `/health` | Health check backend + Supabase |

### Absensi
| Method | Path | Role | Keterangan |
|---|---|---|---|
| POST | `/api/absensi/checkin` | semua | Check-in GPS (geofencing) |
| POST | `/api/absensi/checkout` | semua | Check-out + deteksi overtime |
| POST | `/api/absensi/scan-qr` | semua | Check-in via QR scan |
| GET | `/api/absensi/riwayat` | semua | Riwayat per bulan (paginated) |
| GET | `/api/absensi/hari-ini` | semua | Status absensi hari ini |

### Izin
| Method | Path | Role | Keterangan |
|---|---|---|---|
| POST | `/api/izin/ajukan` | semua | Ajukan izin baru |
| GET | `/api/izin/saya` | semua | Daftar izin milik sendiri |
| GET | `/api/izin/pending` | manajer, hrd | Izin pending untuk diapprove |
| PUT | `/api/izin/:id/review` | manajer, hrd | Approve / reject izin |

### Laporan
| Method | Path | Role | Keterangan |
|---|---|---|---|
| GET | `/api/laporan/bulanan` | admin, hrd, manajer | Laporan bulanan aggregate |
| GET | `/api/laporan/export/excel` | admin, hrd, manajer | Download file Excel |
| GET | `/api/laporan/export/pdf` | admin, hrd, manajer | Download file PDF |

### QR
| Method | Path | Role | Keterangan |
|---|---|---|---|
| POST | `/api/qr/generate` | admin, hrd | Generate QR (30 detik) |
| GET | `/api/qr/status` | admin, hrd | Status QR aktif |

### Users
| Method | Path | Role | Keterangan |
|---|---|---|---|
| GET | `/api/users` | admin, hrd | Daftar semua user (paginated) |
| PUT | `/api/users/:id` | admin | Update data user |
| DELETE | `/api/users/:id` | admin | Nonaktifkan user (soft delete) |

### Profile
| Method | Path | Role | Keterangan |
|---|---|---|---|
| GET | `/api/profile` | semua | Ambil profil sendiri |
| PUT | `/api/profile` | semua | Update profil (nama, HP, alamat) |

---

## Environment Variables

| Variable | Wajib | Keterangan |
|---|---|---|
| `PORT` | — | Default: 3000 |
| `NODE_ENV` | — | `development` atau `production` |
| `SUPABASE_URL` | ✅ | URL project Supabase |
| `SUPABASE_ANON_KEY` | ✅ | Anon/public key |
| `SUPABASE_SERVICE_KEY` | ✅ | Service role key (rahasia, jangan expose) |
| `QR_SECRET_KEY` | ✅ | Key enkripsi AES untuk QR (min 32 karakter) |
| `ALLOWED_ORIGINS` | — | Comma-separated, default: localhost:3000,4000 |
| `OFFICE_LAT` | ✅ | Latitude kantor untuk geofencing |
| `OFFICE_LNG` | ✅ | Longitude kantor untuk geofencing |
| `GEOFENCE_RADIUS_METER` | — | Default: 100 meter |
| `LOG_LEVEL` | — | Default: `info` |

---

## Development Notes

- Backend Express hanya digunakan untuk operasi yang butuh server-side logic:
  check-in (geofencing), check-out (overtime), generate QR, scan QR, export laporan.
  Semua CRUD lain (izin, profil, notifikasi, user management) langsung ke Supabase dari Flutter.
- Auth dikelola sepenuhnya oleh Supabase Auth SDK — tidak ada JWT manual.
- RLS (Row Level Security) aktif di semua tabel Supabase.
- Backend menggunakan service role key (bypass RLS) karena sudah ada RBAC middleware sendiri.
