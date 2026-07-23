import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/translations.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';

class LeavesPanel extends ConsumerStatefulWidget {
  const LeavesPanel({super.key});

  @override
  ConsumerState<LeavesPanel> createState() => _LeavesPanelState();
}

class _LeavesPanelState extends ConsumerState<LeavesPanel> {
  List<dynamic> _izin = [];
  List<dynamic> _filteredIzin = [];
  List<dynamic> _tenants = [];
  bool _isLoading = true;
  String? _error;

  final _searchCtrl = TextEditingController();
  String _selectedTenantFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
      
      // Fetch leaves
      final res = await DioClient().dio.get('/superadmin/izin', options: opt);
      _izin = res.data['data'] ?? [];

      // Fetch tenants
      final tenantsRes = await DioClient().dio.get('/superadmin/tenants', options: opt);
      _tenants = tenantsRes.data['data'] ?? [];

      _applyFilters();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Gagal memuat pengajuan izin: $e';
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredIzin = _izin.where((i) {
        final profile = i['profiles'] ?? {};
        final name = profile['nama']?.toString().toLowerCase() ?? '';
        final email = profile['email']?.toString().toLowerCase() ?? '';
        
        final matchesSearch = name.contains(query) || email.contains(query);
        final matchesTenant = _selectedTenantFilter == 'all' || i['id_tenant'] == _selectedTenantFilter;

        return matchesSearch && matchesTenant;
      }).toList();
    });
  }

  Future<void> _deleteIzin(String id) async {
    try {
      final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
      await DioClient().dio.delete('/superadmin/izin/$id', options: opt);
      _showSnack('Pengajuan izin berhasil dihapus ✓');
      _fetchData();
    } catch (e) {
      _showSnack('Gagal menghapus izin: $e', isError: true);
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

  void _openFormDialog(Map<String, dynamic> item) {
    final formKey = GlobalKey<FormState>();
    final mulaiCtrl = TextEditingController(text: item['tanggal_mulai'] ?? '');
    final selesaiCtrl = TextEditingController(text: item['tanggal_selesai'] ?? '');
    final alasanCtrl = TextEditingController(text: item['alasan'] ?? '');
    final catatanCtrl = TextEditingController(text: item['catatan_approver'] ?? '');

    String selectedJenis = item['jenis_izin'] ?? 'sakit';
    String selectedStatus = item['status'] ?? 'pending';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Izin - ${item['profiles']?['nama'] ?? ''}'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: mulaiCtrl,
                  decoration: const InputDecoration(labelText: 'Tanggal Mulai (YYYY-MM-DD)'),
                  validator: (v) => v == null || v.isEmpty ? 'Tanggal wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: selesaiCtrl,
                  decoration: const InputDecoration(labelText: 'Tanggal Selesai (YYYY-MM-DD)'),
                  validator: (v) => v == null || v.isEmpty ? 'Tanggal wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedJenis,
                  decoration: const InputDecoration(labelText: 'Jenis Izin'),
                  items: const [
                    DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                    DropdownMenuItem(value: 'pribadi', child: Text('Pribadi')),
                    DropdownMenuItem(value: 'cuti', child: Text('Cuti')),
                  ],
                  onChanged: (val) {
                    selectedJenis = val!;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status Persetujuan'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'disetujui', child: Text('Disetujui')),
                    DropdownMenuItem(value: 'ditolak', child: Text('Ditolak')),
                  ],
                  onChanged: (val) {
                    selectedStatus = val!;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: alasanCtrl,
                  decoration: const InputDecoration(labelText: 'Alasan Izin'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: catatanCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan Approver'),
                  maxLines: 2,
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
                'tanggal_mulai': mulaiCtrl.text.trim(),
                'tanggal_selesai': selesaiCtrl.text.trim(),
                'jenis_izin': selectedJenis,
                'status': selectedStatus,
                'alasan': alasanCtrl.text.trim().isEmpty ? null : alasanCtrl.text.trim(),
                'catatan_approver': catatanCtrl.text.trim().isEmpty ? null : catatanCtrl.text.trim(),
              };

              try {
                final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
                await DioClient().dio.put('/superadmin/izin/${item['id']}', data: payload, options: opt);
                _showSnack('Pengajuan izin berhasil diperbarui ✓');
                Navigator.pop(ctx);
                _fetchData();
              } catch (e) {
                _showSnack('Gagal menyimpan izin: $e', isError: true);
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kelola Seluruh Pengajuan Izin / Cuti',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Filter Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cari Nama / Email Karyawan...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTenantFilter,
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Semua Tenant')),
                      ..._tenants.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['name'] ?? ''))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedTenantFilter = val!;
                        _applyFilters();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AppCard(
              child: _filteredIzin.isEmpty
                  ? const Center(child: Text('Tidak ada pengajuan izin.'))
                  : ListView.separated(
                      itemCount: _filteredIzin.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, i) {
                        final item = _filteredIzin[i];
                        final profile = item['profiles'] ?? {};
                        final name = profile['nama'] ?? 'User';
                        final tenantName = item['tenant']?['name'] ?? 'Tenant';
                        final tMulai = item['tanggal_mulai'] ?? '';
                        final tSelesai = item['tanggal_selesai'] ?? '';
                        final status = item['status'] ?? 'pending';

                        return ListTile(
                          leading: StatusBadge(status: status, lang: lang),
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('($tenantName)', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Jenis: ${item['jenis_izin']?.toString().toUpperCase() ?? ''}'),
                              Text('Tanggal: $tMulai s.d $tSelesai'),
                              if (item['alasan'] != null)
                                Text('Alasan: ${item['alasan']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _openFormDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteConfirm(item),
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

  void _showDeleteConfirm(dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Izin'),
        content: Text('Apakah Anda yakin ingin menghapus pengajuan izin ${item['profiles']?['nama'] ?? ''} untuk tanggal ${item['tanggal_mulai'] ?? ''}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteIzin(item['id']);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
