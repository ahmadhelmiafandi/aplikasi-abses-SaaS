import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/services/biometric_service.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  bool  _obscurePass   = true;

  // ── Biometric state ──────────────────────────────────────────────────────
  bool _biometricAvailable = false;
  bool _biometricEnabled   = false;
  bool _biometricLoading   = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    if (kIsWeb) return;
    final available = await BiometricService.isAvailable();
    final enabled   = await BiometricService.isEnabled();

    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled   = enabled && available;
    });

    // Jika biometrik sudah diaktifkan → auto-trigger prompt saat buka app
    if (_biometricEnabled) {
      _loginWithBiometric(autoTrigger: true);
    }
  }

  // ── Login dengan email/password ──────────────────────────────────────────

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _doLogin(_emailCtrl.text.trim(), _passwordCtrl.text);
  }

  Future<void> _doLogin(String email, String password,
      {bool saveBiometric = false}) async {
    await ref.read(authProvider.notifier).login(email, password);

    // Jika login berhasil dan diminta simpan biometrik
    if (saveBiometric && ref.read(authProvider).status == AuthStatus.authenticated) {
      await BiometricService.saveCredentials(
          email: email, password: password);
      setState(() => _biometricEnabled = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Tr.get('biometric_enabled_msg',
              ref.read(langProvider))),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    }
  }

  // ── Login dengan biometrik ───────────────────────────────────────────────

  Future<void> _loginWithBiometric({bool autoTrigger = false}) async {
    if (!_biometricAvailable || !_biometricEnabled) return;

    setState(() => _biometricLoading = true);
    try {
      final lang = ref.read(langProvider);
      final authenticated = await BiometricService.authenticate(
        reason: Tr.get('biometric_reason', lang),
      );

      if (!authenticated) {
        if (!autoTrigger && mounted) {
          _showSnack(Tr.get('biometric_failed', lang), isError: true);
        }
        return;
      }

      final email    = await BiometricService.getSavedEmail();
      final password = await BiometricService.getSavedPassword();

      if (email == null || password == null) {
        if (mounted) _showSnack(Tr.get('biometric_failed', lang), isError: true);
        return;
      }

      await _doLogin(email, password);
    } finally {
      if (mounted) setState(() => _biometricLoading = false);
    }
  }

  // ── Aktifkan biometrik setelah login manual berhasil ────────────────────

  Future<void> _promptEnableBiometric() async {
    final lang = ref.read(langProvider);
    if (!_biometricAvailable || _biometricEnabled) return;
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;

    final label = await BiometricService.getBiometricLabel(lang: lang);

    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang == 'id'
            ? 'Aktifkan $label?'
            : 'Enable $label?'),
        content: Text(lang == 'id'
            ? 'Login lebih cepat di lain waktu dengan $label.'
            : 'Sign in faster next time using $label.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Tr.get('cancel', lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang == 'id' ? 'Aktifkan' : 'Enable'),
          ),
        ],
      ),
    );

    if (enable == true && mounted) {
      await _doLogin(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        saveBiometric: true,
      );
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _showForgotPasswordDialog() {
    final lang = ref.read(langProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            lang == 'id' ? 'Reset Password' : 'Reset Password',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF141B41),
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == 'id'
                      ? 'Masukkan email Anda untuk menerima tautan reset password.'
                      : 'Enter your email to receive a password reset link.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black),
                  decoration: _inputDecor(
                    Tr.get('email', lang),
                    Icons.email_outlined,
                    isDark,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return lang == 'id' ? 'Email wajib diisi' : 'Email is required';
                    }
                    if (!v.contains('@')) {
                      return lang == 'id' ? 'Format email tidak valid' : 'Invalid email format';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: Text(Tr.get('cancel', lang)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => loading = true);
                      final error = await ref
                          .read(authProvider.notifier)
                          .sendPasswordResetEmail(emailController.text.trim());
                      setDialogState(() => loading = false);
                      if (mounted) {
                        Navigator.pop(ctx);
                        if (error == null) {
                          _showSnack(
                            lang == 'id'
                                ? 'Email reset password telah dikirim.'
                                : 'Password reset email has been sent.',
                          );
                        } else {
                          _showSnack(error, isError: true);
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(lang == 'id' ? 'Kirim' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDemoDialog(String lang, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF3B82F6), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang == 'id' ? 'Pilih Mode Demo' : 'Select Demo Mode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'id'
                  ? 'Pilih peran di bawah ini untuk mencoba seluruh fitur secara instan 1-klik:'
                  : 'Select a role below to test all features instantly with 1-click:',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            _DemoRoleTile(
              icon: Icons.person_rounded,
              iconColor: const Color(0xFF22C55E),
              title: lang == 'id' ? 'Demo Karyawan' : 'Employee Demo',
              subtitle: lang == 'id'
                  ? 'Check-In GPS, Scan QR Code & Pengajuan Izin'
                  : 'GPS Check-In, QR Scan & Leave Requests',
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                _emailCtrl.text = 'karyawan@interia.com';
                _passwordCtrl.text = '123456';
                _doLogin('karyawan@interia.com', '123456');
              },
            ),
            const SizedBox(height: 10),
            _DemoRoleTile(
              icon: Icons.business_center_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: lang == 'id' ? 'Demo Admin Perusahaan / HRD' : 'Company Admin Demo',
              subtitle: lang == 'id'
                  ? 'Kelola karyawan, persetujuan izin & lokasi kantor'
                  : 'Manage employees, leave approvals & geofencing',
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                _emailCtrl.text = 'admin@interia.com';
                _passwordCtrl.text = '123456';
                _doLogin('admin@interia.com', '123456');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              Tr.get('cancel', lang),
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark    = ref.watch(darkModeProvider);
    final lang      = ref.watch(langProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Responsive Background Gradient ───────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [
                          Color(0xFF0B0F19),
                          Color(0xFF0F172A),
                          Color(0xFF1E293B),
                        ]
                      : const [
                          Color(0xFFF8FAFC),
                          Color(0xFFEFF6FF),
                          Color(0xFFE2E8F0),
                        ],
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top bar — language & dark mode
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16, left: 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () =>
                              ref.read(langProvider.notifier).toggle(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.25)
                                      : AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Text(
                              lang.toUpperCase(),
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TopBarBtn(
                          icon: isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          onTap: () =>
                              ref.read(darkModeProvider.notifier).toggle(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main content with ScrollView
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        // Logo
                        Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/logo.jpg',
                              width: 100, height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          Tr.get('welcome_back', lang),
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Tr.get('app_subtitle', lang),
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withOpacity(0.65)
                                : const Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Banner Onboarding SaaS Perusahaan Baru (UX Call to Action) ──
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1D4ED8).withOpacity(isDark ? 0.4 : 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.domain_add_rounded,
                                        color: Colors.white, size: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lang == 'id'
                                              ? 'Ingin Daftarkan Perusahaan Anda?'
                                              : 'Want to Register Your Company?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          lang == 'id'
                                              ? 'Dapatkan Token Kode instan untuk karyawan Anda'
                                              : 'Get instant Token Code for all employees',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.85),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1D4ED8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => context.push('/register-tenant'),
                                  icon: const Icon(Icons.add_business_rounded,
                                      size: 18, color: Color(0xFF1D4ED8)),
                                  label: Text(
                                    lang == 'id'
                                        ? 'Daftar Perusahaan Baru (SaaS Tenant)'
                                        : 'Register New Company (SaaS)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Card Login & Register Karyawan ───────────────────
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                // Email
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType:
                                      TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                  decoration: _inputDecor(
                                    Tr.get('email', lang),
                                    Icons.email_outlined,
                                    isDark,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return lang == 'id'
                                          ? 'Email tidak boleh kosong'
                                          : 'Email is required';
                                    }
                                    if (!v.contains('@')) {
                                      return lang == 'id'
                                          ? 'Format email tidak valid'
                                          : 'Invalid email format';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Password
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePass,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                  decoration: _inputDecor(
                                    Tr.get('password', lang),
                                    Icons.lock_outline,
                                    isDark,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscurePass
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePass = !_obscurePass),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty)
                                          ? (lang == 'id'
                                              ? 'Password tidak boleh kosong'
                                              : 'Password is required')
                                          : null,
                                ),
                                 const SizedBox(height: 8),
                                 Align(
                                   alignment: Alignment.centerRight,
                                   child: TextButton(
                                     onPressed: _showForgotPasswordDialog,
                                     style: TextButton.styleFrom(
                                       padding: EdgeInsets.zero,
                                       minimumSize: Size.zero,
                                       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                     ),
                                     child: Text(
                                       lang == 'id' ? 'Lupa Password?' : 'Forgot Password?',
                                       style: const TextStyle(
                                         color: AppColors.primary,
                                         fontSize: 13,
                                         fontWeight: FontWeight.w600,
                                       ),
                                     ),
                                   ),
                                 ),
                                 const SizedBox(height: 16),

                                // Error
                                if (authState.error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.dangerLight,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppColors.danger
                                              .withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: AppColors.danger,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            authState.error!,
                                            style: const TextStyle(
                                              color: AppColors.danger,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // ── Sign In button ─────────────────────
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 22, width: 22,
                                            child:
                                                CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            Tr.get('sign_in', lang),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),

                                // ── Biometric button ───────────────────
                                if (!kIsWeb &&
                                    _biometricAvailable) ...[
                                  const SizedBox(height: 12),
                                  _BiometricButton(
                                    enabled: _biometricEnabled,
                                    loading: _biometricLoading,
                                    lang: lang,
                                    isDark: isDark,
                                    onTap: _biometricEnabled
                                        ? () => _loginWithBiometric()
                                        : _promptEnableBiometric,
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // ── Pilihan Pendaftaran (Karyawan vs Tenant Baru) ──
                                Column(
                                  children: [
                                    // 🚀 Tombol Demo Aplikasi Instan
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showDemoDialog(lang, isDark),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF38BDF8)
                                                : const Color(0xFF0284C7),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          backgroundColor: isDark
                                              ? const Color(0xFF38BDF8).withOpacity(0.08)
                                              : const Color(0xFF0284C7).withOpacity(0.06),
                                        ),
                                        icon: const Icon(
                                          Icons.rocket_launch_rounded,
                                          size: 18,
                                          color: Color(0xFF0284C7),
                                        ),
                                        label: Text(
                                          lang == 'id'
                                              ? 'Coba Demo Aplikasi (Tanpa Daftar)'
                                              : 'Try App Demo (Instant Test)',
                                          style: TextStyle(
                                            color: isDark
                                                ? const Color(0xFF38BDF8)
                                                : const Color(0xFF0284C7),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    const SizedBox(height: 16),

                                    // ── Dua Tombol Pendaftaran Simetris & Rapi ──
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => context.push('/register'),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              side: BorderSide(
                                                color: isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFCBD5E1),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            icon: const Icon(Icons.person_add_outlined, size: 16),
                                            label: Text(
                                              lang == 'id' ? 'Daftar Karyawan' : 'Register Employee',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => context.push('/register-tenant'),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              backgroundColor: const Color(0xFF1D4ED8),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            icon: const Icon(Icons.domain_add_rounded,
                                                size: 16, color: Colors.white),
                                            label: Text(
                                              lang == 'id' ? 'Daftar Perusahaan' : 'Register Company',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
  }

  InputDecoration _inputDecor(String label, IconData icon, bool isDark,
      {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
      floatingLabelStyle: TextStyle(
        color: isDark ? AppColors.accent : AppColors.primary,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        size: 20,
      ),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.accent : AppColors.primary,
          width: 2,
        ),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : AppColors.surfaceAlt,
    );
  }
}

// ── Biometric Button ──────────────────────────────────────────────────────────
class _BiometricButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final String lang;
  final bool isDark;
  final VoidCallback onTap;

  const _BiometricButton({
    required this.enabled,
    required this.loading,
    required this.lang,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = enabled
        ? Tr.get('biometric_login', lang)
        : Tr.get('biometric_enable', lang);

    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(
                enabled ? Icons.fingerprint : Icons.fingerprint_outlined,
                size: 22,
                color: AppColors.primary,
              ),
        label: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: AppColors.primary.withOpacity(0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppColors.primary.withOpacity(0.06),
        ),
      ),
    );
  }
}

// ── Top Bar Button ────────────────────────────────────────────────────────────
class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  const _TopBarBtn(
      {required this.icon, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.25)
                  : AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fgColor, size: 16),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Demo Role Tile Widget ───────────────────────────────────────────────────
class _DemoRoleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _DemoRoleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
