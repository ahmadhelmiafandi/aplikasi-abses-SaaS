import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';

final usersProvider = FutureProvider.autoDispose((ref) async {
  return await SupabaseService.getAllUsers();
});

class KelolaKaryawanScreen extends ConsumerStatefulWidget {
  const KelolaKaryawanScreen({super.key});
  @override
  ConsumerState<KelolaKaryawanScreen> createState() =>
      _KelolaKaryawanScreenState();
}

class _KelolaKaryawanScreenState extends ConsumerState<KelolaKaryawanScreen> {
  String _search = '';
  String _filter = 'semua'; // semua | aktif | nonaktif

  @override
  Widget build(BuildContext context) {
    final lang      = ref.watch(langProvider);
    final usersAsync = ref.watch(usersProvider);
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.get('manage_accounts', lang)),
      ),
      body: Column(
        children: [
          // ── Search ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: Tr.get('search_employee', lang),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor:
                    isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
              ),
            ),
          ),

          // ── Filter chips ───────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _filterChip('semua',    Tr.get('filter_all',      lang), isDark),
                const SizedBox(width: 8),
                _filterChip('aktif',    Tr.get('filter_active',   lang), isDark),
                const SizedBox(width: 8),
                _filterChip('nonaktif', Tr.get('filter_inactive', lang), isDark),
              ],
            ),
          ),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: usersAsync.when(
              data: (all) {
                final filtered = all.where((u) {
                  final nama  = (u['nama']  as String? ?? '').toLowerCase();
                  final email = (u['email'] as String? ?? '').toLowerCase();
                  final q     = _search.toLowerCase();
                  final matchQ = nama.contains(q) || email.contains(q);
                  final isActive = u['status_aktif'] == true;
                  final matchF = _filter == 'semua'
                      || (_filter == 'aktif'    &&  isActive)
                      || (_filter == 'nonaktif' && !isActive);
                  return matchQ && matchF;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: Tr.get('no_users', lang),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(usersProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _UserTile(
                      user: filtered[i],
                      lang: lang,
                      onEdit: () => _showFormDialog(ctx, lang, user: filtered[i]),
                      onDeactivate: () => _deactivate(ctx, filtered[i]),
                      onActivate: () => _activate(ctx, filtered[i]),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: Tr.get('users_load_error', lang),
                onRetry: () => ref.invalidate(usersProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, bool isDark) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: isDark ? AppColors.darkPrimaryTint : AppColors.primaryLight,
      checkmarkColor: AppColors.primary,
      backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.primary
            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark ? AppColors.darkBorder : AppColors.border),
      ),
    );
  }

  Future<void> _deactivate(BuildContext ctx, Map<String, dynamic> user) async {
    final lang = ref.read(langProvider);
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (d) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkDangerTint
                      : AppColors.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_off_outlined,
                    color: AppColors.danger, size: 26),
              ),
              const SizedBox(height: 16),
              Text(Tr.get('confirm_deactivate', lang),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                Tr.get('deactivate_msg', lang),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(d, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(Tr.get('cancel', lang),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(d, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(Tr.get('deactivate', lang),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.deactivateUser(user['id'] as String);
      ref.invalidate(usersProvider);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(Tr.get('deactivated_success', lang)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('${Tr.get("error", lang)}: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    }
  }

  Future<void> _activate(BuildContext ctx, Map<String, dynamic> user) async {
    final lang = ref.read(langProvider);
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (d) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSuccessTint
                      : AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline,
                    color: AppColors.success, size: 26),
              ),
              const SizedBox(height: 16),
              Text(Tr.get('confirm_activate', lang),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                Tr.get('activate_msg', lang),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(d, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(Tr.get('cancel', lang),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(d, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(Tr.get('activate', lang),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.approveUser(user['id'] as String);
      ref.invalidate(usersProvider);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(Tr.get('activated_success', lang)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('${Tr.get("error", lang)}: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    }
  }

  void _showFormDialog(BuildContext context, String lang,
      {Map<String, dynamic>? user}) {
    // Hanya edit — add user tidak didukung (harus lewat registrasi + approval)
    if (user == null) return;
    final namaCtrl = TextEditingController(text: user['nama']);
    String role    = user['role'] ?? 'karyawan';
    bool isActive  = user['status_aktif'] ?? true;
    final fKey     = GlobalKey<FormState>();
    final roles    = ['karyawan', 'manajer', 'hrd', 'admin'];
    final isDark   = Theme.of(context).brightness == Brightness.dark;

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
                  Text(Tr.get('edit_account', lang),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: namaCtrl,
                    decoration: InputDecoration(
                      labelText: Tr.get('full_name', lang),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person_outline, size: 18),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurfaceAlt
                          : AppColors.surfaceAlt,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? Tr.get('name_required', lang) : null,
                  ),
                  const SizedBox(height: 10),

                  // Email — read-only (tidak bisa diubah, harus sinkron auth.users)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceAlt.withOpacity(0.5)
                          : AppColors.surfaceAlt.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder.withOpacity(0.5)
                              : AppColors.border.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email_outlined,
                            size: 18,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary)),
                            Text(user['email'] ?? '',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary)),
                          ],
                        ),
                        const Spacer(),
                        Tooltip(
                          message: Tr.get('email_not_editable', lang),
                          child: Icon(Icons.lock_outline,
                              size: 14,
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.textDisabled),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: role,
                    dropdownColor: isDark
                        ? AppColors.darkSurface
                        : AppColors.surface,
                    decoration: InputDecoration(
                      labelText: Tr.get('role', lang),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon:
                          const Icon(Icons.badge_outlined, size: 18),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurfaceAlt
                          : AppColors.surfaceAlt,
                    ),
                    items: roles
                        .map((r) => DropdownMenuItem(
                            value: r, child: Text(r.toUpperCase())))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setStateBS(() => role = v);
                    },
                  ),

                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(Tr.get('status_active', lang)),
                    value: isActive,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setStateBS(() => isActive = v),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(Tr.get('cancel', lang)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            if (!fKey.currentState!.validate()) return;
                            Navigator.pop(ctx);
                            try {
                              await SupabaseService.updateUserByAdmin(
                                userId:      user['id'] as String,
                                nama:        namaCtrl.text.trim(),
                                email:       user['email'] as String? ?? '',
                                role:        role,
                                statusAktif: isActive,
                              );
                              ref.invalidate(usersProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(Tr.get('saved_success', lang)),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  margin: const EdgeInsets.all(12),
                                ));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                final msg = e.toString().contains('DioException')
                                    ? Tr.get('error', lang)
                                    : '${Tr.get("error", lang)}: $e';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(msg),
                                    backgroundColor: AppColors.danger,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    margin: const EdgeInsets.all(12),
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(Tr.get('save', lang)),
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
    );
  }
}

// ── User Tile ─────────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String lang;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onActivate;

  const _UserTile({
    required this.user,
    required this.lang,
    required this.onEdit,
    required this.onDeactivate,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final nama     = user['nama']?.toString() ?? '-';
    final email    = user['email']?.toString() ?? '-';
    final role     = user['role']?.toString() ?? 'karyawan';
    final isActive = user['status_aktif'] == true;
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isActive
                ? (isDark ? AppColors.darkPrimaryTint : AppColors.primaryLight)
                : (isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt),
            child: Text(
              nama.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive
                    ? AppColors.primary
                    : (isDark
                        ? AppColors.darkTextDisabled
                        : AppColors.textDisabled),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nama,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isActive
                              ? null
                              : (isDark
                                  ? AppColors.darkTextDisabled
                                  : AppColors.textDisabled),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    RoleBadge(role: role),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(email,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? AppColors.success
                            : (isDark
                                ? AppColors.darkTextDisabled
                                : AppColors.textDisabled),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                size: 18,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  const Icon(Icons.edit_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text(Tr.get('edit', lang)),
                ]),
              ),
              if (isActive)
                PopupMenuItem(
                  value: 'deactivate',
                  child: Row(children: [
                    const Icon(Icons.person_off_outlined,
                        size: 16, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Text(Tr.get('deactivate', lang),
                        style: const TextStyle(color: AppColors.danger)),
                  ]),
                )
              else
                PopupMenuItem(
                  value: 'activate',
                  child: Row(children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(Tr.get('activate', lang),
                        style: const TextStyle(color: AppColors.success)),
                  ]),
                ),
            ],
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'deactivate') onDeactivate();
              if (v == 'activate') onActivate();
            },
          ),
        ],
      ),
    );
  }
}
