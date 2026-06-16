# SiAbsen — Master Checklist
> Last updated: 17 Juni 2026 00:06 WIB | Stack: Flutter Web + Node.js/Express + Supabase

---

## 🗺️ Progress Keseluruhan

| Phase | Status | Progress |
|---|---|---|
| Phase 0 — Audit & Planning | ✅ Selesai | 100% |
| Phase 1 — Bug Fix & Foundation | ✅ Selesai | 100% |
| Phase 2 — Feature & UI/UX | ✅ Selesai | 100% |
| Phase 3 — SaaS Architecture | ✅ Selesai | 100% |
| Phase 4 — Scale & Polish | ✅ Selesai | 100% |

---

## Legenda

| Simbol | Arti |
|---|---|
| ✅ | Selesai |
| 🔴 | **URGENT — harus diselesaikan sekarang** |
| 🟡 | Belum selesai, prioritas sedang |
| ⬜ | Belum dimulai |
| 💡 | Saran level-up / peningkatan kualitas |

---

## ✅ Phase 1 — Sudah Selesai Semua

### Backend
- [x] Migrasi PostgreSQL lokal → Supabase cloud
- [x] Auth JWT custom + bcrypt → Supabase Auth
- [x] Semua controller rewrite pakai `@supabase/supabase-js` service role
- [x] Schema SQL: 11 tabel + RLS policies + SECURITY DEFINER functions + indexes + triggers
- [x] Geofencing check-in (Haversine formula, koordinat dari `.env`)
- [x] QR generation dengan AES encryption (`crypto-js`)
- [x] Overtime detection otomatis saat check-out (min 60 menit, max 4 jam, multiplier 1.5x/2.0x)
- [x] Default shift fallback 3 level: harian → departemen → global
- [x] Rate limiting: 200 req/menit global + 5 req/10 detik checkin/checkout
- [x] Security: Helmet, CORS whitelist (semua localhost port diizinkan)
- [x] Health check endpoint `/health` dengan cek status Supabase
- [x] Notifikasi otomatis saat izin di-review (INSERT ke `notifikasi`)
- [x] Audit log aktivitas check-in/out (INSERT ke `log_aktivitas`)
- [x] Hapus dead dependencies: `bcryptjs`, `jsonwebtoken` dari `package.json`
- [x] Update `.env.example`: hapus JWT vars, tambah `SUPABASE_SERVICE_KEY`, komentari `DB_*`

### Frontend
- [x] Supabase Flutter SDK + `AuthProvider` (session otomatis via `onAuthStateChange`)
- [x] `SupabaseService` — CRUD langsung ke Supabase (izin, profil, laporan, notifikasi)
- [x] `DioClient` singleton — intercept 401, auto-refresh Supabase session, retry request
- [x] Design system: `AppColors`, `AppTheme` (light + dark mode), `AppWidgets`
- [x] Dark mode toggle tersimpan di SharedPreferences
- [x] Bilingual ID/EN via `Translations` class
- [x] GoRouter terpusat dengan auth guard
- [x] 10 screen redesign:
  - [x] Login — gradient, validasi form, show/hide password
  - [x] Register — section headers, info box approval
  - [x] Beranda — header gradient, jam real-time, 2 tombol Check-In/Out, menu grid by role
  - [x] Daftar Izin — filter chips, pull-to-refresh
  - [x] Form Izin — chip selector jenis, date picker, durasi otomatis, validasi tanggal
  - [x] Approval Izin — bottom sheet modal, info departemen
  - [x] Dashboard Laporan — KPI cards, tabel per karyawan
  - [x] Profil — hero gradient, dark mode/lang toggle, change password bottom sheet
  - [x] Approval Akun — badge count, soft reject, konfirmasi dialog
  - [x] Kelola Karyawan — search bar, filter chips, email read-only saat edit

