import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/l10n/translations.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../auth/presentation/auth_provider.dart';

import 'panels/overview_panel.dart';
import 'panels/tenants_panel.dart';
import 'panels/plans_panel.dart';
import 'panels/users_panel.dart';
import 'panels/attendance_panel.dart';
import 'panels/leaves_panel.dart';

class SuperAdminDashboardScreen extends ConsumerStatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  ConsumerState<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState
    extends ConsumerState<SuperAdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<String> _menuKeys = [
    'overview',
    'manage_tenants',
    'manage_plans',
    'manage_users',
    'manage_absensi',
    'manage_leaves',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard_outlined,
    Icons.domain,
    Icons.card_membership,
    Icons.people_outline,
    Icons.fingerprint,
    Icons.fact_check_outlined,
  ];

  Widget _buildActivePanel() {
    switch (_selectedIndex) {
      case 0:
        return const OverviewPanel();
      case 1:
        return const TenantsPanel();
      case 2:
        return const PlansPanel();
      case 3:
        return const UsersPanel();
      case 4:
        return const AttendancePanel();
      case 5:
        return const LeavesPanel();
      default:
        return const OverviewPanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final isDark = ref.watch(darkModeProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          Tr.get('superadmin_dashboard', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(darkModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: Icon(lang == 'id' ? Icons.language : Icons.g_translate),
            onPressed: () => ref.read(langProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: AppColors.danger),
            onPressed: () {
              context.go('/');
            },
          ),
        ],
      ),
      drawer: isDesktop
          ? null
          : Drawer(
              child: _buildNavigationList(lang, isMobile: true),
            ),
      body: Row(
        children: [
          if (isDesktop)
            Container(
              width: 260,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                color: isDark ? AppColors.darkSurface : Colors.white,
              ),
              child: _buildNavigationList(lang, isMobile: false),
            ),
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: _buildActivePanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationList(String lang, {required bool isMobile}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (isMobile)
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  radius: 30,
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Super Admin Platform',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  Tr.get('superadmin_dashboard', lang),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Tr.get('superadmin_dashboard', lang),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
        for (int i = 0; i < _menuKeys.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ListTile(
                leading: Icon(
                  _menuIcons[i],
                  color: _selectedIndex == i
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                ),
                title: Text(
                  Tr.get(_menuKeys[i], lang),
                  style: TextStyle(
                    fontWeight: _selectedIndex == i ? FontWeight.bold : FontWeight.w500,
                    color: _selectedIndex == i
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
                  ),
                ),
                selected: _selectedIndex == i,
                selectedTileColor: AppColors.primary,
                onTap: () {
                  setState(() {
                    _selectedIndex = i;
                  });
                  if (isMobile) {
                    Navigator.pop(context); // close drawer
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}
