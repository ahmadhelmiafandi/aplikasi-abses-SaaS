import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';

final reportProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, String>>(
        (ref, params) async {
  return await SupabaseService.getLaporanBulanan(
    bulan: int.parse(params['bulan']!),
    tahun: int.parse(params['tahun']!),
  );
});

class DashboardLaporanScreen extends ConsumerStatefulWidget {
  const DashboardLaporanScreen({super.key});
  @override
  ConsumerState<DashboardLaporanScreen> createState() =>
      _DashboardLaporanScreenState();
}

class _DashboardLaporanScreenState
    extends ConsumerState<DashboardLaporanScreen> {
  String _bulan = DateTime.now().month.toString();
  String _tahun = DateTime.now().year.toString();
  bool _exporting = false;
  int _exportProgress = 0;

  final _bulanNamesId = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final _bulanNamesEn = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final lang   = ref.watch(langProvider);
    final report = ref.watch(reportProvider({'bulan': _bulan, 'tahun': _tahun}));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.get('monthly_report', lang)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: Tr.get('export_report', lang),
            onPressed: () => _showExportDialog(context, lang),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Bar ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            child: Row(
              children: [
                // Bulan
                Expanded(
                  child: _FilterDropdown<String>(
                    value: _bulan,
                    label: Tr.get('month', lang),
                    items: List.generate(12, (i) => (i + 1).toString()),
                    displayText: (v) => (lang == 'id' ? _bulanNamesId : _bulanNamesEn)[int.parse(v) - 1],
                    onChanged: (v) => setState(() => _bulan = v),
                  ),
                ),
                const SizedBox(width: 12),
                // Tahun
                Expanded(
                  child: _FilterDropdown<String>(
                    value: _tahun,
                    label: Tr.get('year', lang),
                    items: ['2024', '2025', '2026', '2027'],
                    displayText: (v) => v,
                    onChanged: (v) => setState(() => _tahun = v),
                  ),
                ),
              ],
            ),
          ),

          // ── Export Progress ───────────────────────────────────────────
          if (_exporting)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.primaryLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${Tr.get('preparing', lang)} $_exportProgress%',
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _exportProgress / 100,
                    backgroundColor: AppColors.border,
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),

          // ── Content ───────────────────────────────────────────────────
          Expanded(
            child: report.when(
              data: (data) {
                final summary = data['summary'] as Map<String, dynamic>;
                final details = data['details'] as List;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Summary KPI cards
                      _SummarySection(summary: summary, lang: lang),
                      const SizedBox(height: 20),
                      // Detail table
                      _DetailTable(details: details, lang: lang),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: Tr.get('error', lang),
                onRetry: () => ref.invalidate(
                    reportProvider({'bulan': _bulan, 'tahun': _tahun})),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(Tr.get('export_report', lang)),
        content: Text(Tr.get('select_format', lang)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(Tr.get('cancel', lang))),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: Text(Tr.get('export_pdf', lang)),
            onPressed: () {
              Navigator.pop(ctx);
              _doExport('pdf');
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.table_chart_outlined, size: 16),
            label: Text(Tr.get('export_excel', lang)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _doExport('excel');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _doExport(String format) async {
    setState(() { _exporting = true; _exportProgress = 0; });

    try {
      // Tampilkan progress animasi sementara download berlangsung
      for (var p in [15, 35]) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) setState(() => _exportProgress = p);
      }

      final ext      = format == 'excel' ? 'xlsx' : 'pdf';
      final bulanNum = (_getLang() == 'id' ? _bulanNamesId : _bulanNamesEn)[int.parse(_bulan) - 1];
      final filename = 'laporan_absensi_${bulanNum}_$_tahun.$ext';

      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/$filename';

      // Download dari backend
      await DioClient().dio.download(
        '/laporan/export/$format',
        path,
        queryParameters: {'bulan': _bulan, 'tahun': _tahun},
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            final pct = (35 + (received / total * 55)).toInt().clamp(35, 90);
            setState(() => _exportProgress = pct);
          }
        },
        options: Options(responseType: ResponseType.bytes),
      );

      if (mounted) setState(() => _exportProgress = 100);
      await Future.delayed(const Duration(milliseconds: 300));

      // Buka file
      await OpenFilex.open(path);

      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$filename ${Tr.get("downloaded_success", _getLang())}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.response?.data?['message'] ?? Tr.get('download_failed', _getLang())),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${Tr.get("error", _getLang())}: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    }
  }

  String _getLang() => ref.read(langProvider);
}

