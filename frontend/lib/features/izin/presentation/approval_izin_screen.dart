import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';

final pendingIzinProvider = FutureProvider.autoDispose((ref) async {
  return await SupabaseService.getPendingIzin();
});

class ApprovalIzinScreen extends ConsumerWidget {
  const ApprovalIzinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang     = ref.watch(langProvider);
    final pending  = ref.watch(pendingIzinProvider);

    return Scaffold(
      appBar: AppBar(
        title: pending.maybeWhen(
          data: (items) => Text('${Tr.get('approval_izin', lang)} (${items.length})'),
          orElse: () => Text(Tr.get('approval_izin', lang)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingIzinProvider),
        child: pending.when(
          data: (items) {
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.check_circle_outline,
                title: Tr.get('no_pending', lang),
                subtitle: Tr.get('all_izin_done', lang),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _ApprovalCard(
                item: items[i],
                lang: lang,
                onAction: (action, catatan) async {
                  try {
                    await SupabaseService.reviewIzin(
                      izinId: items[i]['id'],
                      action: action,
                      catatan: catatan,
                    );
                    ref.invalidate(pendingIzinProvider);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(action == 'approve'
                            ? Tr.get('izin_approved', lang)
                            : Tr.get('izin_rejected', lang)),
                        backgroundColor: action == 'approve'
                            ? AppColors.success
                            : AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(12),
                      ));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('${Tr.get("error", lang)}: $e'),
                        backgroundColor: AppColors.danger,
                      ));
                    }
                  }
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: Tr.get('error', lang),
            onRetry: () => ref.invalidate(pendingIzinProvider),
          ),
        ),
      ),
    );
  }
}

// ── Approval Card ─────────────────────────────────────────────────────────────
class _ApprovalCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String lang;
  final void Function(String action, String? catatan) onAction;

  const _ApprovalCard({
    required this.item,
    required this.lang,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // Extract nested profile data
    final profile = item['profiles'] as Map<String, dynamic>?;
    final dept    = profile?['departemen'] as Map<String, dynamic>?;
    final nama    = profile?['nama'] ?? item['nama_karyawan'] ?? 'Unknown';
    final deptName = dept?['nama_departemen'] ?? '';
    final jenis   = item['jenis_izin']?.toString() ?? '';
    final mulai   = item['tanggal_mulai']?.toString() ?? '';
    final selesai = item['tanggal_selesai']?.toString() ?? '';
    final alasan  = item['alasan']?.toString() ?? '';

    String fmtDate(String d) {
      try {
        final locale = lang == 'id' ? 'id_ID' : 'en_US';
        return DateFormat('d MMM yyyy', locale).format(DateTime.parse(d));
      }
      catch (_) { return d; }
    }

    int durasi = 0;
    try {
      durasi = DateTime.parse(selesai).difference(DateTime.parse(mulai)).inDays + 1;
    } catch (_) {}

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  nama.toString().substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nama.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (deptName.isNotEmpty)
                      Text(deptName,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                ),
                child: Text(
                  jenis.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Detail ─────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('${fmtDate(mulai)} – ${fmtDate(selesai)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$durasi ${Tr.get("hari", lang)}',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (alasan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(alasan,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 16),

          // ── Actions ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(Tr.get('reject', lang)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _showDialog(context, 'reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(Tr.get('approve', lang)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => _showDialog(context, 'approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, String action) {
    final catatanCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    action == 'approve'
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: action == 'approve'
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    action == 'approve'
                        ? Tr.get('approve_izin', lang)
                        : Tr.get('reject_izin', lang),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: catatanCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: Tr.get('catatan', lang),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark
                      ? AppColors.darkSurfaceAlt
                      : AppColors.surfaceAlt,
                ),
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
                        backgroundColor: action == 'approve'
                            ? AppColors.success
                            : AppColors.danger,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onAction(action, catatanCtrl.text.trim());
                      },
                      child: Text(action == 'approve'
                          ? Tr.get('approve', lang)
                          : Tr.get('reject', lang)),
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
}
