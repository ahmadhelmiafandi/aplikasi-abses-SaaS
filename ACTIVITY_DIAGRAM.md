# Activity Diagram — Sistem Absensi Karyawan
> Semua diagram menggunakan **Mermaid** syntax.  
> Render di: VS Code (Mermaid Preview extension), GitHub, atau https://mermaid.live

---

## Daftar Diagram

1. [Autentikasi — Login](#1-autentikasi--login)
2. [Autentikasi — Register & Approval Akun](#2-autentikasi--register--approval-akun)
3. [Absensi — Check In (GPS)](#3-absensi--check-in-gps)
4. [Absensi — Check Out & Deteksi Overtime](#4-absensi--check-out--deteksi-overtime)
5. [Absensi — Scan QR Code](#5-absensi--scan-qr-code)
6. [Izin — Pengajuan Izin](#6-izin--pengajuan-izin)
7. [Izin — Alur Approval Multi-Level](#7-izin--alur-approval-multi-level)
8. [Laporan — Generate & Export](#8-laporan--generate--export)
9. [Profil — Update Profil & Ganti Password](#9-profil--update-profil--ganti-password)
10. [Admin — Kelola Karyawan](#10-admin--kelola-karyawan)
11. [Token Refresh — Auto Renew JWT](#11-token-refresh--auto-renew-jwt)
12. [Alur Sistem Keseluruhan (Overview)](#12-alur-sistem-keseluruhan-overview)

---

## 1. Autentikasi — Login

```mermaid
flowchart TD
    A([▶ Start]) --> B[/User buka aplikasi/]
    B --> C{Token tersimpan\ndi secure storage?}

    C -->|Tidak| D[Tampilkan halaman Login]
    C -->|Ya| E[Load user dari storage]
    E --> F[Set status: authenticated]
    F --> G[Tampilkan halaman Beranda]

    D --> H[/User isi email & password/]
    H --> I{Validasi form\ndi frontend}
    I -->|Gagal| J[Tampilkan pesan error\nvalidasi]
    J --> H

    I -->|Lolos| K[POST /api/auth/login]
    K --> L{Rate limiter:\n≤ 10 req / 15 menit?}
    L -->|Limit exceeded| M[Tampilkan: Terlalu banyak\npercobaan. Coba 15 menit lagi]
    M --> D

    L -->|OK| N{Email terdaftar?}
    N -->|Tidak| O[401: Email atau\npassword salah]
    O --> D

    N -->|Ya| P{bcrypt.compare\npassword}
    P -->|Tidak cocok| O

    P -->|Cocok| Q{status_aktif = true?}
    Q -->|false| R[403: Akun menunggu\npersetujuan admin]
    R --> D

    Q -->|true| S[Generate Access Token\n15 menit]
    S --> T[Generate Refresh Token\n7 hari]
    T --> U[Kirim response:\nuser + tokens]

    U --> V[Simpan tokens &\nuser ke secure storage]
    V --> W[Set status: authenticated]
    W --> G

    G --> Z([■ End])
    style A fill:#1E3A8A,color:#fff,stroke:none
    style Z fill:#1E3A8A,color:#fff,stroke:none
    style O fill:#FEE2E2,stroke:#EF4444
    style R fill:#FEE2E2,stroke:#EF4444
    style M fill:#FEE2E2,stroke:#EF4444
    style G fill:#DCFCE7,stroke:#16A34A
```

---

## 2. Autentikasi — Register & Approval Akun

```mermaid
flowchart TD
    A([▶ Start]) --> B[/User klik Daftar Sekarang/]
    B --> C[/Isi form: nama, email,\nnomor_hp, alamat, password/]
    C --> D{Validasi frontend:\n- Nama tidak kosong\n- Email valid\n- Password ≥ 6 karakter\n- Konfirmasi password cocok}

    D -->|Gagal| E[Tampilkan error per field]
    E --> C

    D -->|Lolos| F[POST /api/auth/register]
    F --> G{Email sudah\nterdaftar?}
    G -->|Ya| H[400: Email sudah terdaftar]
    H --> C

    G -->|Tidak| I[bcrypt.hash password]
    I --> J[INSERT users\nstatus_aktif = FALSE\nrole = 'karyawan']
    J --> K[201: Registrasi berhasil\nmenunggu persetujuan admin]
    K --> L[Tampilkan notifikasi\nkembali ke Login]

    L --> M{Admin buka\nApproval Akun}
    M --> N[GET /api/users\nfilter status_aktif = false]
    N --> O[Tampilkan daftar\nakun pending]

    O --> P{Admin pilih aksi}

    P -->|Setujui| Q[PUT /api/users/:id\nstatus_aktif = true]
    Q --> R[Akun aktif, karyawan\nbisa login]
    R --> S([■ End: Login Flow])

    P -->|Tolak| T[PUT /api/users/:id\nstatus_aktif = false\ntetap di DB]
    T --> U[Akun ditolak\ntidak dihapus]
    U --> V([■ End])

    style A fill:#1E3A8A,color:#fff,stroke:none
    style S fill:#1E3A8A,color:#fff,stroke:none
    style V fill:#1E3A8A,color:#fff,stroke:none
    style H fill:#FEE2E2,stroke:#EF4444
    style R fill:#DCFCE7,stroke:#16A34A
```

---

## 3. Absensi — Check In (GPS)

```mermaid
flowchart TD
    A([▶ Start]) --> B[/User klik tombol Check In/]
    B --> C{Sudah check-in\nhari ini?}
    C -->|Ya| D[Tombol disabled\ntidak bisa diklik]
    D --> Z1([■ End])

    C -->|Belum| E{Cek izin\nLokasi di device}
    E -->|Ditolak| F[Tampilkan dialog\nminta izin lokasi]
    F --> G{User beri\nizin?}
    G -->|Tidak| H[Batalkan proses\ntampilkan pesan]
    H --> Z1

    G -->|Ya| I
    E -->|Sudah ada| I[Ambil koordinat GPS\ngetCurrentPosition]

    I --> J[POST /api/absensi/checkin\nlat + lng]
    J --> K{Auth token valid?}
    K -->|Tidak| L[401: Redirect ke login]

    K -->|Valid| M[Ambil jadwal aktif\ngetJadwalAktif userId + today]
    M --> N{Jadwal ditemukan?}
    N -->|Tidak| O[400: Jadwal belum diatur\noleh admin]
    O --> Z2([■ End])

    N -->|Ada| P{is_libur = true?}
    P -->|Ya| Q[400: Hari ini hari libur]
    Q --> Z2

    P -->|Tidak| R{is_wfh = false?\nPerlu geofencing}
    R -->|WFH| S[Skip geofencing]
    R -->|WFO| T[Hitung jarak dari\nkoordinat kantor]
    T --> U{Jarak ≤ radius\nkonfigurasi env?}
    U -->|> radius| V[403: Di luar radius\nkantor Xm]
    V --> Z2

    U -->|≤ radius| S

    S --> W{Sudah ada record\nabsensi hari ini?}
    W -->|Ya| X[400: Sudah check-in]
    X --> Z2

    W -->|Tidak| Y{is_fleksibel = false?\nPerlu cek keterlambatan}
    Y -->|Fleksibel| AA[status = 'hadir'\nmenit_terlambat = 0]
    Y -->|Tidak fleksibel| AB{Waktu sekarang\n> jam_masuk + toleransi?}
    AB -->|Tidak| AA
    AB -->|Ya| AC[status = 'terlambat'\nhitung menit_terlambat]

    AA --> AD[INSERT absensi]
    AC --> AD
    AD --> AE[INSERT log_aktivitas\nCHECK_IN]
    AE --> AF[200: Check-in Berhasil]
    AF --> AG[Refresh todayStatusProvider]
    AG --> AH[Tampilkan status check-in\ndi UI]
    AH --> Z3([■ End])

    style A fill:#1E3A8A,color:#fff,stroke:none
    style Z1 fill:#6B7280,color:#fff,stroke:none
    style Z2 fill:#6B7280,color:#fff,stroke:none
    style Z3 fill:#1E3A8A,color:#fff,stroke:none
    style AF fill:#DCFCE7,stroke:#16A34A
    style V fill:#FEE2E2,stroke:#EF4444
    style Q fill:#FEE2E2,stroke:#EF4444
    style O fill:#FEE2E2,stroke:#EF4444
```

---

## 4. Absensi — Check Out & Deteksi Overtime

```mermaid
flowchart TD
    A([▶ Start]) --> B[/User klik tombol Check Out/]
    B --> C{Sudah check-in\nhari ini?}
    C -->|Belum| D[Tombol disabled]
    D --> Z1([■ End])

    C -->|Ya| E{Sudah check-out?}
    E -->|Ya| D

    E -->|Belum| F[POST /api/absensi/checkout]
    F --> G[Cari record absensi\nhariini]
    G --> H{Record ditemukan\ndan belum checkout?}
    H -->|Tidak| I[400: Belum check-in\natau sudah check-out]
    I --> Z1

    H -->|Ya| J[UPDATE absensi\njam_keluar = now]
    J --> K[Ambil jadwal aktif\nhari ini]
    K --> L{Jadwal ada?\ndan ada jam_keluar}
    L -->|Tidak| M[Selesai tanpa\ncek overtime]

    L -->|Ya| N[Panggil detectOvertime\njamKeluar vs jam_keluar jadwal]
    N --> O{jamKeluar > jam_keluar\njadwal + 30 menit?}
    O -->|Tidak| M

    O -->|Ya| P[Hitung durasi\nmenit lembur]
    P --> Q{Durasi < 60 menit?}
    Q -->|Ya| M[Abaikan, terlalu singkat]

    Q -->|Tidak| R{Hari Sabtu\natau Minggu?}
    R -->|Ya| S[multiplier = 2.0]
    R -->|Tidak| T[multiplier = 1.5]

    S --> U{Ada overtime\nterencana disetujui\nhari ini?}
    T --> U

    U -->|Ya| V[UPDATE overtime\nstatus=selesai\njam_selesai, durasi]
    U -->|Tidak| W[INSERT overtime baru\njenis=spontan, status=selesai]

    V --> X[UPDATE absensi\nis_overtime=true]
    W --> X

    X --> M
    M --> Y[200: Check-out Berhasil]
    Y --> Z[Refresh todayStatusProvider]
    Z --> AA([■ End])

    style A fill:#1E3A8A,color:#fff,stroke:none
    style Z1 fill:#6B7280,color:#fff,stroke:none
    style AA fill:#1E3A8A,color:#fff,stroke:none
    style Y fill:#DCFCE7,stroke:#16A34A
    style I fill:#FEE2E2,stroke:#EF4444
```

---

## 5. Absensi — Scan QR Code

```mermaid
flowchart TD
    A([▶ Start: Admin/HRD\nBuka QR Generator]) --> B[POST /api/qr/generate]
    B --> C[Generate token_unik\ncrypto.randomBytes 16]
    C --> D[Buat payload JSON:\ntoken_unik + lat + lng + expired_at+30s]
    D --> E[Enkripsi payload\nAES dengan QR_SECRET_KEY]
    E --> F[INSERT qr_sessions\nsudah_dipakai=false]
    F --> G[Tampilkan QR Code\ndi layar admin\nberlaku 30 detik]

    G --> H([▶ Karyawan scan QR])
    H --> I[Kamera device\nbaca QR data]
    I --> J[Ambil GPS koordinat\nkaryawan]
    J --> K[POST /api/absensi/scan-qr\nqr_data + lat + lng]

    K --> L[Dekripsi qr_data\ndengan AES]
    L --> M{Dekripsi berhasil?}
    M -->|Gagal| N[400: Data QR\ntidak dapat diproses]
    N --> Z1([■ End: Gagal])

    M -->|Berhasil| O{expired_at\n> sekarang?}
    O -->|Kadaluarsa| P[400: QR Code\nsudah kadaluarsa]
    P --> Z1

    O -->|Valid| Q[Cari token_unik\ndi tabel qr_sessions]
    Q --> R{Token ditemukan\ndan belum dipakai?}
    R -->|Tidak| S[400: QR tidak valid\natau sudah digunakan]
    S --> Z1

    R -->|Ya| T[Hitung jarak karyawan\nke lokasi scanner]
    T --> U{Jarak ≤ 100m?}
    U -->|> 100m| V[403: Terlalu jauh\ndari lokasi scanner]
    V --> Z1

    U -->|OK| W[UPDATE qr_sessions\nsudah_dipakai = true]
    W --> X[Proses Check-In\nlogic sama dengan GPS Check-In]
    X --> Y[200: Check-in via QR\nBerhasil]
    Y --> Z2([■ End: Sukses])

    style A fill:#1E3A8A,color:#fff,stroke:none
    style H fill:#7C3AED,color:#fff,stroke:none
    style Z1 fill:#EF4444,color:#fff,stroke:none
    style Z2 fill:#16A34A,color:#fff,stroke:none
    style N fill:#FEE2E2,stroke:#EF4444
    style P fill:#FEE2E2,stroke:#EF4444
    style S fill:#FEE2E2,stroke:#EF4444
    style V fill:#FEE2E2,stroke:#EF4444
    style Y fill:#DCFCE7,stroke:#16A34A
```

---

## 6. Izin — Pengajuan Izin

```mermaid
flowchart TD
    A([▶ Start]) --> B[/User buka Riwayat Izin/]
    B --> C[/Klik tombol Ajukan Izin/]
    C --> D[Tampilkan form:\njenis izin, tanggal mulai,\ntanggal selesai, alasan]

    D --> E[/User mengisi form/]
    E --> F{Validasi frontend:\n- Jenis izin dipilih\n- Tanggal mulai dipilih\n- Tanggal selesai dipilih\n- Selesai ≥ Mulai\n- Alasan ≥ 5 karakter}

    F -->|Gagal| G[Tampilkan pesan\nerror validasi]
    G --> E

    F -->|Lolos| H[POST /api/izin/ajukan]
    H --> I{tanggal_mulai ≥\nhari ini?}
    I -->|Tidak| J[400: Tanggal tidak\nboleh sudah lewat]
    J --> E

    I -->|Ya| K{Role karyawan?}
    K -->|karyawan| L[current_approver = 'manajer'\nstatus = 'pending']
    K -->|manajer| M[current_approver = 'hrd'\nstatus = 'pending']
    K -->|hrd| N[current_approver = null\nstatus = 'disetujui']

    L --> O[INSERT izin ke DB]
    M --> O
    N --> O

    O --> P[201: Pengajuan berhasil]
    P --> Q[Invalidate myIzinProvider]
    Q --> R[Kembali ke daftar izin\ndengan status PENDING/DISETUJUI]
    R --> Z([■ End])

    style A fill:#1E3A8A,color:#fff,stroke:none
    style Z fill:#1E3A8A,color:#fff,stroke:none
    style J fill:#FEE2E2,stroke:#EF4444
    style P fill:#DCFCE7,stroke:#16A34A
    style N fill:#DCFCE7,stroke:#16A34A
```

---

## 7. Izin — Alur Approval Multi-Level

```mermaid
flowchart TD
    A([▶ Start: Izin diajukan karyawan\ncurrent_approver = 'manajer']) --> B

    subgraph MANAJER ["👤 Manajer (Level 1)"]
        B[GET /api/izin/pending\nfilter: role=manajer + departemen] --> C[Tampilkan list izin pending]
        C --> D{/Manajer pilih aksi/}
        D -->|Setujui| E[PUT /api/izin/:id/review\naction=approve]
        D -->|Tolak| F[PUT /api/izin/:id/review\naction=reject]
    end

    E --> G{Validasi:\nstatus=pending dan\ncurrent_approver=manajer?}
    G -->|Tidak| H[403: Tidak berhak\natau izin sudah final]
    G -->|Ya| I[UPDATE izin:\nstatus = 'pending'\ncurrent_approver = 'hrd']
    I --> J[INSERT izin_approval_logs\nrole=manajer, action=approve]
    J --> K([Lanjut ke HRD ▼])

    F --> L{Validasi sama}
    L -->|Ya| M[UPDATE izin:\nstatus = 'ditolak'\ncurrent_approver = null]
    M --> N[INSERT izin_approval_logs\naction=reject]
    N --> O([■ End: Ditolak])

    subgraph HRD ["👤 HRD (Level 2 — Final)"]
        K --> P[GET /api/izin/pending\nfilter: role=hrd]
        P --> Q[Tampilkan list izin pending]
        Q --> R{/HRD pilih aksi/}
        R -->|Setujui| S[PUT /api/izin/:id/review\naction=approve]
        R -->|Tolak| T[PUT /api/izin/:id/review\naction=reject]
    end

    S --> U[UPDATE izin:\nstatus = 'disetujui'\ncurrent_approver = null]
    U --> V[INSERT izin_approval_logs\nrole=hrd, action=approve]
    V --> W([■ End: DISETUJUI])

    T --> X[UPDATE izin:\nstatus = 'ditolak'\ncurrent_approver = null]
    X --> Y[INSERT izin_approval_logs\nrole=hrd, action=reject]
    Y --> O

    style A fill:#1E3A8A,color:#fff,stroke:none
    style W fill:#16A34A,color:#fff,stroke:none
    style O fill:#EF4444,color:#fff,stroke:none
    style H fill:#FEE2E2,stroke:#EF4444
    style MANAJER fill:#EFF6FF,stroke:#3B82F6
    style HRD fill:#F0FDF4,stroke:#16A34A
```

---

## 8. Laporan — Generate & Export

```mermaid
flowchart TD
    A([▶ Start: Admin/HRD\nbuka Laporan]) --> B[Tampilkan filter:\nbulan + tahun dropdown]
    B --> C[/User pilih bulan & tahun/]
    C --> D[GET /api/laporan/bulanan\n?bulan=X&tahun=Y]

    D --> E{Role user?}
    E -->|admin| F[Query SEMUA departemen]
    E -->|hrd| F
    E -->|manajer| G[Query hanya departemen\nmilik manajer]

    F --> H[Query absensi per karyawan:\nCOUNT hadir, terlambat, izin, alpha]
    G --> H

    H --> I[Hitung summary:\ntotal_hadir, terlambat, izin, alpha]
    I --> J[Return data:\nsummary + details array]
    J --> K[Tampilkan:\n- 4 summary cards\n- Tabel detail per karyawan]

    K --> L{/User klik Export/}
    L -->|Tidak| M([■ End: Lihat saja])

    L -->|Ya| N[Tampilkan dialog:\nPDF atau Excel]
    N --> O{/User pilih format/}

    O -->|PDF| P[POST /api/laporan/export/pdf\n⚠️ Stub — belum diimplementasi]
    O -->|Excel| Q[POST /api/laporan/export/excel\n⚠️ Stub — belum diimplementasi]

    P --> R[Phase 2: Implementasi\nPDFKit di backend]
    Q --> S[Phase 2: Implementasi\nExcelJS di backend]

    R --> T[Kembalikan file binary\nContent-Type: application/pdf]
    S --> U[Kembalikan file binary\nContent-Type: application/xlsx]

    T --> V[Frontend download file\nke device user]
    U --> V
    V --> W([■ End])

    style A fill:#1E3A8A,color:#fff,stroke:none
    style M fill:#6B7280,color:#fff,stroke:none
    style W fill:#1E3A8A,color:#fff,stroke:none
    style P fill:#FEF3C7,stroke:#F59E0B
    style Q fill:#FEF3C7,stroke:#F59E0B
    style R fill:#DBEAFE,stroke:#3B82F6
    style S fill:#DBEAFE,stroke:#3B82F6
```

---

## 9. Profil — Update Profil & Ganti Password

```mermaid
flowchart TD
    A([▶ Start]) --> B[Buka halaman Profil]
    B --> C[GET /api/profile\ntampilkan data user]

    subgraph UPDATE ["✏️ Update Profil"]
        C --> D[/User klik Edit/]
        D --> E[Form fields menjadi editable:\nnama, nomor_hp, alamat]
        E --> F[/User mengubah data/]
        F --> G{Validasi:\nnama tidak kosong}
        G -->|Gagal| H[Tampilkan error]
        H --> F
        G -->|Lolos| I[PUT /api/profile\nnama + nomor_hp + alamat]
        I --> J{Berhasil?}
        J -->|Ya| K[UPDATE users di DB]
        K --> L[Invalidate profileProvider]
        L --> M[updateCachedUser di AuthProvider\nperbarui nama di header]
        M --> N[Tampilkan: Profil diperbarui]
        J -->|Tidak| O[Tampilkan pesan error]
    end

    subgraph PASSWORD ["🔐 Ganti Password"]
        C --> P[/User klik Ganti Password/]
        P --> Q[/Isi: password lama + baru + konfirmasi/]
        Q --> R{Validasi:\n- Password baru ≥ 6 karakter\n- Konfirmasi cocok}
        R -->|Gagal| S[Tampilkan error]
        S --> Q
        R -->|Lolos| T[PUT /api/profile/password\npasswordLama + passwordBaru]
        T --> U[bcrypt.compare\npassword lama di DB]
        U --> V{Cocok?}
        V -->|Tidak| W[400: Password lama salah]
        W --> Q
        V -->|Ya| X[bcrypt.hash password baru]
        X --> Y[UPDATE users.password]
        Y --> Z[200: Password berhasil diubah]
    end

    N --> END([■ End])
    Z --> END
    O --> END

    style A fill:#1E3A8A,color:#fff,stroke:none
    style END fill:#1E3A8A,color:#fff,stroke:none
    style N fill:#DCFCE7,stroke:#16A34A
    style Z fill:#DCFCE7,stroke:#16A34A
    style W fill:#FEE2E2,stroke:#EF4444
    style UPDATE fill:#EFF6FF,stroke:#3B82F6
    style PASSWORD fill:#FDF4FF,stroke:#A855F7
```

---

## 10. Admin — Kelola Karyawan

```mermaid
flowchart TD
    A([▶ Start: Admin\nbuka Kelola Akun]) --> B[GET /api/users\ntampilkan semua karyawan]

    B --> C{/Admin pilih aksi/}

    C -->|Tambah| D[Buka dialog form\nnama, email, password, role]
    D --> E[/Admin isi form/]
    E --> F{Validasi:\nsemua field wajib}
    F -->|Gagal| G[Tampilkan error]
    G --> E
    F -->|Lolos| H[POST /api/users\nbcrypt.hash password]
    H --> I{Email sudah ada?}
    I -->|Ya| J[400: Email sudah terdaftar]
    J --> E
    I -->|Tidak| K[201: Karyawan ditambahkan]

    C -->|Edit| L[Buka dialog form\npre-fill data existing]
    L --> M[/Admin ubah data/]
    M --> N[PUT /api/users/:id\nnama, email, role, status_aktif]
    N --> O{Email bentrok?}
    O -->|Ya| P[400: Email digunakan\noleh lain]
    O -->|Tidak| Q[200: Data diperbarui]

    C -->|Hapus| R[Tampilkan konfirmasi:\n'Data absensi mungkin ikut terhapus']
    R --> S{/Admin konfirmasi?/}
    S -->|Batal| C
    S -->|Ya| T[DELETE /api/users/:id]
    T --> U{Ada FK constraint\nyang mencegah?}
    U -->|Ya| V[400: Gagal hapus\nmasih terhubung data]
    U -->|Tidak| W[200: Pengguna dihapus]

    K --> X[Invalidate usersProvider\nRefresh list]
    Q --> X
    W --> X
    X --> C

    style A fill:#1E3A8A,color:#fff,stroke:none
    style K fill:#DCFCE7,stroke:#16A34A
    style Q fill:#DCFCE7,stroke:#16A34A
    style W fill:#DCFCE7,stroke:#16A34A
    style J fill:#FEE2E2,stroke:#EF4444
    style P fill:#FEE2E2,stroke:#EF4444
    style V fill:#FEE2E2,stroke:#EF4444
```

---

## 11. Token Refresh — Auto Renew JWT

```mermaid
flowchart TD
    A([▶ Start: API request\ngagal dengan 401]) --> B{Dio onError interceptor\nstatus = 401?}

    B -->|Tidak| C[Teruskan error ke handler]
    C --> Z1([■ End: Error normal])

    B -->|Ya| D[Baca refresh_token\ndari secure storage]
    D --> E{Refresh token\ntersedia?}

    E -->|Tidak| F[deleteAll dari storage]
    F --> G[Panggil DioClient.onUnauthorized]
    G --> H[AuthNotifier set status:\nunauthenticated]
    H --> I[GoRouter redirect ke /login]
    I --> Z2([■ End: Logout paksa])

    E -->|Ya| J[POST /api/auth/refresh\nrefresh_token]
    J --> K{Refresh berhasil?\nstatus 200?}

    K -->|Tidak| F

    K -->|Ya| L[Ambil access_token baru]
    L --> M[Simpan ke secure storage:\naccess_token baru]
    M --> N[Update header original request:\nAuthorization: Bearer token_baru]
    N --> O[Retry original request\ndengan token baru]
    O --> P{Retry berhasil?}
    P -->|Ya| Q[Teruskan response\nke screen]
    Q --> Z3([■ End: Sukses])
    P -->|Tidak| R[Teruskan error\nke handler]
    R --> Z1

    style A fill:#1E3A8A,color:#fff,stroke:none
    style Z1 fill:#6B7280,color:#fff,stroke:none
    style Z2 fill:#EF4444,color:#fff,stroke:none
    style Z3 fill:#16A34A,color:#fff,stroke:none
    style F fill:#FEE2E2,stroke:#EF4444
    style Q fill:#DCFCE7,stroke:#16A34A
    style I fill:#FEE2E2,stroke:#EF4444
```

---

## 12. Alur Sistem Keseluruhan (Overview)

```mermaid
flowchart TD
    START([▶ Buka Aplikasi]) --> AUTH{Sudah login?}

    AUTH -->|Tidak| LOGIN[/Login Screen/]
    AUTH -->|Ya| HOME

    LOGIN --> REG{/Belum punya akun?/}
    REG -->|Daftar| REGISTER[/Register Screen/]
    REGISTER --> WAIT[Menunggu\nApproval Admin]
    WAIT --> LOGIN
    REG -->|Login| LOGINACT[Proses Login]
    LOGINACT --> HOME

    HOME[/🏠 Beranda - AbsensiScreen/]

    HOME --> CHECKIN[✅ Check In\nGPS Geofencing]
    HOME --> CHECKOUT[🚪 Check Out\n+ Deteksi Overtime]
    HOME --> IZIN_MENU[📅 Riwayat Izin]
    HOME --> PROFILE_MENU[⚙️ Profil & Pengaturan]

    subgraph ROLE_MANAJER_HRD ["🔐 Role: manajer atau hrd"]
        HOME --> APPROVAL_IZIN[✔️ Approval Izin\nMulti-level Workflow]
    end

    subgraph ROLE_ADMIN_HRD ["🔐 Role: admin atau hrd"]
        HOME --> LAPORAN[📊 Dashboard Laporan\n+ Export PDF/Excel]
    end

    subgraph ROLE_ADMIN ["🔐 Role: admin"]
        HOME --> APPROVAL_AKUN[👤 Approval Akun Baru]
        HOME --> KELOLA[👥 Kelola Karyawan\nCRUD]
    end

    IZIN_MENU --> FORM_IZIN[📝 Form Pengajuan Izin]
    FORM_IZIN --> IZIN_FLOW[Alur Approval\nManajer → HRD]

    CHECKIN --> QR[📷 Scan QR\n⚠️ Phase 2: UI belum ada]

    PROFILE_MENU --> EDIT_PROFIL[Edit Nama, HP, Alamat]
    PROFILE_MENU --> GANTI_PASS[🔐 Ganti Password]

    HOME --> LOGOUT[🚪 Logout\nHapus semua token]
    LOGOUT --> LOGIN

    style START fill:#1E3A8A,color:#fff,stroke:none
    style HOME fill:#1E3A8A,color:#fff,stroke:none
    style CHECKIN fill:#16A34A,color:#fff,stroke:none
    style CHECKOUT fill:#D97706,color:#fff,stroke:none
    style LOGOUT fill:#EF4444,color:#fff,stroke:none
    style QR fill:#FEF3C7,stroke:#F59E0B,color:#92400E
    style ROLE_MANAJER_HRD fill:#EFF6FF,stroke:#3B82F6
    style ROLE_ADMIN_HRD fill:#F0FDF4,stroke:#16A34A
    style ROLE_ADMIN fill:#FDF4FF,stroke:#A855F7
```

---

## Keterangan Simbol & Warna

| Simbol / Warna | Arti |
|---|---|
| `([▶ Start])` / `([■ End])` | Titik awal dan akhir alur |
| `{ }` | Decision / kondisi percabangan |
| `[ ]` | Aksi / proses |
| `[/ /]` | Input dari user |
| 🟦 Biru tua `#1E3A8A` | Start / End utama |
| 🟩 Hijau `#DCFCE7` | Sukses / berhasil |
| 🟥 Merah `#FEE2E2` | Error / gagal |
| 🟨 Kuning `#FEF3C7` | Fitur belum diimplementasi (stub) |
| 🟦 Biru muda | Swimlane role tertentu |

---

## Catatan Implementasi

### Alur yang sudah berjalan ✅
- Login & logout
- Register & approval akun
- Check-in GPS (dengan geofencing)
- Check-out & deteksi overtime
- Pengajuan izin
- Approval izin multi-level (manajer → HRD)
- Lihat laporan bulanan
- Update profil & ganti password
- Kelola karyawan (CRUD)

### Alur yang perlu diperbaiki ⚠️ (Phase 1)
- Token refresh tidak memicu logout → **Task 12**
- Status badge `'hadir'` tidak ditampilkan hijau → **Task 13**
- Form izin tidak validasi tanggal selesai ≥ mulai → **Task 16**
- Reject akun = hard delete → **Task 17**
- Profile update tidak refresh nama di header → **Task 18**

### Alur yang belum ada 🚧 (Phase 2)
- QR Scan: backend ada, frontend UI belum dibuat
- Export laporan: tombol ada, API call belum terhubung
- Notifikasi real-time: tabel `notifikasi` ada, endpoint & UI belum
- Default shift fallback: karyawan tanpa jadwal tidak bisa check-in
