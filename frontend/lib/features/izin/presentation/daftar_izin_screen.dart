import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';

final myIzinProvider = FutureProvider.autoDispose((ref) async {
  return await SupabaseService.getMyIzin();
});

class DaftarIzinScreen extends ConsumerStatefulWidget {
  const DaftarIzinScreen({super.key});
  @override
  ConsumerState<DaftarIzinScreen> createState() => _DaftarIzinScreenState();
}

class _DaftarIzinScreenState extends ConsumerState<DaftarIzinScreen> {
  String _filter = 'semua';

  @override
  Widget build(BuildContext context) {
    final lang     = ref.watch(langProvider);
    final izinList = ref.watch(myIzinProvider);
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.get('my_leave', lang)),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/izin/ajukan').then((_) => ref.invalidate(myIzinProvider)),
            icon: const Icon(Icons.add, size: 18),
            label: Text(Tr.get('submit_leave', lang)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ──────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: ['semua', 'pending', 'disetujui', 'ditolak'].map((f) {
                final isSelected = _filter == f;
                final label = f == 'semua'
                    ? Tr.get('all', lang)
                    : Tr.get(f, lang);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: AppColors.primaryLight,
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: izinList.when(
              data: (data) {
                final filtered = _filter == 'semua'
                    ? data
                    : data.where((i) => i['status'] == _filter).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: Tr.get('empty', lang),
                    subtitle: _filter == 'semua'
                        ? (lang == 'id' ? 'Belum ada pengajuan izin' : 'No leave requests yet')
                        : (lang == 'id' ? 'Tidak ada izin dengan status ini' : 'No leave with this status'),
                    actionLabel: Tr.get('submit_leave', lang),
                    onAction: () => context.push('/izin/ajukan')
                        .then((_) => ref.invalidate(myIzinProvider)),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myIzinProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _IzinCard(
                      item: filtered[i],
                      lang: lang,
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: Tr.get('error', lang),
                onRetry: () => ref.invalidate(myIzinProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/izin/ajukan')
            .then((_) => ref.invalidate(myIzinProvider)),
        icon: const Icon(Icons.add),
        label: Text(Tr.get('submit_leave', lang)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _IzinCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String lang;

  const _IzinCard({required this.item, required this.lang});

  @override
  Widget build(BuildContext context) {
    final jenis  = item['jenis_izin']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';
    final mulai  = item['tanggal_mulai']?.toString() ?? '';
    final selesai = item['tanggal_selesai']?.toString() ?? '';
    final alasan = item['alasan']?.toString() ?? '';

    // Hitung durasi
    int durasi = 0;
    try {
      final m = DateTime.parse(mulai);
      final s = DateTime.parse(selesai);
      durasi = s.difference(m).inDays + 1;
    } catch (_) {}

    // Format tanggal locale-aware
    String fmtDate(String d) {
      try {
        final locale = lang == 'id' ? 'id_ID' : 'en_US';
        return DateFormat('d MMM yyyy', locale).format(DateTime.parse(d));
      } catch (_) {
        return d;
      }
    }

    final (_, jenisColor) = _jenisData(jenis);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: jenisColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: jenisColor.withOpacity(0.4)),
                ),
                child: Text(
                  jenis.toUpperCase(),
                  style: TextStyle(
                    color: jenisColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              StatusBadge(status: status, lang: lang),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${fmtDate(mulai)} – ${fmtDate(selesai)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$durasi ${Tr.get('days', lang)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (alasan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              alasan,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          // Catatan approver
          if (item['catatan_approver'] != null &&
              (item['catatan_approver'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.comment_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['catatan_approver'].toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static (String, Color) _jenisData(String jenis) {
    switch (jenis.toLowerCase()) {
      case 'sakit':   return ('Sakit',   AppColors.statusIzin);
      case 'pribadi': return ('Pribadi', AppColors.roleManajer);
      case 'cuti':    return ('Cuti',    AppColors.roleHrd);
      default:        return (jenis,     AppColors.textSecondary);
    }
  }
}
