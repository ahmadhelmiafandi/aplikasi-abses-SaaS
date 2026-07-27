import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../notifikasi/presentation/notifikasi_screen.dart';
import '../../auth/presentation/auth_provider.dart';

/// Service Libur Nasional Indonesia (Mendukung API Dinamis untuk Semua Tahun + Fallback Offline)
class IndonesianHolidayService {
  static final Map<int, Map<String, String>> _cache = {};

  /// Pre-defined fallback offline data untuk tahun 2025, 2026, 2027
  static final Map<int, Map<String, String>> _offlineFallback = {
    2025: {
      '2025-01-01': 'Tahun Baru 2025 Masehi',
      '2025-01-27': 'Isra Mikraj Nabi Muhammad SAW',
      '2025-01-29': 'Tahun Baru Imlek 2576 Kongzili',
      '2025-03-29': 'Hari Suci Nyepi (Saka 1947)',
      '2025-03-31': 'Hari Raya Idul Fitri 1446 H',
      '2025-04-01': 'Hari Raya Idul Fitri 1446 H (Hari Ke-2)',
      '2025-04-18': 'Wafat Yesus Kristus',
      '2025-04-20': 'Hari Paskah',
      '2025-05-01': 'Hari Buruh Internasional',
      '2025-05-12': 'Hari Raya Waisak 2569 BE',
      '2025-05-29': 'Kenaikan Yesus Kristus',
      '2025-06-01': 'Hari Lahir Pancasila',
      '2025-06-07': 'Hari Raya Idul Adha 1446 H',
      '2025-06-27': 'Tahun Baru Islam 1447 H',
      '2025-08-17': 'Hari Kemerdekaan RI (17 Agustus)',
      '2025-09-05': 'Maulid Nabi Muhammad SAW',
      '2025-12-25': 'Hari Raya Natal',
    },
    2026: {
      '2026-01-01': 'Tahun Baru 2026 Masehi',
      '2026-01-16': 'Isra Mikraj Nabi Muhammad SAW',
      '2026-01-29': 'Tahun Baru Imlek 2577 Kongzili',
      '2026-03-19': 'Hari Suci Nyepi (Saka 1948)',
      '2026-03-20': 'Hari Raya Idul Fitri 1447 H',
      '2026-03-21': 'Hari Raya Idul Fitri 1447 H (Hari Ke-2)',
      '2026-04-03': 'Wafat Yesus Kristus',
      '2026-04-05': 'Hari Paskah',
      '2026-05-01': 'Hari Buruh Internasional',
      '2026-05-14': 'Kenaikan Yesus Kristus',
      '2026-05-27': 'Hari Raya Waisak 2570 BE',
      '2026-06-01': 'Hari Lahir Pancasila',
      '2026-06-17': 'Hari Raya Idul Adha 1447 H',
      '2026-07-07': 'Tahun Baru Islam 1448 H',
      '2026-08-17': 'Hari Kemerdekaan Republik Indonesia',
      '2026-09-25': 'Maulid Nabi Muhammad SAW',
      '2026-12-25': 'Hari Raya Natal',
    },
    2027: {
      '2027-01-01': 'Tahun Baru 2027 Masehi',
      '2027-02-06': 'Tahun Baru Imlek 2578 Kongzili',
      '2027-02-08': 'Hari Raya Idul Fitri 1448 H',
      '2027-03-08': 'Hari Suci Nyepi (Saka 1949)',
      '2027-03-26': 'Wafat Yesus Kristus',
      '2027-05-01': 'Hari Buruh Internasional',
      '2027-05-06': 'Kenaikan Yesus Kristus',
      '2027-05-16': 'Hari Raya Idul Adha 1448 H',
      '2027-05-20': 'Hari Raya Waisak 2571 BE',
      '2027-06-01': 'Hari Lahir Pancasila',
      '2027-06-16': 'Tahun Baru Islam 1449 H',
      '2027-08-17': 'Hari Kemerdekaan RI',
      '2027-08-25': 'Maulid Nabi Muhammad SAW',
      '2027-12-25': 'Hari Raya Natal',
    },
  };

