import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../auth/presentation/auth_provider.dart';

// Dummy / Initial Demo Announcements for Tenant
final pengumumanListProvider = StateProvider<List<Map<String, dynamic>>>((ref) {
  return [
    {
      'id': '1',
      'judul': 'Pengumuman Townhall & Evaluasi Kinerja Q3',
      'isi': 'Seluruh karyawan diharapkan hadir dalam acara Rapat Evaluasi Kinerja Q3 pada hari Jumat pukul 14.00 WIB di Aula / Zoom Meeting.',
      'tanggal': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'penulis': 'HRD Department',
      'penting': true,
    },
    {
      'id': '2',
      'judul': 'Pembaruan Kebijakan WFH & Jam Kerja Fleksibel',
      'isi': 'Mulai bulan depan, kuota WFH disesuaikan menjadi 2 hari per minggu dengan koordinasi atasan langsung.',
      'tanggal': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'penulis': 'Management',
      'penting': false,
    },
  ];
});

class PengumumanScreen extends ConsumerWidget {
  const PengumumanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final role = user?['role']?.toString() ?? 'karyawan';
    final isAdmin = role == 'admin' || role == 'hrd' || role == 'superadmin';
    final announcements = ref.watch(pengumumanListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(lang == 'id' ? 'Pengumuman Perusahaan' : 'Company Announcements'),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, ref, lang),
              icon: const Icon(Icons.add),
              label: Text(lang == 'id' ? 'Buat Pengumuman' : 'Add Announcement'),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: announcements.isEmpty
          ? EmptyState(
              icon: Icons.campaign_outlined,
              title: lang == 'id' ? 'Belum Ada Pengumuman' : 'No Announcements Yet',
              subtitle: lang == 'id' ? 'Pengumuman resmi tenant akan tampil di sini' : 'Official announcements will appear here',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: announcements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = announcements[i];
                final isImportant = item['penting'] == true;
                final dt = DateTime.parse(item['tanggal']);
                final dateStr = DateFormat('dd MMMM yyyy, HH:mm', lang == 'id' ? 'id_ID' : 'en_US').format(dt);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isImportant
                          ? AppColors.primary.withOpacity(0.5)
                          : (isDark ? AppColors.darkBorder : AppColors.border),
                      width: isImportant ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isImportant) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                lang == 'id' ? 'PENTING' : 'IMPORTANT',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              item['judul'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['isi'],
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 14, color: AppColors.textDisabled),
                              const SizedBox(width: 4),
                              Text(
                                item['penulis'],
                                style: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
                              ),
                            ],
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, String lang) {
    final judulCtrl = TextEditingController();
    final isiCtrl   = TextEditingController();
    bool penting    = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(lang == 'id' ? 'Buat Pengumuman Perusahaan' : 'New Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: judulCtrl,
                  decoration: InputDecoration(
                    labelText: lang == 'id' ? 'Judul Pengumuman' : 'Title',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: isiCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: lang == 'id' ? 'Isi Pengumuman' : 'Content',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text(lang == 'id' ? 'Tandai sebagai Penting' : 'Mark as Important'),
                  value: penting,
                  onChanged: (v) => setStateModal(() => penting = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      Tr.get('cancel', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (judulCtrl.text.trim().isEmpty || isiCtrl.text.trim().isEmpty) return;
                      final newItem = {
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'judul': judulCtrl.text.trim(),
                        'isi': isiCtrl.text.trim(),
                        'tanggal': DateTime.now().toIso8601String(),
                        'penulis': 'HRD / Admin',
                        'penting': penting,
                      };
                      ref.read(pengumumanListProvider.notifier).update((state) => [newItem, ...state]);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      lang == 'id' ? 'Kirim' : 'Publish',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
