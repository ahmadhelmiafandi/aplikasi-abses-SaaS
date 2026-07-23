import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/translations.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';

class PlansPanel extends ConsumerStatefulWidget {
  const PlansPanel({super.key});

  @override
  ConsumerState<PlansPanel> createState() => _PlansPanelState();
}

class _PlansPanelState extends ConsumerState<PlansPanel> {
  List<dynamic> _plans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
      final res = await DioClient().dio.get('/superadmin/plans', options: opt);
      _plans = res.data['data'] ?? [];

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Gagal memuat subscription plans: $e';
        });
      }
    }
  }

  Future<void> _deletePlan(String id) async {
    try {
      final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
      await DioClient().dio.delete('/superadmin/plans/$id', options: opt);
      _showSnack('Plan berhasil dihapus ✓');
      _fetchPlans();
    } catch (e) {
      _showSnack('Gagal menghapus plan: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _openFormDialog({Map<String, dynamic>? plan}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: plan?['name'] ?? '');
    final maxEmployeesCtrl = TextEditingController(text: plan?['max_employees']?.toString() ?? '5');
    
    // features is an array, we join them with comma
    final featuresList = plan?['features'] as List?;
    final featuresCtrl = TextEditingController(
      text: featuresList != null ? featuresList.join(', ') : 'absensi, izin',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plan == null ? 'Tambah Subscription Plan' : 'Edit Subscription Plan'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Plan (e.g. Pro, Premium)'),
                validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: maxEmployeesCtrl,
                decoration: const InputDecoration(labelText: 'Maksimal Karyawan'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Maksimal karyawan wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: featuresCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fitur',
                  hintText: 'pisahkan dengan koma (contoh: absensi, izin, lembur)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              // split features by comma
              final features = featuresCtrl.text
                  .split(',')
                  .map((f) => f.trim())
                  .where((f) => f.isNotEmpty)
                  .toList();

              final payload = {
                'name': nameCtrl.text.trim(),
                'max_employees': int.tryParse(maxEmployeesCtrl.text.trim()) ?? 5,
                'features': features,
              };

              try {
                final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
                if (plan == null) {
                  await DioClient().dio.post('/superadmin/plans', data: payload, options: opt);
                  _showSnack('Plan berhasil ditambahkan ✓');
                } else {
                  await DioClient().dio.put('/superadmin/plans/${plan['id']}', data: payload, options: opt);
                  _showSnack('Plan berhasil diperbarui ✓');
                }
                Navigator.pop(ctx);
                _fetchPlans();
              } catch (e) {
                _showSnack('Gagal menyimpan plan: $e', isError: true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _fetchPlans,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kelola Paket Subscription',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _openFormDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Plan'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AppCard(
              child: _plans.isEmpty
                  ? const Center(child: Text('Belum ada paket subscription.'))
                  : ListView.separated(
                      itemCount: _plans.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, i) {
                        final p = _plans[i];
                        final features = p['features'] as List? ?? [];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            child: const Icon(Icons.card_membership, color: Colors.orange),
                          ),
                          title: Text(
                            p['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Maksimal Karyawan: ${p['max_employees']}'),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: features
                                    .map((f) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            f.toString(),
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _openFormDialog(plan: p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteConfirm(p),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(dynamic plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Paket'),
        content: Text('Apakah Anda yakin ingin menghapus paket "${plan['name']}"?\nPastikan tidak ada tenant yang sedang menggunakan paket ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deletePlan(plan['id']);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
