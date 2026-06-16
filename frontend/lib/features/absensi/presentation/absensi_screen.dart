import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/location_service.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../notifikasi/presentation/notifikasi_screen.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final todayStatusProvider = FutureProvider.autoDispose((ref) async {
  return await SupabaseService.getTodayAbsensi();
});

// ── Screen ────────────────────────────────────────────────────────────────────
class AbsensiScreen extends ConsumerStatefulWidget {
  const AbsensiScreen({super.key});
  @override
  ConsumerState<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends ConsumerState<AbsensiScreen> {
  Timer? _timer;
  String _currentTime = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _greeting(String lang) {
    final h = DateTime.now().hour;
    if (h < 12) return Tr.get('good_morning', lang);
    if (h < 17) return Tr.get('good_afternoon', lang);
    return Tr.get('good_evening', lang);
  }

  // ── Check In ────────────────────────────────────────────────────────────────
  Future<void> _checkIn() async {
    setState(() => _isLoading = true);
    try {
      LocationResult locationResult;

      // Cek apakah perlu tampilkan rationale dulu
      if (await LocationService.shouldShowRationale()) {
        if (!mounted) return;
        locationResult = await LocationService.showRationaleAndRequest(
            context, lang: ref.read(langProvider));
      } else {
        locationResult = await LocationService.requestAndGet();
      }

      if (locationResult is! LocationSuccess) {
        if (mounted) {
          await LocationService.showLocationErrorDialog(
              context, locationResult,
              lang: ref.read(langProvider));
        }
        return;
      }

      final pos = locationResult.position;
      await DioClient().dio.post('/absensi/checkin', data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      ref.invalidate(todayStatusProvider);
      _showSnack(Tr.get('check_in_success', ref.read(langProvider)));
    } on DioException catch (e) {
      _showSnack(e.response?.data['message'] ?? 'Gagal check-in', isError: true);
    } catch (_) {
      _showSnack('Gagal check-in', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Check Out ───────────────────────────────────────────────────────────────
  Future<void> _checkOut() async {
    setState(() => _isLoading = true);
    try {
      await DioClient().dio.post('/absensi/checkout');
      ref.invalidate(todayStatusProvider);
      _showSnack(Tr.get('check_out_success', ref.read(langProvider)));
    } on DioException catch (e) {
      _showSnack(e.response?.data['message'] ?? 'Gagal check-out', isError: true);
    } catch (_) {
      _showSnack('Gagal check-out', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang       = ref.watch(langProvider);
    final isDark     = ref.watch(darkModeProvider);

    // select() — hanya rebuild saat nama/role berubah, bukan saat token refresh
    final userName   = ref.watch(authProvider.select((s) => s.user?['nama'] as String? ?? 'User'));
    final userRole   = ref.watch(authProvider.select((s) => s.user?['role'] as String? ?? ''));
    final userMap    = ref.watch(authProvider.select((s) => s.user));

    final todayAsync  = ref.watch(todayStatusProvider);
    final unreadAsync = ref.watch(unreadCountProvider);
    final isWide      = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayStatusProvider);
          ref.invalidate(unreadCountProvider);
        },
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(userMap, lang, isDark, unreadAsync),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  RepaintBoundary(
                    child: _ClockCard(
                      currentTime: _currentTime,
                      lang: lang,
                      todayAsync: todayAsync,
                      isWide: isWide,
                    ),
                  ),
                  const SizedBox(height: 16),
                  todayAsync.when(
                    data: (data) => _CheckButtons(
                      data: data,
                      isLoading: _isLoading,
                      lang: lang,
                      onCheckIn: _checkIn,
                      onCheckOut: _checkOut,
                    ),
                    loading: () => const SizedBox(height: 80),
                    error: (_, __) => const SizedBox(height: 80),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    Tr.get('menu', lang),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuGrid(userRole, isWide, lang),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────
  Widget _buildHeader(Map<String, dynamic>? user, String lang, bool isDark,
      AsyncValue<int> unreadAsync) {
    final unreadCount = unreadAsync.valueOrNull ?? 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(lang),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13),
                        ),
                        Text(
                          user?['nama'] ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dark mode
                  _HeaderAction(
                    icon: isDark ? Icons.light_mode : Icons.dark_mode,
                    onTap: () =>
                        ref.read(darkModeProvider.notifier).toggle(),
                  ),
                  const SizedBox(width: 8),
                  // Language
                  _HeaderAction(
                    label: lang == 'id' ? 'EN' : 'ID',
                    icon: Icons.language,
                    onTap: () =>
                        ref.read(langProvider.notifier).toggle(),
                  ),
                  const SizedBox(width: 8),
                  // 🔔 Notifikasi bell dengan badge
                  GestureDetector(
                    onTap: () => context.push('/notifikasi').then((_) {
                      ref.invalidate(unreadCountProvider);
                    }),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 18),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Avatar → profil
                  GestureDetector(
                    onTap: () => context.push('/profil'),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        (user?['nama'] as String? ?? 'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  RoleBadge(role: user?['role'] ?? 'karyawan'),
                  const Spacer(),
                  GestureDetector(
                    onTap: _confirmLogout,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.logout,
                              color: Colors.white.withOpacity(0.8), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            Tr.get('logout', lang),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    final lang = ref.read(langProvider);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                Tr.get('logout', lang),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                Tr.get('confirm_logout', lang),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Text(
                        Tr.get('cancel', lang),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(authProvider.notifier).logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        Tr.get('logout', lang),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Menu Grid ─────────────────────────────────────────────────────────────
  Widget _buildMenuGrid(String role, bool isWide, String lang) {
    final items = <_MenuItem>[
      // Riwayat Absensi — semua role
      _MenuItem(
        title: Tr.get('attendance_history', lang),
        icon: Icons.history_rounded,
        color: const Color(0xFF0F766E),
        route: '/absensi/riwayat',
      ),
      // Izin — semua role
      _MenuItem(
        title: Tr.get('izin', lang),
        icon: Icons.event_note_outlined,
        color: const Color(0xFF0891B2),
        route: '/izin',
      ),
      // Scan QR — semua role
      _MenuItem(
        title: Tr.get('scan_qr', lang),
        icon: Icons.qr_code_scanner,
        color: const Color(0xFF7C3AED),
        route: '/absensi/scan-qr',
      ),
    ];

    if (role == 'admin' || role == 'hrd') {
      items.add(_MenuItem(
        title: Tr.get('reports', lang),
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF6D28D9),
        route: '/laporan',
      ));
    }
    if (role == 'manajer' || role == 'hrd') {
      items.add(_MenuItem(
        title: Tr.get('approval_izin', lang),
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF059669),
        route: '/approval/izin',
      ));
    }
    if (role == 'admin') {
      items.add(_MenuItem(
        title: Tr.get('approval_account', lang),
        icon: Icons.person_add_outlined,
        color: const Color(0xFFD97706),
        route: '/admin/approval-akun',
      ));
      items.add(_MenuItem(
        title: Tr.get('manage_accounts', lang),
        icon: Icons.people_outline,
        color: const Color(0xFFDC2626),
        route: '/admin/kelola-akun',
      ));
    }

    final cols = isWide ? 4 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _MenuTile(item: items[i]),
    );
  }
}

// ── Clock Card ────────────────────────────────────────────────────────────────
class _ClockCard extends StatelessWidget {
  final String currentTime;
  final String lang;
  final AsyncValue<dynamic> todayAsync;
  final bool isWide;

  const _ClockCard({
    required this.currentTime,
    required this.lang,
    required this.todayAsync,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFFED7AA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              Tr.get('today_attendance', lang),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM yyyy',
                              lang == 'id' ? 'id_ID' : 'en_US')
                          .format(DateTime.now()),
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // FittedBox mencegah wrap — jam akan scale down jika sempit
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currentTime,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                          letterSpacing: 1,
                          // Tabular figures: semua digit lebar sama → tidak naik turun
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              todayAsync.when(
                data: (data) => data != null
                    ? StatusBadge(status: data['status'] ?? 'hadir', fontSize: 12, lang: lang)
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.warning.withOpacity(0.4)),
                        ),
                        child: Text(
                          Tr.get('belum_absen', lang),
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                loading: () => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
          todayAsync.when(
            data: (data) {
              if (data == null) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    _TimeChip(
                      icon: Icons.login,
                      label: Tr.get('jam_masuk', lang),
                      time: data['jam_masuk'] ?? '-',
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 12),
                    _TimeChip(
                      icon: Icons.logout,
                      label: Tr.get('jam_keluar', lang),
                      time: data['jam_keluar'] ?? '-',
                      color: AppColors.danger,
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Error: $e',
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color color;

  const _TimeChip({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
              Text(time,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Check Buttons ─────────────────────────────────────────────────────────────
class _CheckButtons extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final String lang;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  const _CheckButtons({
    required this.data,
    required this.isLoading,
    required this.lang,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  @override
  Widget build(BuildContext context) {
    final hasCheckedIn  = data != null;
    final hasCheckedOut = data != null && data!['jam_keluar'] != null;

    return Row(
      children: [
        Expanded(
          child: _BigActionBtn(
            label: Tr.get('check_in', lang),
            icon: Icons.fingerprint,
            color: AppColors.success,
            enabled: !hasCheckedIn && !isLoading,
            isLoading: isLoading && !hasCheckedIn,
            onTap: onCheckIn,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigActionBtn(
            label: Tr.get('check_out', lang),
            icon: Icons.door_back_door_outlined,
            color: AppColors.danger,
            enabled: hasCheckedIn && !hasCheckedOut && !isLoading,
            isLoading: isLoading && hasCheckedIn && !hasCheckedOut,
            onTap: onCheckOut,
          ),
        ),
      ],
    );
  }
}

class _BigActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _BigActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                isLoading
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 6),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Menu Tile ─────────────────────────────────────────────────────────────────
class _MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _MenuItem(
      {required this.title,
      required this.icon,
      required this.color,
      required this.route});
}

class _MenuTile extends StatelessWidget {
  final _MenuItem item;
  const _MenuTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      onTap: () => context.push(item.route),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header Action ─────────────────────────────────────────────────────────────
class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  const _HeaderAction({required this.icon, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: label != null ? 10 : 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
