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

class OverviewPanel extends ConsumerStatefulWidget {
  const OverviewPanel({super.key});

  @override
  ConsumerState<OverviewPanel> createState() => _OverviewPanelState();
}

class _OverviewPanelState extends ConsumerState<OverviewPanel> {
  bool _isLoading = true;
  String? _error;

  int _totalTenants = 0;
  int _activeUsers = 0;
  int _todayAbsen = 0;
  int _pendingLeaves = 0;

  Map<String, int> _planDistribution = {};
  List<dynamic> _recentTenants = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final opt = Options(headers: {'x-super-admin-key': AppConfig.superAdminKey});
      
      // 1. Fetch Tenants
      final tenantsRes = await DioClient().dio.get('/superadmin/tenants', options: opt);
      final List tenants = tenantsRes.data['data'] ?? [];
      _totalTenants = tenants.length;
      
      // Calculate plan distribution
      _planDistribution = {};
      for (var t in tenants) {
        final planName = t['subscription_plans']?['name']?.toString() ?? 'Free';
        _planDistribution[planName] = (_planDistribution[planName] ?? 0) + 1;
      }

      // Save recent tenants
      _recentTenants = tenants.take(4).toList();

      // 2. Fetch Users
      final usersRes = await DioClient().dio.get('/superadmin/users', options: opt);
      final List users = usersRes.data['data'] ?? [];
      _activeUsers = users.where((u) => u['status_aktif'] == true).length;

      // 3. Fetch Attendance
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final absensiRes = await DioClient().dio.get('/superadmin/absensi', options: opt);
      final List absensi = absensiRes.data['data'] ?? [];
      _todayAbsen = absensi.where((a) => a['tanggal'] == todayStr).length;

      // 4. Fetch Leaves
      final leavesRes = await DioClient().dio.get('/superadmin/izin', options: opt);
      final List leaves = leavesRes.data['data'] ?? [];
      _pendingLeaves = leaves.where((l) => l['status']?.toString().toLowerCase() == 'pending').length;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Gagal memuat statistik overview: $e';
        });
      }
    }
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
        onRetry: _fetchStats,
      );
    }

    final isWide = MediaQuery.of(context).size.width > 700;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Tr.get('overview', lang),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),

          // ── Stat Grid ──────────────────────────────────────────────────────
          GridView.count(
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: isWide ? 1.4 : 1.2,
            children: [
              StatCard(
                label: Tr.get('total_tenants', lang),
                value: '$_totalTenants',
                color: Colors.blue,
                icon: Icons.domain,
              ),
              StatCard(
                label: Tr.get('active_users', lang),
                value: '$_activeUsers',
                color: Colors.green,
                icon: Icons.people,
              ),
              StatCard(
                label: Tr.get('today_attendance_cnt', lang),
                value: '$_todayAbsen',
                color: Colors.purple,
                icon: Icons.fingerprint,
              ),
              StatCard(
                label: Tr.get('pending_leaves_cnt', lang),
                value: '$_pendingLeaves',
                color: Colors.amber,
                icon: Icons.pending_actions,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Secondary Layout ───────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Plan Distribution
              Expanded(
                flex: isWide ? 3 : 1,
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Plan Distribution',
                        subtitle: 'Penyebaran paket subscription',
                      ),
                      const SizedBox(height: 16),
                      if (_planDistribution.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('Tidak ada data plan')),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _planDistribution.length,
                          separatorBuilder: (c, i) => const Divider(),
                          itemBuilder: (context, index) {
                            final key = _planDistribution.keys.elementAt(index);
                            final val = _planDistribution[key] ?? 0;
                            final percent = _totalTenants > 0 ? (val / _totalTenants) : 0.0;
                            
                            Color pColor = Colors.grey;
                            if (key.toLowerCase() == 'free') pColor = Colors.blue;
                            if (key.toLowerCase() == 'pro') pColor = Colors.orange;
                            if (key.toLowerCase() == 'enterprise') pColor = Colors.red;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        key,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '$val tenant (${(percent * 100).toStringAsFixed(0)}%)',
                                        style: const TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                      color: pColor,
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              if (isWide) const SizedBox(width: 24),
              // Right Column: Recent Tenants (Desktop only)
              if (isWide)
                Expanded(
                  flex: 4,
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Tenants Baru',
                          subtitle: 'Tenant yang baru bergabung',
                        ),
                        const SizedBox(height: 16),
                        if (_recentTenants.isEmpty)
                          const Center(child: Text('Belum ada tenant'))
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _recentTenants.length,
                            itemBuilder: (context, index) {
                              final t = _recentTenants[index];
                              final plan = t['subscription_plans']?['name'] ?? 'Free';
                              final status = t['subscription_status'] ?? 'active';

                              return ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.domain, color: Colors.blue),
                                ),
                                title: Text(
                                  t['name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('${t['subdomain']}.siabsen.id'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        plan,
                                        style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    StatusBadge(status: status, lang: lang),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
