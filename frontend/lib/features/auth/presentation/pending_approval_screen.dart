import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'auth_provider.dart';

/// Ditampilkan ketika user sudah terdaftar tapi [status_aktif] masih false.
/// User tidak bisa mengakses fitur apapun sampai admin mengaktifkan akun.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState
    extends ConsumerState<PendingApprovalScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    // Reload profil — jika sudah diaktifkan, router otomatis redirect
    await ref.read(authProvider.notifier).reloadProfile();

    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final user  = ref.watch(currentUserProvider);
    final lang  = ref.watch(langProvider);
    final nama  = user?['nama']?.toString() ?? (lang == 'id' ? 'Karyawan' : 'Employee');
    final email = user?['email']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Ilustrasi ────────────────────────────────────────
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.35),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.hourglass_top_rounded,
                            size: 58, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Judul ────────────────────────────────────────────
                    Text(
                      lang == 'id' ? 'Akun Sedang Ditinjau' : 'Account Under Review',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lang == 'id' ? 'Halo, $nama!' : 'Hello, $nama!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lang == 'id'
                          ? 'Registrasi Anda berhasil. Admin sedang memproses '
                            'aktivasi akun. Anda akan dapat menggunakan SiAbsen '
                            'setelah akun diaktifkan.'
                          : 'Registration successful. Admin is processing your '
                            'account activation. You can use SiAbsen once '
                            'your account is activated.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Card Email ───────────────────────────────────────
                    _InfoCard(
                      icon: Icons.email_outlined,
                      iconColor: const Color(0xFF3B82F6),
                      bgColor: const Color(0xFFEFF6FF),
                      title: lang == 'id' ? 'Email Terdaftar' : 'Registered Email',
                      value: email,
                    ),
                    const SizedBox(height: 12),

                    // ── Card Status ──────────────────────────────────────
                    _InfoCard(
                      icon: Icons.pending_actions_outlined,
                      iconColor: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                      title: lang == 'id' ? 'Status Akun' : 'Account Status',
                      value: Tr.get('waiting_approval', lang),
                      valueColor: const Color(0xFFD97706),
                    ),
                    const SizedBox(height: 28),

                    // ── Langkah-langkah ──────────────────────────────────
                    _StepsCard(lang: lang),
                    const SizedBox(height: 28),

                    // ── Tombol Cek Status ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isRefreshing ? null : _refresh,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          disabledBackgroundColor:
                              const Color(0xFF1D4ED8).withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded,
                                color: Colors.white),
                        label: Text(
                          _isRefreshing
                              ? (lang == 'id' ? 'Memeriksa status...' : 'Checking status...')
                              : (lang == 'id' ? 'Cek Status Akun' : 'Check Account Status'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Tombol Logout ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.logout_rounded,
                            color: AppColors.textSecondary, size: 18),
                        label: Text(
                          Tr.get('logout', lang),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Catatan kecil ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            lang == 'id'
                                ? 'Proses aktivasi biasanya memakan waktu 1×24 jam.'
                                : 'Activation usually takes up to 24 hours.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget: Info Card ─────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String value;
  final Color? valueColor;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget: Steps Card ────────────────────────────────────────────────────────

class _StepsCard extends StatelessWidget {
  final String lang;
  const _StepsCard({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded,
                  size: 18, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              Text(
                lang == 'id' ? 'Proses Aktivasi Akun' : 'Account Activation Process',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StepItem(
            step: '1',
            isCompleted: true,
            title: lang == 'id' ? 'Registrasi berhasil' : 'Registration successful',
            subtitle: lang == 'id'
                ? 'Data Anda telah tersimpan di sistem'
                : 'Your data has been saved in the system',
          ),
          _StepItem(
            step: '2',
            isActive: true,
            title: lang == 'id' ? 'Menunggu persetujuan admin' : 'Waiting for admin approval',
            subtitle: lang == 'id'
                ? 'Admin akan meninjau dan mengaktifkan akun Anda'
                : 'Admin will review and activate your account',
          ),
          _StepItem(
            step: '3',
            title: lang == 'id' ? 'Akun diaktifkan' : 'Account activated',
            subtitle: lang == 'id'
                ? 'Anda dapat login dan menggunakan semua fitur'
                : 'You can sign in and use all features',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;
  final bool isLast;

  const _StepItem({
    required this.step,
    required this.title,
    required this.subtitle,
    this.isCompleted = false,
    this.isActive = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Widget dotChild;

    if (isCompleted) {
      dotColor = const Color(0xFF22C55E);
      dotChild = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isActive) {
      dotColor = const Color(0xFF3B82F6);
      dotChild = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    } else {
      dotColor = const Color(0xFFCBD5E1);
      dotChild = Text(
        step,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Dot + Line ───────────────────────────────────────────────────
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
              child: Center(child: dotChild),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted
                    ? const Color(0xFF22C55E).withOpacity(0.3)
                    : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),

        // ── Text ─────────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: 4,
              bottom: isLast ? 0 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: (isCompleted || isActive)
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: (isCompleted || isActive)
                        ? Colors.grey.shade500
                        : const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
