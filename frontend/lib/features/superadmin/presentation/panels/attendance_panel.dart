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

class AttendancePanel extends ConsumerStatefulWidget {
  const AttendancePanel({super.key});

  @override
  ConsumerState<AttendancePanel> createState() => _AttendancePanelState();
}

class _AttendancePanelState extends ConsumerState<AttendancePanel> {
  List<dynamic> _absensi = [];
  List<dynamic> _filteredAbsensi = [];
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
      
      // Fetch attendance
      final res = await DioClient().dio.get('/superadmin/absensi', options: opt);
      _absensi = res.data['data'] ?? [];

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
          _error = 'Gagal memuat absensi: $e';
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredAbsensi = _absensi.where((a) {
        final profile = a['profiles'] ?? {};
        final name = profile['nama']?.toString().toLowerCase() ?? '';
        final email = profile['email']?.toString().toLowerCase() ?? '';
        
        final matchesSearch = name.contains(query) || email.contains(query);
        final matchesTenant = _selectedTenantFilter == 'all' || a['id_tenant'] == _selectedTenantFilter;

        return matchesSearch && matchesTenant;
      }).toList();
    });
  }

  Future<void> _deleteAbsensi(String id) async {
    try {
      final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
      await DioClient().dio.delete('/superadmin/absensi/$id', options: opt);
      _showSnack('Rekam absensi berhasil dihapus ✓');
      _fetchData();
    } catch (e) {
      _showSnack('Gagal menghapus absensi: $e', isError: true);
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
    final tanggalCtrl = TextEditingController(text: item['tanggal'] ?? '');
    final masukCtrl = TextEditingController(text: item['jam_masuk'] ?? '');
    final keluarCtrl = TextEditingController(text: item['jam_keluar'] ?? '');
    final terlambatCtrl = TextEditingController(text: item['menit_terlambat']?.toString() ?? '0');
    final keteranganCtrl = TextEditingController(text: item['keterangan'] ?? '');

    String selectedStatus = item['status'] ?? 'hadir';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Absensi - ${item['profiles']?['nama'] ?? ''}'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: tanggalCtrl,
                  decoration: const InputDecoration(labelText: 'Tanggal (YYYY-MM-DD)'),
                  validator: (v) => v == null || v.isEmpty ? 'Tanggal wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: masukCtrl,
                  decoration: const InputDecoration(labelText: 'Jam Masuk (HH:MM:SS)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: keluarCtrl,
                  decoration: const InputDecoration(labelText: 'Jam Keluar (HH:MM:SS)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status Kehadiran'),
                  items: const [
                    DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                    DropdownMenuItem(value: 'terlambat', child: Text('Terlambat')),
                    DropdownMenuItem(value: 'izin', child: Text('Izin')),
                    DropdownMenuItem(value: 'alpha', child: Text('Alpha')),
                  ],
                  onChanged: (val) {
                    selectedStatus = val!;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: terlambatCtrl,
                  decoration: const InputDecoration(labelText: 'Menit Terlambat'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: keteranganCtrl,
                  decoration: const InputDecoration(labelText: 'Keterangan'),
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
                'tanggal': tanggalCtrl.text.trim(),
                'jam_masuk': masukCtrl.text.trim().isEmpty ? null : masukCtrl.text.trim(),
                'jam_keluar': keluarCtrl.text.trim().isEmpty ? null : keluarCtrl.text.trim(),
                'status': selectedStatus,
                'menit_terlambat': int.tryParse(terlambatCtrl.text) ?? 0,
                'keterangan': keteranganCtrl.text.trim().isEmpty ? null : keteranganCtrl.text.trim(),
              };

              try {
                final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
                await DioClient().dio.put('/superadmin/absensi/${item['id']}', data: payload, options: opt);
                _showSnack('Rekam absensi berhasil diperbarui ✓');
                Navigator.pop(ctx);
                _fetchData();
              } catch (e) {
                _showSnack('Gagal menyimpan absensi: $e', isError: true);
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
            'Kelola Log Kehadiran Karyawan',
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
              child: _filteredAbsensi.isEmpty
                  ? const Center(child: Text('Tidak ada log absensi.'))
                  : ListView.separated(
                      itemCount: _filteredAbsensi.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, i) {
                        final a = _filteredAbsensi[i];
                        final profile = a['profiles'] ?? {};
                        final name = profile['nama'] ?? 'User';
                        final tenantName = a['tenant']?['name'] ?? 'Tenant';
                        final dateStr = a['tanggal'] ?? '';

                        return ListTile(
                          leading: StatusBadge(status: a['status'] ?? 'hadir', lang: lang),
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
                              Text('Tanggal: $dateStr'),
                              Text(
                                'Masuk: ${a['jam_masuk'] ?? '-'} | Pulang: ${a['jam_keluar'] ?? '-'}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _openFormDialog(a),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteConfirm(a),
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
        title: const Text('Hapus Absensi'),
        content: Text('Apakah Anda yakin ingin menghapus log kehadiran ${item['profiles']?['nama'] ?? ''} pada tanggal ${item['tanggal'] ?? ''}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAbsensi(item['id']);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
