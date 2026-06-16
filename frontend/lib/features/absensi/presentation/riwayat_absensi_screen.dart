import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';

// Provider dengan parameter bulan + tahun
final riwayatAbsensiProvider = FutureProvider.family<
    List<Map<String, dynamic>>, Map<String, int>>((ref, params) async {
  return SupabaseService.getAbsensiHistory(
    bulan: params['bulan']!,
    tahun: params['tahun']!,
  );
});

class RiwayatAbsensiScreen extends ConsumerStatefulWidget {
  const RiwayatAbsensiScreen({super.key});

  @override
  ConsumerState<RiwayatAbsensiScreen> createState() =>
      _RiwayatAbsensiScreenState();
}

class _RiwayatAbsensiScreenState extends ConsumerState<RiwayatAbsensiScreen> {
  int _bulan = DateTime.now().month;
  int _tahun = DateTime.now().year;
  int? _selectedDay;
  bool _calendarExpanded = true;

  final _bulanNamesId = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final _bulanNamesEn = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final _hariNamesId = const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  final _hariNamesEn = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final ScrollController _listController = ScrollController();

  Map<String, int> get _params => {'bulan': _bulan, 'tahun': _tahun};

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _prevMonth() {
    setState(() {
      _selectedDay = null;
      if (_bulan == 1) { _bulan = 12; _tahun--; }
      else _bulan--;
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_tahun > now.year || (_tahun == now.year && _bulan >= now.month)) return;
    setState(() {
      _selectedDay = null;
      if (_bulan == 12) { _bulan = 1; _tahun++; }
      else _bulan++;
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _bulan == now.month && _tahun == now.year;
  }

  /// Build a map: day (int) → status (string) from the attendance list
  Map<int, String> _buildDayStatusMap(List<Map<String, dynamic>> list) {
    final map = <int, String>{};
    for (final item in list) {
      final tanggal = item['tanggal']?.toString();
      if (tanggal == null) continue;
      try {
        final dt = DateTime.parse(tanggal);
        map[dt.day] = item['status']?.toString() ?? '';
      } catch (_) {}
    }
    return map;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'hadir':     return AppColors.statusHadir;
      case 'terlambat': return AppColors.statusTerlambat;
      case 'izin':      return AppColors.statusIzin;
      case 'alpha':     return AppColors.statusAlpha;
      default:          return AppColors.textDisabled;
    }
  }

  void _onDayTap(int day, List<Map<String, dynamic>> list) {
    setState(() => _selectedDay = _selectedDay == day ? null : day);

    // Find index of the card matching this day & scroll to it
    final idx = list.indexWhere((item) {
      final tanggal = item['tanggal']?.toString();
      if (tanggal == null) return false;
      try {
        return DateTime.parse(tanggal).day == day;
      } catch (_) {
        return false;
      }
    });

    if (idx >= 0 && _listController.hasClients) {
      // Approximate card height (card ~90px + separator 8px)
      final offset = (idx * 98.0).clamp(0.0, _listController.position.maxScrollExtent);
      _listController.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang    = ref.watch(langProvider);
    final async   = ref.watch(riwayatAbsensiProvider(_params));
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.get('attendance_history', lang)),
      ),
      body: Column(
        children: [
          // ── Month Navigator ──────────────────────────────────────────────
          Container(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceAlt
                        : AppColors.surfaceAlt,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _calendarExpanded = !_calendarExpanded),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(lang == 'id' ? _bulanNamesId : _bulanNamesEn)[_bulan - 1]} $_tahun',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _calendarExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      async.maybeWhen(
                        data: (list) => Text(
                          lang == 'id'
                              ? '${list.length} hari tercatat'
                              : '${list.length} days recorded',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary),
                        ),
                        orElse: () => const SizedBox(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isCurrentMonth ? null : _nextMonth,
                  icon: Icon(Icons.chevron_right,
                      color: _isCurrentMonth
                          ? (isDark ? AppColors.darkTextDisabled : AppColors.textDisabled)
                          : null),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceAlt
                        : AppColors.surfaceAlt,
                  ),
                ),
              ],
            ),
          ),

          // ── Interactive Calendar Grid ───────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _calendarExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: async.maybeWhen(
              data: (list) {
                final dayStatusMap = _buildDayStatusMap(list);
                return _CalendarGrid(
                  bulan: _bulan,
                  tahun: _tahun,
                  dayStatusMap: dayStatusMap,
                  selectedDay: _selectedDay,
                  hariNames: lang == 'id' ? _hariNamesId : _hariNamesEn,
                  statusColor: _statusColor,
                  onDayTap: (day) => _onDayTap(day, list),
                  isDark: isDark,
                );
              },
              orElse: () => const SizedBox(height: 8),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),

          // ── Summary chips ─────────────────────────────────────────────────
          async.maybeWhen(
            data: (list) {
              final hadir     = list.where((a) => a['status'] == 'hadir').length;
              final terlambat = list.where((a) => a['status'] == 'terlambat').length;
              final izin      = list.where((a) => a['status'] == 'izin').length;
              final alpha     = list.where((a) => a['status'] == 'alpha').length;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _SummaryChip(Tr.get('hadir',     lang), hadir,     AppColors.statusHadir),
                    _SummaryChip(Tr.get('terlambat', lang), terlambat, AppColors.statusTerlambat),
                    _SummaryChip(Tr.get('izin',      lang), izin,      AppColors.statusIzin),
                    _SummaryChip(Tr.get('alpha',     lang), alpha,     AppColors.statusAlpha),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox(height: 8),
          ),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: async.when(
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: Tr.get('empty', lang),
                    subtitle: lang == 'id'
                        ? 'Belum ada rekaman absensi di ${_bulanNamesId[_bulan - 1]} $_tahun'
                        : 'No attendance records in ${_bulanNamesEn[_bulan - 1]} $_tahun',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(riwayatAbsensiProvider(_params)),
                  child: ListView.separated(
                    controller: _listController,
                    padding:
                        const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final item = list[i];
                      final tanggal = item['tanggal']?.toString();
                      int? day;
                      try { day = DateTime.parse(tanggal ?? '').day; } catch (_) {}

                      final isHighlighted = _selectedDay != null && day == _selectedDay;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: isHighlighted
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              )
                            : null,
                        child: _AbsensiCard(item: item, lang: lang),
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: Tr.get('error', lang),
                onRetry: () =>
                    ref.invalidate(riwayatAbsensiProvider(_params)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendar Grid ─────────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final int bulan;
  final int tahun;
  final Map<int, String> dayStatusMap;
  final int? selectedDay;
  final List<String> hariNames;
  final Color Function(String) statusColor;
  final void Function(int) onDayTap;
  final bool isDark;

  const _CalendarGrid({
    required this.bulan,
    required this.tahun,
    required this.dayStatusMap,
    required this.selectedDay,
    required this.hariNames,
    required this.statusColor,
    required this.onDayTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(tahun, bulan + 1, 0).day;
    // Monday = 1 in DateTime.weekday, we want Mon = 0 index
    final firstWeekday = (DateTime(tahun, bulan, 1).weekday - 1) % 7;
    final today = DateTime.now();
    final isThisMonth = today.month == bulan && today.year == tahun;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Day-of-week headers
          Row(
            children: hariNames.map((name) => Expanded(
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 6),
          // Calendar cells
          ...List.generate(
            ((firstWeekday + daysInMonth + 6) ~/ 7), // number of weeks
            (week) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: List.generate(7, (col) {
                    final dayIndex = week * 7 + col - firstWeekday + 1;
                    if (dayIndex < 1 || dayIndex > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 36));
                    }

                    final status = dayStatusMap[dayIndex];
                    final hasData = status != null;
                    final isToday = isThisMonth && dayIndex == today.day;
                    final isSelected = selectedDay == dayIndex;

                    return Expanded(
                      child: GestureDetector(
                        onTap: hasData ? () => onDayTap(dayIndex) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 36,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.15)
                                : isToday
                                    ? (isDark
                                        ? AppColors.darkSurfaceAlt
                                        : AppColors.surfaceAlt)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday && !isSelected
                                ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5)
                                : isSelected
                                    ? Border.all(color: AppColors.primary, width: 1.5)
                                    : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayIndex',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isToday || isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primary
                                      : isToday
                                          ? AppColors.primary
                                          : isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Dot indicator
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: hasData ? 6 : 0,
                                height: hasData ? 6 : 0,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasData
                                      ? statusColor(status)
                                      : Colors.transparent,
                                  boxShadow: hasData
                                      ? [
                                          BoxShadow(
                                            color: statusColor(status).withOpacity(0.4),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Summary Chip ──────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: color.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Absensi Card ──────────────────────────────────────────────────────────────
class _AbsensiCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String lang;

  const _AbsensiCard({required this.item, required this.lang});

  String _fmt(String? t) {
    if (t == null || t.isEmpty) return '—';
    // Potong menjadi HH:mm
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  String _fmtDate(String? d, String lang) {
    if (d == null) return '—';
    try {
      final locale = lang == 'id' ? 'id_ID' : 'en_US';
      return DateFormat('EEEE, d MMM', locale).format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status      = item['status']?.toString() ?? '';
    final tanggal     = item['tanggal']?.toString();
    final jamMasuk    = item['jam_masuk']?.toString();
    final jamKeluar   = item['jam_keluar']?.toString();
    final terlambat   = (item['menit_terlambat'] as num?)?.toInt() ?? 0;
    final isOvertime  = item['is_overtime'] == true;
    final locale      = lang == 'id' ? 'id_ID' : 'en_US';

    final lateLabel   = lang == 'id'
        ? 'Terlambat $terlambat menit'
        : 'Late $terlambat min';
    final overtimeLabel = lang == 'id' ? 'Lembur' : 'Overtime';
    final masukLabel    = lang == 'id' ? 'Masuk'  : 'In';
    final pulangLabel   = lang == 'id' ? 'Pulang' : 'Out';

    return AppCard(
      child: Row(
        children: [
          // ── Tanggal block ───────────────────────────────────────────────
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  tanggal != null
                      ? DateFormat('d').format(DateTime.parse(tanggal))
                      : '—',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  tanggal != null
                      ? DateFormat('EEE', locale)
                          .format(DateTime.parse(tanggal))
                      : '—',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // ── Detail ─────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDate(tanggal, lang),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _TimeInfo(Icons.login,  masukLabel,  _fmt(jamMasuk),  AppColors.success),
                    const SizedBox(width: 14),
                    _TimeInfo(Icons.logout, pulangLabel, _fmt(jamKeluar), AppColors.danger),
                  ],
                ),
                if (terlambat > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 12,
                          color: AppColors.statusTerlambat),
                      const SizedBox(width: 4),
                      Text(
                        lateLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.statusTerlambat,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Status + overtime badge ─────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: status, lang: lang),
              if (isOvertime) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFF7C3AED).withOpacity(0.4)),
                  ),
                  child: Text(
                    overtimeLabel,
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color color;

  const _TimeInfo(this.icon, this.label, this.time, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: color.withOpacity(0.7))),
            Text(time,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ],
    );
  }
}
