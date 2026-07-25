import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/theme_provider.dart';
import '../../auth/presentation/auth_provider.dart';

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final namaKaryawan = user?['nama'] ?? 'Karyawan';
    final namaPerusahaan = user?['nama_perusahaan'] ?? 'PT SiAbsen SaaS Enterprise';

    final rupiahFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Dummy salary details matching standard Indonesian payroll format
    const gajiPokok = 7500000;
    const tunjanganMakan = 800000;
    const tunjanganTransport = 600000;
    const bpjsKesehatan = 150000;
    const bpjsKetenagakerjaan = 225000;
    const pph21 = 180000;

    const totalPendapatan = gajiPokok + tunjanganMakan + tunjanganTransport;
    const totalPotongan = bpjsKesehatan + bpjsKetenagakerjaan + pph21;
    const gajiNetto = totalPendapatan - totalPotongan;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(lang == 'id' ? 'Payroll & Slip Gaji' : 'Payroll & Payslip'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Month Selector Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            namaPerusahaan,
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            namaKaryawan,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success.withOpacity(0.5)),
                        ),
                        child: Text(
                          lang == 'id' ? 'Dibayarkan' : 'Paid',
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang == 'id' ? 'Total Gaji Bersih (THP)' : 'Take Home Pay',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                      ),
                      Text(
                        rupiahFormat.format(gajiNetto),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pendapatan Details Card
            _buildSectionCard(
              title: lang == 'id' ? 'Pendapatan' : 'Earnings',
              icon: Icons.add_circle_outline,
              iconColor: AppColors.success,
              isDark: isDark,
              items: [
                _buildLineItem(lang == 'id' ? 'Gaji Pokok' : 'Basic Salary', rupiahFormat.format(gajiPokok), isDark),
                _buildLineItem(lang == 'id' ? 'Tunjangan Uang Makan' : 'Meal Allowance', rupiahFormat.format(tunjanganMakan), isDark),
                _buildLineItem(lang == 'id' ? 'Tunjangan Transportasi' : 'Transport Allowance', rupiahFormat.format(tunjanganTransport), isDark),
              ],
              totalLabel: lang == 'id' ? 'Total Pendapatan' : 'Total Earnings',
              totalValue: rupiahFormat.format(totalPendapatan),
            ),

            const SizedBox(height: 16),

            // Potongan Details Card
            _buildSectionCard(
              title: lang == 'id' ? 'Potongan' : 'Deductions',
              icon: Icons.remove_circle_outline,
              iconColor: AppColors.danger,
              isDark: isDark,
              items: [
                _buildLineItem('BPJS Kesehatan (1%)', rupiahFormat.format(bpjsKesehatan), isDark),
                _buildLineItem('BPJS Ketenagakerjaan (2%)', rupiahFormat.format(bpjsKetenagakerjaan), isDark),
                _buildLineItem('PPh 21', rupiahFormat.format(pph21), isDark),
              ],
              totalLabel: lang == 'id' ? 'Total Potongan' : 'Total Deductions',
              totalValue: rupiahFormat.format(totalPotongan),
              isDeduction: true,
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lang == 'id'
                        ? 'Slip Gaji Juli 2026 telah diunduh (PDF)'
                        : 'Payslip for July 2026 downloaded (PDF)'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(lang == 'id' ? 'Unduh Slip Gaji (PDF)' : 'Download Payslip (PDF)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required List<Widget> items,
    required String totalLabel,
    required String totalValue,
    bool isDeduction = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          ...items,
          const Divider(),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                totalValue,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDeduction ? AppColors.danger : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
