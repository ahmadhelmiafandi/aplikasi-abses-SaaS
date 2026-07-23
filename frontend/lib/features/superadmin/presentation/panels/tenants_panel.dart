import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/translations.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';

class TenantsPanel extends ConsumerStatefulWidget {
  const TenantsPanel({super.key});

  @override
  ConsumerState<TenantsPanel> createState() => _TenantsPanelState();
}

class _TenantsPanelState extends ConsumerState<TenantsPanel> {
  List<dynamic> _tenants = [];
  List<dynamic> _plans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
      
      // Fetch tenants
      final tenantsRes = await DioClient().dio.get('/superadmin/tenants', options: opt);
      _tenants = tenantsRes.data['data'] ?? [];

      // Fetch plans
      final plansRes = await DioClient().dio.get('/superadmin/plans', options: opt);
      _plans = plansRes.data['data'] ?? [];

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Gagal memuat data: $e';
        });
      }
    }
  }

  Future<void> _deleteTenant(String id) async {
    try {
      final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
      await DioClient().dio.delete('/superadmin/tenants/$id', options: opt);
      _showSnack('Tenant berhasil dihapus');
      _fetchData();
    } catch (e) {
      _showSnack('Gagal menghapus tenant: $e', isError: true);
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

  void _openFormDialog({Map<String, dynamic>? tenant}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: tenant?['name'] ?? '');
    final subdomainCtrl = TextEditingController(text: tenant?['subdomain'] ?? '');
    
    // Settings
    final settings = tenant?['tenant_settings']?[0] ?? tenant?['tenant_settings'];
    final officeLatCtrl = TextEditingController(
      text: settings?['office_lat']?.toString() ?? '-6.9826',
    );
    final officeLngCtrl = TextEditingController(
      text: settings?['office_lng']?.toString() ?? '110.4092',
    );
    final geofenceRadiusCtrl = TextEditingController(
      text: settings?['geofence_radius_meter']?.toString() ?? '100',
    );

    String? selectedPlanId = tenant?['id_plan'];
    if (selectedPlanId == null && _plans.isNotEmpty) {
      // Find default or free plan
      final freePlan = _plans.firstWhere((p) => p['name'].toString().toLowerCase() == 'free', orElse: () => null);
      selectedPlanId = freePlan?['id'] ?? _plans.first['id'];
    }

    String selectedStatus = tenant?['subscription_status'] ?? 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSB) => AlertDialog(
          title: Text(tenant == null ? 'Tambah Tenant' : 'Edit Tenant'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Perusahaan/Tenant'),
                    validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: subdomainCtrl,
                    decoration: const InputDecoration(labelText: 'Subdomain (e.g. company)'),
                    validator: (v) => v == null || v.isEmpty ? 'Subdomain wajib diisi' : null,
                    enabled: tenant == null, // subdomain cannot be edited
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedPlanId,
                    decoration: const InputDecoration(labelText: 'Subscription Plan'),
                    items: _plans
                        .map((p) => DropdownMenuItem<String>(
                              value: p['id'],
                              child: Text('${p['name']} (Max ${p['max_employees']} Karyawan)'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setStateSB(() {
                        selectedPlanId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Subscription Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    ],
                    onChanged: (val) {
                      setStateSB(() {
                        selectedStatus = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('GPS & Geofencing (Kantor)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: officeLatCtrl,
                          decoration: const InputDecoration(labelText: 'Latitude'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: officeLngCtrl,
                          decoration: const InputDecoration(labelText: 'Longitude'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: geofenceRadiusCtrl,
                    decoration: const InputDecoration(labelText: 'Radius Geofence (Meter)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
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
                
                final payload = {
                  'name': nameCtrl.text.trim(),
                  'subdomain': subdomainCtrl.text.trim().toLowerCase(),
                  'id_plan': selectedPlanId,
                  'status': selectedStatus,
                  'office_lat': double.tryParse(officeLatCtrl.text),
                  'office_lng': double.tryParse(officeLngCtrl.text),
                  'geofence_radius_meter': int.tryParse(geofenceRadiusCtrl.text),
                };

                try {
                  final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
                  if (tenant == null) {
                    await DioClient().dio.post('/superadmin/tenants', data: payload, options: opt);
                    _showSnack('Tenant berhasil ditambahkan ✓');
                  } else {
                    await DioClient().dio.put('/superadmin/tenants/${tenant['id']}', data: payload, options: opt);
                    _showSnack('Tenant berhasil diperbarui ✓');
                  }
                  Navigator.pop(ctx);
                  _fetchData();
                } catch (e) {
                  _showSnack('Gagal menyimpan tenant: $e', isError: true);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _fetchData,
      );
    }

    final isWide = MediaQuery.of(context).size.width > 800;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manajemen Tenant SaaS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _openFormDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Tenant'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AppCard(
              child: _tenants.isEmpty
                  ? const Center(child: Text('Belum ada tenant.'))
                  : ListView.separated(
                      itemCount: _tenants.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, i) {
                        final t = _tenants[i];
                        final planName = t['subscription_plans']?['name']?.toString() ?? 'Free';
                        final status = t['subscription_status'] ?? 'active';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            child: const Icon(Icons.domain, color: Colors.blue),
                          ),
                          title: Text(
                            t['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${t['subdomain']}.siabsen.id'),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      planName,
                                      style: const TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge(status: status, lang: lang),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _openFormDialog(tenant: t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteConfirm(t),
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

  void _showDeleteConfirm(dynamic tenant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Tenant'),
        content: Text('Apakah Anda yakin ingin menghapus tenant "${tenant['name']}"?\nTindakan ini bersifat permanen dan menghapus seluruh data karyawan & absensi di bawah tenant ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTenant(tenant['id']);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
