import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../auth/presentation/auth_provider.dart';

final acaraListProvider = StateProvider<List<Map<String, dynamic>>>((ref) {
  final now = DateTime.now();
  return [
    {
      'id': '1',
      'judul': 'Meeting All Hands & Standup Mingguan',
      'kategori': 'Rapat Internal',
      'waktu': DateTime(now.year, now.month, now.day, 09, 00).toIso8601String(),
      'lokasi': 'Ruang Meeting Utama / Google Meet',
      'warna': const Color(0xFF2563EB),
    },
    {
      'id': '2',
      'judul': 'Review Proyek SaaS & Sprints Q3',
      'kategori': 'Meeting Tenant',
      'waktu': DateTime(now.year, now.month, now.day + 2, 13, 30).toIso8601String(),
      'lokasi': 'Ruang Diskusi Lt. 2',
      'warna': const Color(0xFF7C3AED),
    },
    {
      'id': '3',
      'judul': 'Hari Kemerdekaan Indonesia (Libur Nasional)',
      'kategori': 'Libur Nasional',
      'waktu': DateTime(now.year, 8, 17).toIso8601String(),
      'lokasi': 'Nasional',
      'warna': const Color(0xFFDC2626),
    },
  ];
});

class KalenderAcaraScreen extends ConsumerStatefulWidget {
  const KalenderAcaraScreen({super.key});

  @override
  ConsumerState<KalenderAcaraScreen> createState() => _KalenderAcaraScreenState();
}

class _KalenderAcaraScreenState extends ConsumerState<KalenderAcaraScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final role = user?['role']?.toString() ?? 'karyawan';
    final isAdmin = role == 'admin' || role == 'hrd' || role == 'superadmin';
    final events = ref.watch(acaraListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(lang == 'id' ? 'Kalender Acara & Rapat' : 'Calendar & Meetings'),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEventDialog(context, ref, lang),
              icon: const Icon(Icons.add),
              label: Text(lang == 'id' ? 'Tambah Acara' : 'Add Event'),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar Month Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy', lang == 'id' ? 'id_ID' : 'en_US').format(_selectedDate),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () {
                              setState(() {
                                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              setState(() {
                                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Days of week row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'].map((day) {
                      return SizedBox(
                        width: 36,
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: day == 'Min' ? AppColors.danger : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              lang == 'id' ? 'Agenda & Rapat Mendatang' : 'Upcoming Meetings & Events',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            events.isEmpty
                ? EmptyState(
                    icon: Icons.event_busy,
                    title: lang == 'id' ? 'Tidak Ada Acara' : 'No Events Scheduled',
                    subtitle: lang == 'id' ? 'Belum ada agenda rapat atau acara tenant' : 'No meetings or tenant events yet',
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = events[i];
                      final dt = DateTime.parse(item['waktu']);
                      final color = item['warna'] as Color? ?? AppColors.primary;
                      final timeStr = DateFormat('dd MMM yyyy — HH:mm', lang == 'id' ? 'id_ID' : 'en_US').format(dt);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item['kategori'],
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['judul'],
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 12, color: AppColors.textDisabled),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeStr,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textDisabled),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          item['lokasi'],
                                          style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context, WidgetRef ref, String lang) {
    final judulCtrl = TextEditingController();
    final lokasiCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang == 'id' ? 'Tambah Acara / Rapat Baru' : 'New Event / Meeting'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: judulCtrl,
                decoration: InputDecoration(
                  labelText: lang == 'id' ? 'Nama Acara / Rapat' : 'Event Name',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lokasiCtrl,
                decoration: InputDecoration(
                  labelText: lang == 'id' ? 'Lokasi / Tautan Meeting' : 'Location / Link',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.get('cancel', lang)),
          ),
          ElevatedButton(
            onPressed: () {
              if (judulCtrl.text.trim().isEmpty) return;
              final newEvent = {
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'judul': judulCtrl.text.trim(),
                'kategori': 'Rapat Tenant',
                'waktu': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
                'lokasi': lokasiCtrl.text.trim().isEmpty ? 'Ruang Meeting' : lokasiCtrl.text.trim(),
                'warna': const Color(0xFF059669),
              };
              ref.read(acaraListProvider.notifier).update((state) => [newEvent, ...state]);
              Navigator.pop(ctx);
            },
            child: Text(lang == 'id' ? 'Simpan' : 'Save'),
          ),
        ],
      ),
    );
  }
}
