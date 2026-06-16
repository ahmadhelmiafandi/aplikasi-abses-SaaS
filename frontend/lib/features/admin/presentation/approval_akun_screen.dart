import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';

final pendingUsersProvider = FutureProvider.autoDispose((ref) async {
  return await SupabaseService.getPendingUsers();
});

class ApprovalAkunScreen extends ConsumerWidget {
  const ApprovalAkunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang    = ref.watch(langProvider);
    final pending = ref.watch(pendingUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: pending.maybeWhen(
          data: (u) => Text('${Tr.get('approval_account', lang)} (${u.length})'),
          orElse: () => Text(Tr.get('approval_account', lang)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingUsersProvider),
        child: pending.when(
          data: (users) {
            if (users.isEmpty) {
              return EmptyState(
                icon: Icons.check_circle_outline,
                title: Tr.get('no_pending_accounts', lang),
                subtitle: Tr.get('all_approvals_done', lang),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _PendingUserCard(
                user: users[i],
                lang: lang,
                onApprove: () async {
                  await _doApprove(ctx, ref, users[i], lang);
                },
                onReject: () async {
                  await _doReject(ctx, ref, users[i], lang);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: Tr.get('load_error', lang),
            onRetry: () => ref.invalidate(pendingUsersProvider),
          ),
        ),
      ),
    );
  }

  Future<void> _doApprove(BuildContext context, WidgetRef ref,
      Map<String, dynamic> user, String lang) async {
    final confirm = await _confirmDialog(
      context,
      title: Tr.get('approve_account', lang),
      content: Tr.get('approve_msg', lang),
      confirmLabel: Tr.get('approve', lang),
      confirmColor: AppColors.success,
      lang: lang,
    );
    if (!confirm) return;
    try {
      await SupabaseService.approveUser(user['id'] as String);
      ref.invalidate(pendingUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Tr.get('approved_success', lang)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${Tr.get("error", lang)}: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _doReject(BuildContext context, WidgetRef ref,
      Map<String, dynamic> user, String lang) async {
    final confirm = await _confirmDialog(
      context,
      title: Tr.get('reject_account', lang),
      content: Tr.get('reject_msg', lang),
      confirmLabel: Tr.get('reject', lang),
      confirmColor: AppColors.danger,
      lang: lang,
    );
    if (!confirm) return;
    try {
      await SupabaseService.deactivateUser(user['id'] as String);
      ref.invalidate(pendingUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Tr.get('rejected_label', lang)),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${Tr.get("error", lang)}: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<bool> _confirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
    required String lang,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(Tr.get('cancel', lang)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _PendingUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String lang;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingUserCard({
    required this.user,
    required this.lang,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final nama  = user['nama']?.toString() ?? '-';
    final email = user['email']?.toString() ?? '-';
    final createdAt = user['created_at']?.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String tglDaftar = '';
    if (createdAt != null) {
      try {
        tglDaftar = DateFormat('d MMM yyyy').format(DateTime.parse(createdAt));
      } catch (_) {}
    }

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark
                ? AppColors.darkWarningTint
                : AppColors.warningLight,
            child: Text(
              nama.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark
                    ? AppColors.warning
                    : AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nama,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(email,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary)),
                if (tglDaftar.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('${Tr.get("registered_date", lang)}: $tglDaftar',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextDisabled
                              : AppColors.textDisabled)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              SizedBox(
                height: 34,
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(Tr.get('reject', lang),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(Tr.get('approve', lang),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
