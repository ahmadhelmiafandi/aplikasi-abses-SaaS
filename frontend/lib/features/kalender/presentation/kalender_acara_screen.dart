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

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final role = user?['role']?.toString() ?? 'karyawan';
    final isAdmin = role == 'admin' || role == 'hrd' || role == 'superadmin';
    final events = ref.watch(acaraListProvider);

    final todayEvents = events.where((e) {
      try {
        return _isToday(DateTime.parse(e['waktu']));
      } catch (_) {
        return false;
      }
    }).toList();

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
            // ── Active Notification Alert Banner for Today's Agenda ──────────────
            if (todayEvents.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  lang == 'id' ? 'PING! AGENDA HARI INI' : 'TODAY AGENDA ALERT',
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${todayEvents.length} Agenda',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            todayEvents.first['judul'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 13, color: Colors.white.withOpacity(0.9)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  todayEvents.first['lokasi'],
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
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
              ),
            ],

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
              lang == 'id' ? 'Agenda & Rapat Perusahaan' : 'Company Meetings & Events',
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
                      final isCurrentToday = _isToday(dt);
                      final color = item['warna'] as Color? ?? AppColors.primary;
                      final timeStr = DateFormat('dd MMM yyyy — HH:mm', lang == 'id' ? 'id_ID' : 'en_US').format(dt);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCurrentToday
                              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                              : (isDark ? AppColors.darkSurface : AppColors.surface),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrentToday
                                ? AppColors.primary
                                : (isDark ? AppColors.darkBorder : AppColors.border),
                            width: isCurrentToday ? 2 : 1,
                          ),
                          boxShadow: isCurrentToday
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isCurrentToday ? AppColors.danger : color,
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
                                      if (isCurrentToday) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            lang == 'id' ? 'HARI INI' : 'TODAY',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
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
    bool setToday = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(lang == 'id' ? 'Hari Ini' : 'Today'),
                      selected: setToday,
                      onSelected: (val) => setModalState(() => setToday = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(lang == 'id' ? 'Besok' : 'Tomorrow'),
                      selected: !setToday,
                      onSelected: (val) => setModalState(() => setToday = false),
                    ),
                  ],
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
                final eventTime = setToday
                    ? DateTime.now()
                    : DateTime.now().add(const Duration(days: 1));
                final newEvent = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'judul': judulCtrl.text.trim(),
                  'kategori': 'Rapat Tenant',
                  'waktu': eventTime.toIso8601String(),
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
      ),
    );
  }
}