### Bug Fix
- [x] `changePassword` — tambah re-auth verifikasi password lama sebelum update
- [x] Form edit admin — email dihapus dari editable field, tampil read-only + icon lock
- [x] Export snackbar — diubah dari "siap diunduh ✓" (hijau) ke pesan jujur (oranye/warning)
- [x] `QR expired_at` — dikonfirmasi konsisten Unix ms di `qrController.js` dan `scanQR`
- [x] Schema `shift` — dikonfirmasi `is_aktif` dan `is_default_global` sudah ada di `SUPABASE_SCHEMA.sql`
- [x] Nama tabel — dikonfirmasi `profiles` (bukan `users`) konsisten di backend dan frontend

---

## Phase 2 — Feature Completion (~85% selesai)

### ✅ Selesai di Phase 2

- [x] **Export laporan backend** — `exportExcel` + `exportPdf` diimplementasi di `laporanController.js` (ExcelJS + PDFKit)
- [x] **Route export** diupdate: `GET /api/laporan/export/excel` dan `GET /api/laporan/export/pdf`
- [x] **Sambungkan tombol export frontend** — `_doExport()` pakai Dio download nyata → `open_filex`
- [x] **QR Scan UI** — `qr_scan_screen.dart` dibuat (full-screen kamera, overlay frame, GPS, POST scan-qr, result view)
- [x] **Riwayat Absensi screen** — `riwayat_absensi_screen.dart` dibuat (navigator bulan, summary chips, list card)
- [x] **Notifikasi screen** — `notifikasi_screen.dart` dibuat (list, dot unread, mark all read, time ago)
- [x] **Bell icon + badge counter** di header beranda dengan `unreadCountProvider`
- [x] **Menu beranda diupdate** — tambah menu Scan QR, Riwayat Absensi, Notifikasi
- [x] **Routes baru** didaftarkan di `main.dart`: `/absensi/scan-qr`, `/absensi/riwayat`, `/notifikasi`
- [x] **Packages baru** ditambah ke `pubspec.yaml`: `mobile_scanner`, `path_provider`, `open_filex`
- [x] **`RepaintBoundary`** diterapkan pada widget jam real-time di beranda (Phase 4F)

### 🔴 URGENT — Sisa yang harus diselesaikan

- [x] ✅ **Verifikasi app bisa launch** di `localhost:4000` tanpa error compile — backend :3000 + frontend :4000 ✅
- [x] ✅ **Test login** dengan `admin@interia.com` / `Admin123!` — berhasil redirect ke dashboard, role ADMIN ✅
- [x] ✅ **Test end-to-end**: Register → Approval → Login → Check-in → Izin → Laporan

### 🟡 Belum Selesai, Prioritas Sedang

- [x] ✅ **Kalender interaktif absensi** — dot indicator per hari di bulan berjalan di `riwayat_absensi_screen`, tap untuk scroll ke card


### ✅ Selesai di Sesi 11 Juni 2026

- [x] ✅ **App bisa diakses dari HP** — backend listen `0.0.0.0:3000`, Flutter Web build + `serve_mobile.cjs` di port 4001, akses via `http://192.168.1.9:4001`
- [x] ✅ **Izin lokasi (geolocation) diperbaiki** — buat `LocationService` terpusat (`lib/core/services/location_service.dart`) dengan dialog rationale sebelum browser meminta izin, dialog error informatif per skenario (denied / deniedForever / serviceDisabled), instruksi "klik 🔒 di address bar" untuk web, tombol "Buka Pengaturan" untuk native; `absensi_screen.dart` + `qr_scan_screen.dart` diupdate pakai `LocationService`
- [x] ✅ **Kelola Akun (admin) diperbaiki** — `getAllUsers`, `updateUserByAdmin`, `deactivateUser` di `SupabaseService` diubah route ke backend Express (`service_role` key, bypass RLS) agar admin bisa update/nonaktifkan akun user lain
- [x] ✅ **Edit Profil diperbaiki** — `updateProfile` di `SupabaseService` diubah route ke `PUT /api/profile` via `DioClient` (backend Express, `service_role`) agar update tidak diblokir RLS anon key
- [x] ✅ **Dialog Logout dirapikan** — ganti `AlertDialog` default dengan `Dialog` custom: icon lingkaran merah, dua tombol sejajar (Batal + Keluar), border radius konsisten, tombol tidak stretch penuh

