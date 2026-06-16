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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E3A8A),
              Color(0xFF1D4ED8),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Top bar — language & dark mode ──────────────────────
              Positioned(
                top: 8, right: 16,
                child: Row(
                  children: [
                    _TopBarBtn(
                      icon: Icons.language,
                      label: lang == 'id' ? 'EN' : 'ID',
                      onTap: () =>
                          ref.read(langProvider.notifier).toggle(),
                    ),
                    const SizedBox(width: 8),
                    _TopBarBtn(
                      icon: isDark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                      onTap: () =>
                          ref.read(darkModeProvider.notifier).toggle(),
                    ),
                  ],
                ),
              ),

              // ── Main content ─────────────────────────────────────────
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
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
                                color: Colors.black.withOpacity(0.3),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Tr.get('app_subtitle', lang),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ── Card ───────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
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
                                  decoration: _inputDecor(
                                    Tr.get('email', lang),
                                    Icons.email_outlined,
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
                                  decoration: _inputDecor(
                                    Tr.get('password', lang),
                                    Icons.lock_outline,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscurePass
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: AppColors.textSecondary,
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
                                const SizedBox(height: 24),

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

                                // Register link
                                TextButton(
                                  onPressed: () =>
                                      context.push('/register'),
                                  child: Text(
                                    Tr.get('no_account', lang),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String label, IconData icon,
      {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon:
          Icon(icon, color: AppColors.textSecondary, size: 20),
      suffixIcon: suffix,
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 2),
      ),
      filled: true,
      fillColor: AppColors.surfaceAlt,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
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