  /// Mengambil data hari libur nasional untuk tahun tertentu via Public API Indonesia
  static Future<Map<String, String>> getHolidays(int year) async {
    if (_cache.containsKey(year)) {
      return _cache[year]!;
    }

    try {
      // Panggil Public API Kalender Indonesia (Day Off API)
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 4);
      final response = await dio.get('https://dayoffapi.vercel.app/api?year=$year');

      if (response.statusCode == 200 && response.data is List) {
        final Map<String, String> holidays = {};
        for (var item in response.data) {
          if (item is Map && item['is_cuti'] == false) {
            final dateStr = item['is_leave'] == false || item['is_cuti'] == false
                ? item['tanggal']?.toString()
                : null;
            final name = item['keterangan']?.toString();
            if (dateStr != null && name != null) {
              holidays[dateStr] = name;
            }
          }
        }
        if (holidays.isNotEmpty) {
          _cache[year] = holidays;
          return holidays;
        }
      }
    } catch (_) {
      // Silently catch network timeout / offline & fallback
    }

    // Fallback Offline
    final fallback = _offlineFallback[year] ?? _offlineFallback[2026]!;
    _cache[year] = fallback;
    return fallback;
  }
}

final acaraListProvider = StateProvider<List<Map<String, dynamic>>>((ref) {
  final now = DateTime.now();
  return [
    {
      'id': '1',
      'judul': 'Meeting All Hands & Standup Mingguan',
      'kategori': 'Rapat Internal',
      'waktu': DateTime(now.year, now.month, now.day, 09, 00).toIso8601String(),
      'lokasi': 'Ruang Meeting Utama / Google Meet',
      'target_peserta': 'semua',
      'target_label': 'Semua Karyawan Tenant',
      'warna': const Color(0xFF2563EB),
    },
    {
      'id': '2',
      'judul': 'Review Proyek SaaS & Sprints Q3',
      'kategori': 'Meeting Tenant',
      'waktu': DateTime(now.year, now.month, now.day + 2, 13, 30).toIso8601String(),
      'lokasi': 'Ruang Diskusi Lt. 2',
      'target_peserta': 'departemen',
      'target_label': 'Divisi IT & Software',
      'warna': const Color(0xFF7C3AED),
    },
    {
      'id': '3',
      'judul': 'Hari Kemerdekaan Indonesia (Libur Nasional)',
      'kategori': 'Libur Nasional',
      'waktu': DateTime(now.year, 8, 17).toIso8601String(),
      'lokasi': 'Nasional (Seluruh Indonesia)',
      'target_peserta': 'semua',
      'target_label': 'Nasional',
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
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  Map<String, String> _currentHolidays = {};
  bool _isLoadingHolidays = false;

  @override
  void initState() {
    super.initState();
    _loadHolidaysForYear(_focusedMonth.year);
  }

  Future<void> _loadHolidaysForYear(int year) async {
    setState(() => _isLoadingHolidays = true);
    final h = await IndonesianHolidayService.getHolidays(year);
    if (mounted) {
      setState(() {
        _currentHolidays = h;
        _isLoadingHolidays = false;
      });
    }
  }

  void _changeMonth(int delta) {
    final nextMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    final yearChanged = nextMonth.year != _focusedMonth.year;
    setState(() {
      _focusedMonth = nextMonth;
    });
    if (yearChanged) {
      _loadHolidaysForYear(nextMonth.year);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isToday(DateTime dt) {
    return _isSameDay(dt, DateTime.now());
  }

  String _formatDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool _isRedDate(DateTime dt) {
    if (dt.weekday == DateTime.sunday) return true;
    final key = _formatDateKey(dt);
    return _currentHolidays.containsKey(key);
  }

  String? _getHolidayName(DateTime dt) {
    final key = _formatDateKey(dt);
    return _currentHolidays[key];
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final role = user?['role']?.toString() ?? 'karyawan';
    final isAdmin = role == 'admin' || role == 'hrd' || role == 'superadmin';
    final events = ref.watch(acaraListProvider);

    // Agenda hari ini
    final todayEvents = events.where((e) {
      try {
        return _isToday(DateTime.parse(e['waktu']));
      } catch (_) {
        return false;
      }
    }).toList();

    // Event terfilter berdasarkan tanggal terpilih
    final filteredEvents = events.where((e) {
      if (_selectedDate == null) return true;
      try {
        final dt = DateTime.parse(e['waktu']);
        return _isSameDay(dt, _selectedDate!);
      } catch (_) {
        return false;
      }
    }).toList();

    final selectedHolidayName = _selectedDate != null ? _getHolidayName(_selectedDate!) : null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(lang == 'id' ? 'Kalender Acara & Rapat' : 'Calendar & Meetings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: lang == 'id' ? 'Kembali ke Hari Ini' : 'Today',
            onPressed: () {
              final now = DateTime.now();
              final yearChanged = now.year != _focusedMonth.year;
              setState(() {
                _focusedMonth = now;
                _selectedDate = now;
              });
              if (yearChanged) _loadHolidaysForYear(now.year);
            },
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEventDialog(context, ref, lang),
              icon: const Icon(Icons.add_task_rounded),
              label: Text(lang == 'id' ? 'Tambah Acara / Rapat' : 'Add Event / Meeting'),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Alert Banner Agenda Hari Ini ───────────────────────────────────
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

            // ── Grid Kalender Indonesia dengan API & Tanggal Merah ───────────
            _buildInteractiveCalendar(isDark, lang, events),

            const SizedBox(height: 16),

            // Banner Tanggal Merah Libur Nasional jika dipilih
            if (selectedHolidayName != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Text('🇮🇩 ', style: TextStyle(fontSize: 18)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'id' ? 'Tanggal Merah — Libur Nasional' : 'National Holiday',
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            selectedHolidayName,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Header Daftar Agenda
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDate == null
                          ? (lang == 'id' ? 'Semua Agenda & Rapat Tenant' : 'All Tenant Events')
                          : DateFormat('EEEE, d MMMM yyyy', lang == 'id' ? 'id_ID' : 'en_US').format(_selectedDate!),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (_selectedDate != null)
                      Text(
                        lang == 'id' ? 'Menampilkan agenda untuk tanggal ini' : 'Showing events for selected date',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                  ],
                ),
                if (_selectedDate != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: Text(lang == 'id' ? 'Lihat Semua' : 'Show All'),
                    onPressed: () => setState(() => _selectedDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Daftar Agenda Cards
            filteredEvents.isEmpty
                ? EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: lang == 'id' ? 'Tidak Ada Agenda' : 'No Events Scheduled',
                    subtitle: _selectedDate != null
                        ? (lang == 'id' ? 'Tidak ada rapat atau acara pada tanggal ini' : 'No meetings on this date')
                        : (lang == 'id' ? 'Belum ada agenda rapat atau acara tenant' : 'No meetings or tenant events yet'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredEvents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = filteredEvents[i];
                      final dt = DateTime.parse(item['waktu']);
                      final isCurrentToday = _isToday(dt);
                      final color = item['warna'] as Color? ?? AppColors.primary;
                      final timeStr = DateFormat('dd MMM yyyy — HH:mm', lang == 'id' ? 'id_ID' : 'en_US').format(dt);
                      final targetLabel = item['target_label'] ?? 'Semua Karyawan';

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
                              height: 58,
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
                                          item['kategori'] ?? 'Acara',
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Badge Target Peserta
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.people_alt_outlined, size: 10),
                                            const SizedBox(width: 3),
                                            Text(
                                              targetLabel,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['judul'] ?? '',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeStr,
                                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(Icons.location_on_outlined, size: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          item['lokasi'] ?? '',
                                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isAdmin && item['id'] != '3')
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                onPressed: () {
                                  ref.read(acaraListProvider.notifier).update(
                                        (state) => state.where((e) => e['id'] != item['id']).toList(),
                                      );
                                },
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

  // ── Grid Kalender Indonesia ──────────────────────────────────────────────────
  Widget _buildInteractiveCalendar(bool isDark, String lang, List<Map<String, dynamic>> events) {
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    final offset = firstWeekday % 7;

    return Container(
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
              Row(
                children: [
                  Text(
                    DateFormat('MMMM yyyy', lang == 'id' ? 'id_ID' : 'en_US').format(_focusedMonth),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_isLoadingHolidays) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _changeMonth(-1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeekdayHeader('Min', isRed: true, isDark: isDark),
              _buildWeekdayHeader('Sen', isRed: false, isDark: isDark),
              _buildWeekdayHeader('Sel', isRed: false, isDark: isDark),
              _buildWeekdayHeader('Rab', isRed: false, isDark: isDark),
              _buildWeekdayHeader('Kam', isRed: false, isDark: isDark),
              _buildWeekdayHeader('Jum', isRed: false, isDark: isDark),
              _buildWeekdayHeader('Sab', isRed: false, isDark: isDark),
            ],
          ),
          const SizedBox(height: 8),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: offset + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (ctx, index) {
              if (index < offset) return const SizedBox();
              final dayNumber = index - offset + 1;
              final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
              final isRed = _isRedDate(cellDate);
              final holidayName = _getHolidayName(cellDate);
              final isToday = _isToday(cellDate);
              final isSelected = _selectedDate != null && _isSameDay(cellDate, _selectedDate!);

              final hasEvent = events.any((e) {
                try {
                  return _isSameDay(DateTime.parse(e['waktu']), cellDate);
                } catch (_) {
                  return false;
                }
              });

              return InkWell(
                onTap: () {
                  setState(() {
                    if (_selectedDate != null && _isSameDay(_selectedDate!, cellDate)) {
                      _selectedDate = null;
                    } else {
                      _selectedDate = cellDate;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isToday
                            ? AppColors.primary.withOpacity(0.15)
                            : (isRed ? AppColors.danger.withOpacity(0.06) : Colors.transparent)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isToday
                              ? AppColors.primary
                              : (isRed ? AppColors.danger.withOpacity(0.3) : (isDark ? AppColors.darkBorder.withOpacity(0.5) : AppColors.border.withOpacity(0.5)))),
                      width: isToday || isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday || isSelected || isRed ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : (isRed
                                  ? AppColors.danger
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasEvent)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (holidayName != null)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader(String day, {required bool isRed, required bool isDark}) {
    return SizedBox(
      width: 36,
      child: Text(
        day,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isRed ? AppColors.danger : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
        ),
      ),
    );
  }

  // ── Dialog Form Input Agenda Acara dengan Pengaturan Target Peserta ───────────
  void _showAddEventDialog(BuildContext context, WidgetRef ref, String lang) {
    final judulCtrl = TextEditingController();
    final lokasiCtrl = TextEditingController();
    final spesifikCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedKategori = 'Rapat Internal';
    String targetPesertaType = 'semua';
    String selectedDept = 'IT & Software';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final kategoriList = [
      'Rapat Internal',
      'Meeting Tenant',
      'Agenda Perusahaan',
      'Webinar & Training',
      'Lainnya',
    ];

    final deptList = [
      'IT & Software',
      'HRD & General Affair',
      'Keuangan & Finance',
      'Operasional',
      'Marketing & Sales',
      'Desain & Kreatif',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final formattedDateStr = DateFormat('EEEE, d MMMM yyyy', lang == 'id' ? 'id_ID' : 'en_US').format(selectedDate);
          final formattedTimeStr = selectedTime.format(context);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            title: Row(
              children: [
                const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang == 'id' ? 'Tambah Acara / Rapat Baru' : 'New Event / Meeting',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: judulCtrl,
                    decoration: InputDecoration(
                      labelText: lang == 'id' ? 'Nama Acara / Rapat' : 'Event Name',
                      hintText: lang == 'id' ? 'misal: Meeting Standup Tim' : 'e.g. Weekly Standup',
                      prefixIcon: const Icon(Icons.event_note_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: lokasiCtrl,
                    decoration: InputDecoration(
                      labelText: lang == 'id' ? 'Lokasi / Tautan Meeting' : 'Location / Link',
                      hintText: lang == 'id' ? 'misal: Ruang Meeting / Google Meet' : 'e.g. Meeting Room 1',
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: selectedKategori,
                    decoration: InputDecoration(
                      labelText: lang == 'id' ? 'Kategori Acara' : 'Category',
                      prefixIcon: const Icon(Icons.category_outlined, size: 20),
                    ),
                    items: kategoriList
                        .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedKategori = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  Text(
                    lang == 'id' ? 'Target Peserta Agenda' : 'Agenda Target Audience',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.groups_rounded, size: 16),
                        label: Text(lang == 'id' ? 'Semua Karyawan' : 'All Employees'),
                        selected: targetPesertaType == 'semua',
                        onSelected: (_) => setModalState(() => targetPesertaType = 'semua'),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.domain_rounded, size: 16),
                        label: Text(lang == 'id' ? 'Divisi / Dept' : 'Department'),
                        selected: targetPesertaType == 'departemen',
                        onSelected: (_) => setModalState(() => targetPesertaType = 'departemen'),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.person_rounded, size: 16),
                        label: Text(lang == 'id' ? 'Karyawan Spesifik' : 'Specific People'),
                        selected: targetPesertaType == 'spesifik',
                        onSelected: (_) => setModalState(() => targetPesertaType = 'spesifik'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (targetPesertaType == 'departemen') ...[
                    DropdownButtonFormField<String>(
                      value: selectedDept,
                      decoration: InputDecoration(
                        labelText: lang == 'id' ? 'Pilih Divisi / Departemen' : 'Select Department',
                        prefixIcon: const Icon(Icons.business_center_outlined, size: 20),
                      ),
                      items: deptList
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedDept = val);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (targetPesertaType == 'spesifik') ...[
                    TextField(
                      controller: spesifikCtrl,
                      decoration: InputDecoration(
                        labelText: lang == 'id' ? 'Nama Karyawan Tertentu' : 'Specific Employee Names',
                        hintText: lang == 'id' ? 'misal: Budi, Sasa, Luffy' : 'e.g. Budi, Sarah',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang == 'id' ? 'Tanggal Acara' : 'Event Date',
                                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                ),
                                Text(
                                  formattedDateStr,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_calendar_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang == 'id' ? 'Jam / Waktu' : 'Time',
                                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                ),
                                Text(
                                  formattedTimeStr,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.schedule_rounded, size: 18),
                        ],
                      ),
                    ),
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
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: Text(
                        Tr.get('cancel', lang),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final judul = judulCtrl.text.trim();
                        if (judul.isEmpty) return;
                        final lokasi = lokasiCtrl.text.trim().isEmpty
                            ? 'Ruang Meeting Utama'
                            : lokasiCtrl.text.trim();

                        final eventDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        String targetLabel = 'Semua Karyawan';
                        if (targetPesertaType == 'departemen') {
                          targetLabel = 'Divisi $selectedDept';
                        } else if (targetPesertaType == 'spesifik') {
                          targetLabel = spesifikCtrl.text.trim().isEmpty
                              ? 'Beberapa Karyawan'
                              : spesifikCtrl.text.trim();
                        }

                        final newEvent = {
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'judul': judul,
                          'kategori': selectedKategori,
                          'waktu': eventDateTime.toIso8601String(),
                          'lokasi': lokasi,
                          'target_peserta': targetPesertaType,
                          'target_label': targetLabel,
                          'warna': selectedKategori == 'Rapat Internal'
                              ? const Color(0xFF2563EB)
                              : (selectedKategori == 'Meeting Tenant'
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFF059669)),
                        };

                        ref.read(acaraListProvider.notifier).update((state) => [newEvent, ...state]);

                        await SupabaseService.createNotifikasi(
                          judul: 'Acara Perusahaan: $judul',
                          pesan: 'Diadakan pada ${DateFormat("d MMM, HH:mm").format(eventDateTime)} di $lokasi. Target: $targetLabel',
                          tipe: 'agenda',
                        );

                        ref.invalidate(notifikasiProvider);
                        ref.invalidate(unreadCountProvider);

                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        lang == 'id' ? 'Simpan Agenda' : 'Save Event',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