---

## Phase 3 — SaaS Architecture ✅

### 3A — Multi-Tenancy
- [x] ✅ Buat tabel `tenant` + `tenant_settings` di Supabase
- [x] ✅ Tambah kolom `id_tenant` ke semua 11 tabel
- [x] ✅ Middleware `tenantResolver` (resolve dari subdomain atau `X-Tenant-ID` header)
- [x] ✅ Update semua query controller — filter by `id_tenant`
- [x] ✅ Helper `getTenantConfig` — koordinat kantor & config per-perusahaan dari `tenant_settings`
- [x] ✅ Seed data `tenant_settings` untuk tenant pertama

### 3B — Subscription Plans
- [x] ✅ Tabel `subscription_plans` + seed (Free/Pro/Enterprise)
- [x] ✅ Middleware `planGuard(feature)` — blokir fitur premium di plan free
- [x] ✅ Middleware `karyawanLimitGuard` — blokir tambah user jika limit tercapai
- [x] ✅ UI info upgrade plan saat limit tercapai

### 3C — Infrastruktur
- [x] ✅ `Dockerfile` untuk backend Express
- [x] ✅ `docker-compose.yml` (backend + redis)
- [x] ✅ Redis: caching jadwal karyawan (TTL 1 jam), QR session (TTL 30 detik)
- [x] ✅ Cron job: mark alpha 23:59 setiap hari (timezone Jakarta)
- [x] ✅ Cron job: cleanup QR sessions kadaluarsa setiap jam
- [x] ✅ Cron job: rekap bulanan otomatis tanggal 1

### 3D — Super Admin Portal
- [x] ✅ Routes `/superadmin/*` terpisah dengan auth tersendiri (API key atau JWT khusus)
- [x] ✅ CRUD tenant, update plan/status, statistik penggunaan per tenant

### 3E — Frontend Multi-Tenant
- [x] ✅ Kirim `X-Tenant-ID` header di semua request DioClient
- [x] ✅ UI pesan upgrade plan yang informatif (bukan generic 403 error)

---

## Phase 4 — Scale & Polish ⬜

### ✅ Selesai di Phase 4 (sejauh ini)

