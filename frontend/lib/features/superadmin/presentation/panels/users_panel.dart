import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/translations.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';

class UsersPanel extends ConsumerStatefulWidget {
  const UsersPanel({super.key});

  @override
  ConsumerState<UsersPanel> createState() => _UsersPanelState();
}

class _UsersPanelState extends ConsumerState<UsersPanel> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
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
      
      // Fetch users
      final usersRes = await DioClient().dio.get('/superadmin/users', options: opt);
      _users = usersRes.data['data'] ?? [];

      // Fetch tenants (for filtering and dropdown)
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
          _error = 'Gagal memuat pengguna: $e';
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((u) {
        final matchesSearch = (u['nama']?.toString().toLowerCase().contains(query) ?? false) ||
            (u['email']?.toString().toLowerCase().contains(query) ?? false);
        
        final matchesTenant = _selectedTenantFilter == 'all' || u['id_tenant'] == _selectedTenantFilter;

        return matchesSearch && matchesTenant;
      }).toList();
    });
  }

  Future<void> _deleteUser(String id) async {
    try {
      final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
      await DioClient().dio.delete('/superadmin/users/$id', options: opt);
      _showSnack('Akun pengguna berhasil dihapus ✓');
      _fetchData();
    } catch (e) {
      _showSnack('Gagal menghapus pengguna: $e', isError: true);
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

  void _openFormDialog({Map<String, dynamic>? user}) {
    final formKey = GlobalKey<FormState>();
    final namaCtrl = TextEditingController(text: user?['nama'] ?? '');
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final passwordCtrl = TextEditingController();
    final hpCtrl = TextEditingController(text: user?['nomor_hp'] ?? '');
    final alamatCtrl = TextEditingController(text: user?['alamat'] ?? '');

    String selectedRole = user?['role'] ?? 'karyawan';
    String? selectedTenantId = user?['id_tenant'];
    bool statusAktif = user?['status_aktif'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSB) => AlertDialog(
          title: Text(user == null ? 'Tambah Pengguna' : 'Edit Pengguna'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: namaCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                    validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Alamat Email'),
                    validator: (v) => v == null || v.isEmpty ? 'Email wajib diisi' : null,
                    enabled: user == null, // email cannot be changed
                  ),
                  if (user == null) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) => v == null || v.length < 6 ? 'Password minimal 6 karakter' : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role Pengguna'),
                    items: const [
                      DropdownMenuItem(value: 'karyawan', child: Text('Karyawan')),
                      DropdownMenuItem(value: 'manajer', child: Text('Manajer')),
                      DropdownMenuItem(value: 'hrd', child: Text('HRD')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (val) {
                      setStateSB(() {
                        selectedRole = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedTenantId,
                    decoration: const InputDecoration(labelText: 'Tenant Organisasi'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tanpa Tenant (Global / Super Admin)'),
                      ),
                      ..._tenants.map((t) => DropdownMenuItem<String?>(
                            value: t['id'],
                            child: Text(t['name'] ?? ''),
                          )),
                    ],
                    onChanged: (val) {
                      setStateSB(() {
                        selectedTenantId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Status Aktif'),
                    value: statusAktif,
                    onChanged: (val) {
                      setStateSB(() {
                        statusAktif = val;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: hpCtrl,
                    decoration: const InputDecoration(labelText: 'Nomor HP (Opsional)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: alamatCtrl,
                    decoration: const InputDecoration(labelText: 'Alamat (Opsional)'),
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
                  'nama': namaCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'role': selectedRole,
                  'id_tenant': selectedTenantId,
                  'status_aktif': statusAktif,
                  'nomor_hp': hpCtrl.text.trim().isEmpty ? null : hpCtrl.text.trim(),
                  'alamat': alamatCtrl.text.trim().isEmpty ? null : alamatCtrl.text.trim(),
                };

                if (user == null) {
                  payload['password'] = passwordCtrl.text;
                }

                try {
                  final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
                  if (user == null) {
                    await DioClient().dio.post('/superadmin/users', data: payload, options: opt);
                    _showSnack('Pengguna berhasil dibuat ✓');
                  } else {
                    await DioClient().dio.put('/superadmin/users/${user['id']}', data: payload, options: opt);
                    _showSnack('Pengguna berhasil diperbarui ✓');
                  }
                  Navigator.pop(ctx);
                  _fetchData();
                } catch (e) {
                  _showSnack('Gagal menyimpan pengguna: $e', isError: true);
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

    final isWide = MediaQuery.of(context).size.width > 700;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kelola Seluruh Pengguna',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _openFormDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah User'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cari Nama / Email...',
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
              child: _filteredUsers.isEmpty
                  ? const Center(child: Text('Pengguna tidak ditemukan.'))
                  : ListView.separated(
                      itemCount: _filteredUsers.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, i) {
                        final u = _filteredUsers[i];
                        final tenantName = u['tenant']?['name'] ?? 'Platform Global';
                        final email = u['email'] ?? '';
                        final active = u['status_aktif'] ?? false;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.person, color: AppColors.primary),
                          ),
                          title: Row(
                            children: [
                              Text(
                                u['nama'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              RoleBadge(role: u['role'] ?? 'karyawan'),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(email),
                              Text('Tenant: $tenantName', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: active ? Colors.green : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _openFormDialog(user: u),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteConfirm(u),
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

  void _showDeleteConfirm(dynamic user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: Text('Apakah Anda yakin ingin menghapus pengguna "${user['nama']}"?\nTindakan ini akan menghapus permanen semua data kehadiran & profil mereka dari sistem.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUser(user['id']);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
