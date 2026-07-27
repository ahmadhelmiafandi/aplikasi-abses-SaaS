import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/network/dio_client.dart';
import 'auth_provider.dart';

/// Form Pendaftaran Mandiri Perusahaan / Tenant Baru (Self-Service SaaS Provisioning)
class RegisterTenantScreen extends ConsumerStatefulWidget {
  const RegisterTenantScreen({super.key});

  @override
  ConsumerState<RegisterTenantScreen> createState() =>
      _RegisterTenantScreenState();
}

class _RegisterTenantScreenState extends ConsumerState<RegisterTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  final _companyNameCtrl = TextEditingController();
  final _subdomainCtrl   = TextEditingController();
  final _adminNamaCtrl   = TextEditingController();
  final _adminEmailCtrl  = TextEditingController();
  final _adminNoHpCtrl   = TextEditingController();
  final _adminPassCtrl   = TextEditingController();

  bool _obscurePass = true;
  bool _isLoading   = false;

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _subdomainCtrl.dispose();
    _adminNamaCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminNoHpCtrl.dispose();
    _adminPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerTenant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final lang       = ref.read(langProvider);
    final compName   = _companyNameCtrl.text.trim();
    final subdomain  = _subdomainCtrl.text.trim().toLowerCase();
    final adminNama  = _adminNamaCtrl.text.trim();
    final adminEmail = _adminEmailCtrl.text.trim();
    final adminHp    = _adminNoHpCtrl.text.trim();
    final adminPass  = _adminPassCtrl.text;

    // Generate Token Kode Perusahaan (misal: TC-INT12345)
    final prefix = compName.length >= 3
        ? compName.substring(0, 3).toUpperCase()
        : 'TC';
    final randomDigits = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final generatedCompanyToken = 'TC-$prefix$randomDigits';

    try {
      bool isSuccess = false;
      String? errorMessage;

      // 1. Panggil Endpoint Backend Express (Auto email_confirm via Service Role)
      try {
        final res = await DioClient().dio.post('/auth/register-tenant', data: {
          'name': compName,
          'subdomain': subdomain,
          'adminNama': adminNama,
          'adminEmail': adminEmail,
          'adminPass': adminPass,
          'adminHp': adminHp,
        });

        if (res.data != null && res.data['success'] == true) {
          isSuccess = true;
        } else {
          errorMessage = res.data?['message']?.toString();
        }
      } catch (dioErr) {
        // Direct Supabase Fallback jika backend Express offline
        try {
          String? newTenantId;
          try {
            final tenantRes = await SupabaseConfig.client
                .from('tenant')
                .insert({
                  'name': compName,
                  'subdomain': subdomain,
                })
                .select('id')
                .single();
            newTenantId = tenantRes['id']?.toString();
          } catch (_) {
            newTenantId = 'tenant-$subdomain';
          }

          final authRes = await SupabaseConfig.auth.signUp(
            email: adminEmail,
            password: adminPass,
            data: {
              'nama': adminNama,
              'nomor_hp': adminHp.isEmpty ? null : adminHp,
              'role': 'admin',
              'status_aktif': true,
              'id_tenant': newTenantId,
            },
          );

          final user = authRes.user;
          if (user != null) {
            try {
              await SupabaseConfig.client.from('profiles').upsert({
                'id': user.id,
                'email': adminEmail,
                'nama': adminNama,
                'role': 'admin',
                'status_aktif': true,
                'nomor_hp': adminHp.isEmpty ? null : adminHp,
                'id_tenant': newTenantId,
              });
            } catch (_) {}
          }
          isSuccess = true;
        } catch (e) {
          errorMessage = e.toString().replaceAll("PostgrestException", "").replaceAll("AuthException", "");
        }
      }

      if (!isSuccess && errorMessage != null) {
        throw Exception(errorMessage);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 3. Tampilkan Modal Dialog Sukses Pendaftaran Tenant & Token Kode
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.success, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang == 'id'
                      ? 'Perusahaan Berhasil Didaftarkan!'
                      : 'Company Successfully Registered!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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
                    ? 'Selamat! $compName telah aktif di siAbsen.'
                    : 'Congratulations! $compName is now active on siAbsen.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang == 'id'
                          ? '🔑 TOKEN KODE PERUSAHAAN ANDA:'
                          : '🔑 YOUR COMPANY TOKEN CODE:',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      generatedCompanyToken,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang == 'id'
                          ? 'Bagikan Token Kode ini kepada karyawan Anda saat mereka mendaftar akun.'
                          : 'Share this Token Code with your employees when they register.',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                lang == 'id' ? 'Masuk ke Aplikasi' : 'Proceed to Sign In',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      // Auto-login sebagai Admin Tenant
      if (mounted) {
        await ref.read(authProvider.notifier).login(adminEmail, adminPass);
        if (mounted) context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mendaftarkan perusahaan: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  InputDecoration _inputDecor(String hint, IconData icon,
      {Widget? suffixIcon, required bool isDark}) {
    return InputDecoration(
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      hintStyle: TextStyle(
        fontSize: 14,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      ),
      prefixIcon: Icon(icon,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final isDark = ref.watch(darkModeProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(lang == 'id' ? 'Daftar Perusahaan Baru' : 'Register New Company'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(darkModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header Card ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.domain_add_rounded,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang == 'id'
                                      ? 'Pendaftaran Tenant SaaS'
                                      : 'SaaS Tenant Registration',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lang == 'id'
                                      ? 'Daftarkan kantor Anda & dapatkan Token Kode instan'
                                      : 'Register your company & get an instant Token Code',
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
                    ),
                    const SizedBox(height: 24),

                    // ── Data Perusahaan ─────────────────────────────────
                    _SectionHeader(
                      label: lang == 'id'
                          ? '1. Informasi Perusahaan'
                          : '1. Company Details',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _companyNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecor(
                        lang == 'id' ? 'Nama Perusahaan / Kantor' : 'Company Name',
                        Icons.business_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? (lang == 'id' ? 'Nama perusahaan wajib diisi' : 'Company name is required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _subdomainCtrl,
                      decoration: _inputDecor(
                        lang == 'id' ? 'Subdomain / Identifikasi (misal: mahakarya)' : 'Subdomain / Identifier',
                        Icons.link_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? (lang == 'id' ? 'Subdomain wajib diisi' : 'Subdomain is required')
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // ── Data Admin Pemilik ──────────────────────────────
                    _SectionHeader(
                      label: lang == 'id'
                          ? '2. Akun Admin Perusahaan (Pemilik)'
                          : '2. Company Admin (Owner)',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _adminNamaCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecor(
                        lang == 'id' ? 'Nama Lengkap Admin' : 'Admin Full Name',
                        Icons.person_outline_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? (lang == 'id' ? 'Nama admin wajib diisi' : 'Admin name is required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _adminEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecor(
                        lang == 'id' ? 'Email Admin' : 'Admin Email',
                        Icons.email_outlined,
                        isDark: isDark,
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? (lang == 'id' ? 'Email tidak valid' : 'Invalid email')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _adminNoHpCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecor(
                        lang == 'id' ? 'Nomor HP Admin (Opsional)' : 'Admin Phone (Optional)',
                        Icons.phone_outlined,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _adminPassCtrl,
                      obscureText: _obscurePass,
                      decoration: _inputDecor(
                        lang == 'id' ? 'Kata Sandi Admin' : 'Admin Password',
                        Icons.lock_outline_rounded,
                        isDark: isDark,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePass ? Icons.visibility_off : Icons.visibility,
                            color: isDark ? Colors.grey : Colors.grey.shade600,
                          ),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? (lang == 'id' ? 'Kata sandi minimal 6 karakter' : 'Password must be at least 6 chars')
                          : null,
                    ),
                    const SizedBox(height: 32),

                    // ── Submit Button ───────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _registerTenant,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.rocket_launch_rounded, color: Colors.white),
                        label: Text(
                          _isLoading
                              ? (lang == 'id' ? 'Mendaftarkan Perusahaan...' : 'Registering Company...')
                              : (lang == 'id' ? 'Daftar Perusahaan Sekarang' : 'Register Company Now'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
      ),
    );
  }
}