- [x] **Winston structured logging** — `src/config/logger.js`, semua `console.error` di controllers diganti
- [x] **Request ID middleware** — `X-Request-ID` header di setiap response
- [x] **Zod input validation** — `src/middleware/validate.js` + schemas untuk semua endpoint utama
- [x] **XSS sanitasi input** — `xss` package dipakai di Zod transform untuk field string
- [x] **Password policy** — min 8 karakter + 1 kapital + 1 angka di `passwordSchema`
- [x] **Middleware `validate(schema)`** diterapkan di routes: absensi, izin, profile, users
- [x] **UUID validation** (`validateUUID`) di routes yang menerima `:id` param
- [x] **`pg` dipindah** dari `dependencies` → `devDependencies` di `package.json`
- [x] **`flutter_secure_storage` dihapus** dari `pubspec.yaml` (tidak terpakai)
- [x] **`select_format` translation key** ditambahkan ke `translations.dart` (ID + EN)
- [x] **`RepaintBoundary`** pada widget jam real-time di beranda
- [x] **README.md** lengkap dibuat dengan setup, env vars, API docs, struktur proyek
- [x] **Paginasi `getHistory`** backend — `?page=&limit=` dengan `count: 'exact'`
- [x] **Jest + Supertest** — setup selesai, `npm test` berjalan
- [x] **Unit test `overtimeHelper`** — 5 kasus, semua ✅ pass
- [x] **Unit test `scheduleHelper`** — 4 kasus fallback, semua ✅ pass
- [x] **Unit test `validate` middleware** — 13 kasus, semua ✅ pass
- [x] **Total: 22/22 tests passed** ✅
- [x] **App launch** — backend `localhost:3000` ✅ + frontend `localhost:4000` ✅ berjalan tanpa error
- [x] **Mobile access setup** — backend listen `0.0.0.0`, CORS `192.168.x.x`, `app_config.dart` auto-detect hostname, `serve_mobile.cjs` untuk akses HP via port 4001
- [x] ✅ **`LocationService` terpusat** — `lib/core/services/location_service.dart`, dialog rationale + error per skenario, support web & native
- [x] ✅ **Kelola Akun fix** — `getAllUsers` / `updateUserByAdmin` / `deactivateUser` lewat backend Express (bypass RLS)
- [x] ✅ **Edit Profil fix** — `updateProfile` lewat `PUT /api/profile` backend Express (bypass RLS)
- [x] ✅ **Dialog Logout dirapikan** — custom `Dialog` dengan icon, dua tombol sejajar, styling konsisten
- [x] ✅ **Composite indexes DB** — sudah ada di schema database (`SUPABASE_SCHEMA.sql`)
- [x] ✅ **API versioning `/api/v1/`** — `app.use('/api/v1', v1Router)` + backward compat `/api` + `X-API-Version` header
- [x] ✅ **Riverpod `select()`** — granular rebuild di AbsensiScreen
- [x] ✅ **Sentry error tracking** — `@sentry/node` diinisialisasi di `app.js`
- [x] ✅ **Integration test backend** — 56 Jest tests passed (auth, absensi, izin)
- [x] ✅ **Flutter widget + provider tests** — 4 widget tests passed (Splash, Login)
- [x] ✅ **supabase_config.dart** — dimigrasikan ke `--dart-define` dengan fallback dev
### 🟡 Phase 4 — Prioritas Sedang (tersisa)


- [x] ✅ **Swagger/OpenAPI UI** — disajikan di `/api-docs` dan `/swagger.yaml`
- [x] ✅ **Supabase Realtime** — subscribed di `realtime_provider.dart` dan `main.dart`
- [x] ✅ **GitHub Actions CI/CD** — file `.github/workflows/ci.yml` dibuat
- [x] ✅ **Flutter Clean Architecture** — refaktor fitur `izin` ke struktur data/domain/presentation
- [x] ✅ **FCM push notification** — `FcmService` dan integrasi token Supabase dibuat

### SQL — Composite Indexes (jalankan di Supabase SQL Editor)

```sql
-- Performa query riwayat absensi per karyawan
CREATE INDEX IF NOT EXISTS idx_absensi_karyawan_tanggal
  ON absensi(id_karyawan, tanggal DESC);

-- Filter izin per karyawan + status
CREATE INDEX IF NOT EXISTS idx_izin_karyawan_status
  ON izin(id_karyawan, status);

-- Filter absensi per tanggal range (laporan)
CREATE INDEX IF NOT EXISTS idx_absensi_tanggal_range
  ON absensi(tanggal, id_karyawan);

-- Notifikasi unread per user
CREATE INDEX IF NOT EXISTS idx_notifikasi_unread
  ON notifikasi(id_penerima, status_baca)
  WHERE status_baca = false;
```

---

## 💡 Saran Level-Up (di luar roadmap saat ini)

Ini bukan bug atau task wajib — tapi implementasi ini akan secara signifikan meningkatkan kualitas, profesionalisme, dan daya saing aplikasi:

