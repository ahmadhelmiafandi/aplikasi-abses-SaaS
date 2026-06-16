import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/biometric_service.dart';
import '../../auth/presentation/auth_provider.dart';

final profileProvider = FutureProvider.autoDispose((ref) async {
  return await SupabaseService.getProfile();
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _namaCtrl  = TextEditingController();
  final _hpCtrl    = TextEditingController();
  final _alamatCtrl = TextEditingController();
  bool _isEditing  = false;
  bool _isLoading  = false;

  // Biometric state
  bool _biometricAvailable = false;
  bool _biometricEnabled   = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    if (kIsWeb) return;
    final available = await BiometricService.isAvailable();
    final enabled   = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled   = enabled && available;
      });
    }
  }

  Future<void> _toggleBiometric(bool newValue, String lang) async {
    if (newValue) {
      // Aktifkan: minta autentikasi dulu baru simpan
      final ok = await BiometricService.authenticate(
        reason: Tr.get('biometric_reason', lang),
      );
      if (!ok) return;
      // Kredensial sudah tersimpan dari saat login — cukup tandai enabled
      final email = await BiometricService.getSavedEmail();
      if (email == null) {
        // Belum pernah login dengan biometrik — minta user login ulang
        if (mounted) {
          _snack(
            lang == 'id'
                ? 'Silakan login ulang untuk mengaktifkan biometrik'
                : 'Please sign in again to enable biometrics',
            isError: true,
          );
        }
        return;
      }
      await BiometricService.saveCredentials(
        email: email,
        password: await BiometricService.getSavedPassword() ?? '',
      );
      setState(() => _biometricEnabled = true);
      if (mounted) _snack(Tr.get('biometric_enabled_msg', lang));
    } else {
      // Nonaktifkan
      await BiometricService.clearCredentials();
      setState(() => _biometricEnabled = false);
      if (mounted) _snack(Tr.get('biometric_disabled_msg', lang));
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hpCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> data) {
    if (!_isEditing) {
      _namaCtrl.text  = data['nama']     ?? '';
      _hpCtrl.text    = data['nomor_hp'] ?? '';
      _alamatCtrl.text = data['alamat']  ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateProfile(
        nama:     _namaCtrl.text.trim(),
        nomorHp:  _hpCtrl.text.trim(),
        alamat:   _alamatCtrl.text.trim(),
      );
      ref.invalidate(profileProvider);
      ref.read(authProvider.notifier).updateCachedUser({
        'nama':     _namaCtrl.text.trim(),
        'nomor_hp': _hpCtrl.text.trim(),
        'alamat':   _alamatCtrl.text.trim(),
      });
      setState(() => _isEditing = false);
      if (mounted) _snack(Tr.get('profile_updated', ref.read(langProvider)));
    } catch (e) {
      if (mounted) _snack('Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
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
    final lang        = ref.watch(langProvider);
    final profileAsync = ref.watch(profileProvider);
    final isDark      = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.get('profile', lang)),
        actions: [
          if (!_isEditing)
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(Tr.get('edit_profile', lang)),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: Text(Tr.get('cancel', lang)),
              onPressed: () => setState(() => _isEditing = false),
            ),
        ],
      ),
      body: profileAsync.when(
        data: (data) {
          _populate(data);
          final dept = (data['departemen'] as Map?)?.cast<String, dynamic>();
          return SingleChildScrollView(
            child: Column(
              children: [
                // ── Hero Section ─────────────────────────────────────────
                _ProfileHero(data: data, deptName: dept?['nama_departemen']),

                // ── Form ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionLabel(label: Tr.get('personal_info', lang)),
                          const SizedBox(height: 14),

                          _FormField(
                            ctrl:    _namaCtrl,
                            label:   Tr.get('full_name', lang),
                            icon:    Icons.person_outline,
                            enabled: _isEditing,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nama wajib diisi' : null,
                          ),
                          const SizedBox(height: 12),
                          _FormField(
                            ctrl:    _hpCtrl,
                            label:   Tr.get('phone', lang),
                            icon:    Icons.phone_outlined,
                            enabled: _isEditing,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _FormField(
                            ctrl:    _alamatCtrl,
                            label:   Tr.get('address', lang),
                            icon:    Icons.location_on_outlined,
                            enabled: _isEditing,
                            maxLines: 3,
                          ),

                          // Email (read only)
                          const SizedBox(height: 12),
                          _ReadOnlyField(
                            label: Tr.get('email', lang),
                            value: data['email'] ?? '',
                            icon: Icons.email_outlined,
                          ),

                          // Save button
                          if (_isEditing) ...[
                            const SizedBox(height: 20),
                            LoadingButton(
                              label: Tr.get('save_changes', lang),
                              onPressed: _save,
                              isLoading: _isLoading,
                              icon: Icons.save_outlined,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Security Section ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionLabel(label: Tr.get('security', lang)),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Builder(builder: (ctx) {
                            final dark = Theme.of(ctx).brightness == Brightness.dark;
                            return Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: dark
                                    ? AppColors.darkPrimaryTint
                                    : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.lock_outline,
                                  color: AppColors.primary, size: 20),
                            );
                          }),
                          title: Text(Tr.get('change_password', lang),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(Tr.get('change_password_sub', lang),
                              style: const TextStyle(fontSize: 12,
                                  color: AppColors.textSecondary)),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.textSecondary),
                          onTap: () => _showChangePasswordDialog(context, lang),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Dark Mode & Lang toggle ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionLabel(label: Tr.get('settings', lang)),
                        const SizedBox(height: 12),
                        _SettingTile(
                          icon: Icons.dark_mode_outlined,
                          title: Tr.get('dark_mode', lang),
                          trailing: Consumer(
                            builder: (ctx, r, _) {
                              final dark = r.watch(darkModeProvider);
                              return Switch(
                                value: dark,
                                onChanged: (_) =>
                                    r.read(darkModeProvider.notifier).toggle(),
                                activeColor: AppColors.primary,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SettingTile(
                          icon: Icons.language,
                          title: Tr.get('language', lang),
                          trailing: Consumer(
                            builder: (ctx, r, _) {
                              final l = r.watch(langProvider);
                              return TextButton(
                                onPressed: () =>
                                    r.read(langProvider.notifier).toggle(),
                                child: Text(
                                  l == 'id' ? 'Bahasa Indonesia' : 'English',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              );
                            },
                          ),
                        ),
                        // ── Biometric toggle ──────────────────────────
                        if (!kIsWeb && _biometricAvailable) ...[
                          const SizedBox(height: 8),
                          _SettingTile(
                            icon: Icons.fingerprint,
                            title: _biometricEnabled
                                ? Tr.get('biometric_disable', lang)
                                : Tr.get('biometric_enable', lang),
                            trailing: Switch(
                              value: _biometricEnabled,
                              onChanged: (v) =>
                                  _toggleBiometric(v, lang),
                              activeColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => ErrorState(
          message: Tr.get('profile_load_error', ref.read(langProvider)),
          onRetry: () => ref.invalidate(profileProvider),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, String lang) {
    final oldCtrl  = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    final fKey     = GlobalKey<FormState>();
    bool loading   = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateBS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Form(
              key: fKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.lock_outline, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(Tr.get('change_password', lang),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 16),
                  _PassField(ctrl: oldCtrl,  label: Tr.get('old_password', lang)),
                  const SizedBox(height: 10),
                  _PassField(ctrl: newCtrl,  label: Tr.get('new_password', lang),
                    validator: (v) => (v == null || v.length < 6)
                        ? Tr.get('min_6_chars', lang) : null),
                  const SizedBox(height: 10),
                  _PassField(ctrl: confCtrl, label: Tr.get('confirm_new_pass', lang),
                    validator: (v) => v != newCtrl.text
                        ? Tr.get('password_mismatch', lang) : null),
                  const SizedBox(height: 16),
                  LoadingButton(
                    label: Tr.get('save_changes', lang),
                    isLoading: loading,
                    onPressed: () async {
                      if (!fKey.currentState!.validate()) return;
                      setStateBS(() => loading = true);
                      try {
                        await SupabaseService.changePassword(
                          oldPassword: oldCtrl.text,
                          newPassword: newCtrl.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _snack(Tr.get('password_changed', lang));
                      } catch (e) {
                        final msg = e.toString().toLowerCase();
                        if (msg.contains('invalid') || msg.contains('wrong') || msg.contains('credentials')) {
                          _snack(Tr.get('wrong_old_password', lang), isError: true);
                        } else {
                          _snack('${Tr.get("error", lang)}: $e', isError: true);
                        }
                      } finally {
                        setStateBS(() => loading = false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero section ──────────────────────────────────────────────────────────────
class _ProfileHero extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? deptName;
  const _ProfileHero({required this.data, this.deptName});

  @override
  Widget build(BuildContext context) {
    final nama  = data['nama']?.toString() ?? 'U';
    final email = data['email']?.toString() ?? '';
    final role  = data['role']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white.withOpacity(0.15),
                child: Text(
                  nama.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(nama,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(email,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65), fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoleBadge(role: role),
              if (deptName != null && deptName!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(deptName!,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool enabled;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark
                  ? AppColors.darkBorder.withOpacity(0.5)
                  : AppColors.border.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: enabled
            ? (isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt)
            : (isDark
                ? AppColors.darkSurfaceAlt.withOpacity(0.4)
                : AppColors.surfaceAlt.withOpacity(0.6)),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceAlt.withOpacity(0.4)
            : AppColors.surfaceAlt.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? AppColors.darkBorder.withOpacity(0.5)
                : AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary)),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPrimaryTint : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        trailing,
      ],
    );
  }
}

class _PassField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final String? Function(String?)? validator;
  const _PassField({required this.ctrl, required this.label, this.validator});

  @override
  State<_PassField> createState() => _PassFieldState();
}

class _PassFieldState extends State<_PassField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: widget.ctrl,
      obscureText: _obscure,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(Icons.lock_outline,
            size: 18,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
      ),
    );
  }
}
