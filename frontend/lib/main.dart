import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/absensi/presentation/absensi_screen.dart';
import 'features/absensi/presentation/qr_scan_screen.dart';
import 'features/absensi/presentation/riwayat_absensi_screen.dart';
import 'features/izin/presentation/daftar_izin_screen.dart';
import 'features/izin/presentation/form_izin_screen.dart';
import 'features/izin/presentation/approval_izin_screen.dart';
import 'features/laporan/presentation/dashboard_laporan_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/admin/presentation/approval_akun_screen.dart';
import 'features/admin/presentation/kelola_karyawan_screen.dart';
import 'features/notifikasi/presentation/notifikasi_screen.dart';
import 'features/auth/presentation/pending_approval_screen.dart';
import 'core/providers/realtime_provider.dart';
import 'core/services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi locale data untuk DateFormat (id_ID & en_US)
  await initializeDateFormatting('id_ID', null);
  await initializeDateFormatting('en_US', null);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Inisialisasi Firebase Cloud Messaging (FCM)
  await FcmService().init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState  = ref.watch(authProvider);
    final isDarkMode = ref.watch(darkModeProvider);

    // Hubungkan/putuskan Supabase Realtime berdasarkan status login
    if (authState.status == AuthStatus.authenticated &&
        authState.user?['status_aktif'] == true) {
      // Jalankan setelah build selesai agar aman dari side-effects
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(realtimeProvider.notifier).startListening();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(realtimeProvider.notifier).stopListening();
      });
    }

    // Splash / loading state
    if (authState.status == AuthStatus.loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: const _SplashScreen(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('id', 'ID'),
          Locale('en', 'US'),
        ],
      );
    }

    final router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final isAuth      = authState.status == AuthStatus.authenticated;
        final isAuthRoute = ['/login', '/register'].contains(state.matchedLocation);
        final isPending   = state.matchedLocation == '/pending-approval';

        if (!isAuth && !isAuthRoute) return '/login';
        if (isAuth && isAuthRoute) {
          // Cek apakah akun belum aktif
          final statusAktif = authState.user?['status_aktif'] ?? true;
          return statusAktif == true ? '/' : '/pending-approval';
        }

        // Akun sudah login tapi belum aktif → paksa ke pending page
        if (isAuth && !isPending && !isAuthRoute) {
          final statusAktif = authState.user?['status_aktif'] ?? true;
          if (statusAktif == false) return '/pending-approval';
        }

        // Akun sudah aktif tapi masih di pending page → redirect ke home
        if (isAuth && isPending) {
          final statusAktif = authState.user?['status_aktif'] ?? true;
          if (statusAktif == true) return '/';
        }

        return null;
      },
      routes: [
        // ── Core ───────────────────────────────────────────────────────────
        GoRoute(path: '/',      builder: (c, s) => const AbsensiScreen()),
        GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
        GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
        GoRoute(path: '/pending-approval', builder: (c, s) => const PendingApprovalScreen()),

        // ── Absensi ────────────────────────────────────────────────────────
        GoRoute(path: '/absensi/scan-qr',  builder: (c, s) => const QrScanScreen()),
        GoRoute(path: '/absensi/riwayat',  builder: (c, s) => const RiwayatAbsensiScreen()),

        // ── Izin ───────────────────────────────────────────────────────────
        GoRoute(path: '/izin',         builder: (c, s) => const DaftarIzinScreen()),
        GoRoute(path: '/izin/ajukan',  builder: (c, s) => const FormIzinScreen()),
        GoRoute(path: '/approval/izin', builder: (c, s) => const ApprovalIzinScreen()),

        // ── Laporan ────────────────────────────────────────────────────────
        GoRoute(path: '/laporan', builder: (c, s) => const DashboardLaporanScreen()),

        // ── Profil & Notifikasi ────────────────────────────────────────────
        GoRoute(path: '/profil',       builder: (c, s) => const ProfileScreen()),
        GoRoute(path: '/notifikasi',   builder: (c, s) => const NotifikasiScreen()),

        // ── Admin ──────────────────────────────────────────────────────────
        GoRoute(path: '/admin/approval-akun', builder: (c, s) => const ApprovalAkunScreen()),
        GoRoute(path: '/admin/kelola-akun',   builder: (c, s) => const KelolaKaryawanScreen()),
      ],
    );

    return MaterialApp.router(
      title: 'SiAbsen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      // Locale support — diperlukan agar DateFormat('id_ID') bekerja
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
    );
  }
}

// ── Splash Screen ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/logo.jpg',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SiAbsen',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sistem Absensi Karyawan',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