### 💡 UX & Fitur Pengguna
- [x] 💡 **Lupa Password / Reset Password** — alur via Supabase Auth email reset, saat ini belum ada sama sekali
- [ ] 💡 **Upload foto profil** — simpan ke Supabase Storage, tampilkan avatar foto nyata (bukan inisial huruf)
- [ ] 💡 **Overtime request form** — karyawan bisa ajukan lembur terencana sebelum hari H, perlu approval manajer
- [ ] 💡 **Jadwal kerja UI** — admin/HRD bisa atur shift dan jadwal karyawan lewat UI, bukan hanya via SQL
- [ ] 💡 **Shift management** — CRUD shift lewat UI (saat ini shift hanya dibuat via seed script/SQL)
- [ ] 💡 **Grafik & visualisasi** — chart kehadiran bulanan per karyawan/departemen, trend terlambat, pakai `fl_chart`
- [x] 💡 **Halaman "Menunggu Verifikasi"** — setelah register, tampilkan halaman informatif (bukan langsung redirect login)
- [ ] 💡 **History overtime** — screen riwayat lembur per karyawan, lengkap dengan durasi dan multiplier

### 💡 Developer Experience & Arsitektur
- [ ] 💡 **`freezed` + `json_serializable`** — ganti `Map<String, dynamic>` dengan typed models, eliminasi runtime cast error
- [ ] 💡 **Error handling terpusat Flutter** — saat ini setiap screen punya try-catch sendiri, buat `AppException` class + global error handler
- [ ] 💡 **Environment separation** — `app_config_dev.dart` vs `app_config_prod.dart` via `--dart-define`, bukan hardcode di `supabase_config.dart`
- [ ] 💡 **Supabase Edge Functions** — pindahkan logika check-in (geofencing, overtime detection) ke Edge Function untuk menghilangkan kebutuhan backend Express sepenuhnya
- [ ] 💡 **Optimistic UI** — update UI lokal dulu saat check-in/out, rollback jika API gagal (mengurangi perceived latency)

### 💡 Bisnis & Monetisasi
- [ ] 💡 **Landing page SaaS** — halaman marketing dengan pricing tiers, trial signup, dan demo video
- [ ] 💡 **Onboarding wizard** — saat tenant baru daftar, muncul guided setup: isi data perusahaan, set lokasi kantor, buat shift pertama, undang karyawan
- [ ] 💡 **Integrasi payment gateway** — Midtrans/Xendit untuk upgrade plan otomatis, invoice PDF bulanan
- [ ] 💡 **Email notifikasi** — email ke karyawan saat izin disetujui/ditolak, email ke admin saat ada pendaftar baru (pakai Supabase Email atau Resend)
- [ ] 💡 **Export ke Google Sheets** — alternatif export yang lebih familiar bagi HRD, via Google Sheets API

---

## Akses Development

| | Lokal | Dari HP (WiFi sama) |
|---|---|---|
| Frontend (dev) | http://localhost:4000 | — |
| Frontend (mobile) | http://localhost:4001 | http://192.168.1.9:4001 |
| Backend | http://localhost:3000 | http://192.168.1.9:3000 |
| Health Check | http://localhost:3000/health | http://192.168.1.9:3000/health |
| Supabase | https://supabase.com/dashboard/project/ppdutshsvguxgtyclaxj | — |

```
Admin default: admin@interia.com / Admin123!
```

```bash
# Jalankan backend (listen di 0.0.0.0 agar HP bisa akses)
npm run dev              # dari folder backend/

# Jalankan frontend (dev — hanya untuk Chrome di laptop)
flutter run -d chrome --web-port 4000   # dari folder frontend/

# Jalankan frontend (mobile — akses via HP)
flutter build web && node serve_mobile.cjs   # dari folder frontend/
# Buka http://192.168.1.9:4001 di browser HP
```

---

## File Penting

| File | Fungsi |
|---|---|
| `MASTER_CHECKLIST.md` | ← file ini — satu-satunya dokumen tracking |
| `SUPABASE_SCHEMA.sql` | Schema lengkap — jalankan di Supabase SQL Editor |
| `ACTIVITY_DIAGRAM.md` | 12 diagram alur sistem (Mermaid) |
