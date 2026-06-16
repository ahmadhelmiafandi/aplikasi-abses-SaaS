import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../presentation/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _namaCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _noHpCtrl        = TextEditingController();
  final _alamatCtrl      = TextEditingController();
  final _passCtrl        = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _isLoading     = false;
  bool _obscurePass   = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _noHpCtrl.dispose();
    _alamatCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final lang = ref.read(langProvider);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final error = await ref.read(authProvider.notifier).register(
          nama: _namaCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          nomorHp: _noHpCtrl.text.trim().isEmpty ? null : _noHpCtrl.text.trim(),
          alamat: _alamatCtrl.text.trim().isEmpty ? null : _alamatCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.danger),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(lang == 'id' ? 'Registrasi Berhasil' : 'Registration Successful'),
          ],
        ),
        content: Text(
          lang == 'id'
              ? 'Akun Anda telah dibuat dan sedang menunggu persetujuan admin. '
                'Anda akan bisa login setelah akun diaktifkan.'
              : 'Your account has been created and is awaiting admin approval. '
                'You will be able to sign in once your account is activated.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(lang == 'id' ? 'Kembali ke Login' : 'Back to Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang   = ref.watch(langProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F6FC),
      appBar: AppBar(
        title: Text(lang == 'id' ? 'Registrasi Akun' : 'Create Account'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.0 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ───────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkPrimaryTint
                            : const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_outlined,
                          size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      lang == 'id' ? 'Daftar Akun Baru' : 'Create New Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF141B41)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang == 'id'
                          ? 'Akun akan diverifikasi oleh Admin sebelum aktif'
                          : 'Account will be verified by Admin before activation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF64748B),
                          fontSize: 13),
                    ),
                    const SizedBox(height: 28),

                    // ── Info box ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkWarningTint
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.warning.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 18, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang == 'id'
                                  ? 'Setelah daftar, tunggu admin mengaktifkan akun Anda sebelum bisa login.'
                                  : 'After registering, wait for admin to activate your account before signing in.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.warning
                                      : const Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Informasi Pribadi ─────────────────────────────────
                    _SectionLabel(
                        label: Tr.get('personal_info', lang),
                        isDark: isDark),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _namaCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecor(
                          Tr.get('full_name', lang),
                          Icons.person_outline,
                          isDark: isDark),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? Tr.get('name_required', lang)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecor(
                          Tr.get('email', lang),
                          Icons.email_outlined,
                          isDark: isDark),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return lang == 'id'
                              ? 'Email wajib diisi'
                              : 'Email is required';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return lang == 'id'
                              ? 'Email tidak valid'
                              : 'Invalid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _noHpCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecor(
                          Tr.get('phone', lang),
                          Icons.phone_outlined,
                          isDark: isDark),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _alamatCtrl,
                      maxLines: 2,
                      decoration: _inputDecor(
                          Tr.get('address', lang),
                          Icons.location_on_outlined,
                          isDark: isDark),
                    ),
                    const SizedBox(height: 24),

                    // ── Keamanan Akun ─────────────────────────────────────
                    _SectionLabel(
                        label: lang == 'id' ? 'Keamanan Akun' : 'Account Security',
                        isDark: isDark),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: _inputDecor(
                        Tr.get('password', lang),
                        Icons.lock_outline,
                        isDark: isDark,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass
                              ? Icons.visibility_off
                              : Icons.visibility,
                              color: AppColors.textSecondary),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? Tr.get('min_6_chars', lang)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passConfirmCtrl,
                      obscureText: _obscureConfirm,
                      decoration: _inputDecor(
                        Tr.get('confirm_password', lang),
                        Icons.lock_outline,
                        isDark: isDark,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                              color: AppColors.textSecondary),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) => v != _passCtrl.text
                          ? Tr.get('password_mismatch', lang)
                          : null,
                    ),
                    const SizedBox(height: 32),

                    // ── Submit ────────────────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22, width: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                Tr.get('register_now', lang),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                      ),
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

  InputDecoration _inputDecor(String label, IconData icon,
      {Widget? suffixIcon, required bool isDark}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          size: 20),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      filled: true,
      fillColor: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextSecondary
                : const Color(0xFF475569),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
              thickness: 1),
        ),
      ],
    );
  }
}