// ── Summary Section ───────────────────────────────────────────────────────────
class _SummarySection extends StatelessWidget {
  final Map<String, dynamic> summary;
  final String lang;

  const _SummarySection({required this.summary, required this.lang});

  @override
  Widget build(BuildContext context) {
    final totalHadir    = (summary['total_hadir']     ?? 0) as int;
    final totalTerlambat = (summary['total_terlambat'] ?? 0) as int;
    final totalIzin     = (summary['total_izin']      ?? 0) as int;
    final totalAlpha    = (summary['total_alpha']     ?? 0) as int;
    final totalKaryawan = (summary['total_karyawan']  ?? 0) as int;

    return Column(
      children: [
        // Big KPI
        Row(
          children: [
            Expanded(
              flex: 2,
              child: StatCard(
                label: Tr.get('hadir', lang),
                value: totalHadir.toString(),
                color: AppColors.statusHadir,
                icon: Icons.how_to_reg_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: Tr.get('total_karyawan', lang),
                value: totalKaryawan.toString(),
                color: AppColors.primary,
                icon: Icons.people_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 3 small KPI
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: Tr.get('terlambat', lang),
                value: totalTerlambat.toString(),
                color: AppColors.statusTerlambat,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: Tr.get('izin', lang),
                value: totalIzin.toString(),
                color: AppColors.statusIzin,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: Tr.get('alpha', lang),
                value: totalAlpha.toString(),
                color: AppColors.statusAlpha,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Detail Table ──────────────────────────────────────────────────────────────
class _DetailTable extends StatelessWidget {
  final List details;
  final String lang;

  const _DetailTable({required this.details, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: SectionHeader(
              title: Tr.get('detail_per_karyawan', lang),
              subtitle: '${details.length} ${Tr.get("karyawan_count", lang)}',
            ),
          ),
          const Divider(height: 1),
          // Table header
          Container(
            color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    lang == 'id' ? 'Nama' : 'Name',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                  ),
                ),
                for (final h in [
                  Tr.get('hadir',     lang),
                  Tr.get('terlambat', lang),
                  Tr.get('izin',      lang),
                  Tr.get('alpha',     lang),
                ])
                  Expanded(
                    child: Text(
                      h,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          // Rows
          ...details.asMap().entries.map((e) {
            final i    = e.key;
            final item = e.value as Map<String, dynamic>;
            final hadir     = (item['hadir']     ?? 0) as int;
            final terlambat = (item['terlambat'] ?? 0) as int;
            final izin      = (item['izin']      ?? 0) as int;
            final alpha     = (item['alpha']     ?? 0) as int;

            return Container(
              color: i.isEven
                  ? Colors.transparent
                  : (isDark
                      ? AppColors.darkSurfaceAlt.withOpacity(0.3)
                      : AppColors.surfaceAlt.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      item['nama']?.toString() ?? '-',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _TableCell(value: hadir,     color: AppColors.statusHadir),
                  _TableCell(value: terlambat, color: AppColors.statusTerlambat, highlight: terlambat > 3),
                  _TableCell(value: izin,      color: AppColors.statusIzin),
                  _TableCell(value: alpha,     color: AppColors.statusAlpha, highlight: alpha > 0),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final int value;
  final Color color;
  final bool highlight;

  const _TableCell({
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: highlight
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              )
            : Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 13,
                  color: value > 0 ? color : AppColors.textDisabled,
                ),
              ),
      ),
    );
  }
}

// ── Filter Dropdown ───────────────────────────────────────────────────────────
class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String label;
  final List<T> items;
  final String Function(T) displayText;
  final void Function(T) onChanged;

  const _FilterDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.displayText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          items: items.map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(displayText(item)),
              )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}
