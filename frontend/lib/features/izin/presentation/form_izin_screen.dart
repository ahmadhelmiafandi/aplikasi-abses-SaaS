import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';
import 'daftar_izin_screen.dart';

class FormIzinScreen extends ConsumerStatefulWidget {
  const FormIzinScreen({super.key});
  @override
  ConsumerState<FormIzinScreen> createState() => _FormIzinScreenState();
}

class _FormIzinScreenState extends ConsumerState<FormIzinScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _alasanCtrl = TextEditingController();
  String    _jenis    = 'sakit';
  DateTime? _startDate;
  DateTime? _endDate;
  bool      _isLoading = false;

  @override
  void dispose() {
    _alasanCtrl.dispose();
    super.dispose();
  }

  int? get _durasi {
    if (_startDate == null || _endDate == null) return null;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _submit() async {
    final lang = ref.read(langProvider);
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showSnack(lang == 'id'
          ? 'Pilih tanggal mulai dan selesai'
          : 'Select start and end date', isError: true);
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _showSnack(lang == 'id'
          ? 'Tanggal selesai tidak boleh sebelum tanggal mulai'
          : 'End date cannot be before start date', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.ajukanIzin(
        tanggalMulai:  DateFormat('yyyy-MM-dd').format(_startDate!),
        tanggalSelesai: DateFormat('yyyy-MM-dd').format(_endDate!),
        jenisIzin:     _jenis,
        alasan:        _alasanCtrl.text.trim(),
      );
      ref.invalidate(myIzinProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang == 'id'
              ? 'Izin berhasil diajukan ✓'
              : 'Leave request submitted ✓'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } catch (e) {
      _showSnack('${Tr.get("error", ref.read(langProvider))}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now  = DateTime.now();
    final init = isStart
        ? (_startDate ?? now.add(const Duration(days: 1)))
        : (_endDate   ?? (_startDate ?? now).add(const Duration(days: 1)));
    final first = isStart ? now : (_startDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: init.isBefore(first) ? first : init,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang   = ref.watch(langProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final jenisOptions = [
      ('sakit',   Icons.healing_outlined,     AppColors.statusIzin,    Tr.get('sakit', lang)),
      ('pribadi', Icons.person_outline,        AppColors.roleManajer,   Tr.get('pribadi', lang)),
      ('cuti',    Icons.beach_access_outlined, AppColors.roleHrd,       Tr.get('cuti', lang)),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(Tr.get('submit_leave', lang))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Jenis Izin ─────────────────────────────────────────────
              Text(Tr.get('leave_type', lang),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                children: jenisOptions.map((opt) {
                  final (key, icon, color, label) = opt;
                  final isSelected = _jenis == key;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _jenis = key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withOpacity(0.12)
                                : (isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(icon,
                                  color: isSelected ? color : AppColors.textSecondary,
                                  size: 22),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? color : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Tanggal ────────────────────────────────────────────────
              Text(Tr.get('start_date', lang),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerField(
                      label: Tr.get('start_date', lang),
                      date: _startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward,
                        color: AppColors.textSecondary, size: 18),
                  ),
                  Expanded(
                    child: _DatePickerField(
                      label: Tr.get('end_date', lang),
                      date: _endDate,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),

              // ── Durasi ─────────────────────────────────────────────────
              if (_durasi != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${Tr.get('duration', lang)}: $_durasi ${Tr.get('days', lang)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // ── Alasan ─────────────────────────────────────────────────
              Text(Tr.get('leave_reason', lang),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _alasanCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: lang == 'id'
                      ? 'Tulis alasan izin/cuti...'
                      : 'Write your reason...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 5)
                        ? (lang == 'id'
                            ? 'Alasan minimal 5 karakter'
                            : 'Reason must be at least 5 characters')
                        : null,
              ),
              const SizedBox(height: 16),

              // ── Info approval flow ─────────────────────────────────────
              InfoBanner(
                message: lang == 'id'
                    ? 'Izin akan diperiksa oleh Manajer → HRD sebelum disetujui'
                    : 'Leave will be reviewed by Manager → HRD before approval',
                icon: Icons.account_tree_outlined,
                color: AppColors.info,
              ),
              const SizedBox(height: 24),

              LoadingButton(
                label: lang == 'id' ? 'Kirim Pengajuan' : 'Submit Request',
                onPressed: _submit,
                isLoading: _isLoading,
                icon: Icons.send_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 16,
                color: date != null
                    ? AppColors.primary
                    : AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null
                    ? DateFormat('d MMM yyyy').format(date!)
                    : label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      date != null ? FontWeight.w600 : FontWeight.normal,
                  color: date != null
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
