import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
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
          Center(
            child: InkWell(
              onTap: () => ref.read(langProvider.notifier).toggle(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  lang.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: AppColors.danger),
            tooltip: 'Keluar / Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/');
              }
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

    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Compact header ──
          Container(
            padding: EdgeInsets.only(
              top: isMobile ? MediaQuery.of(context).padding.top + 16 : 20,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            decoration: isMobile
                ? const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  )
                : null,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMobile
                        ? Colors.white.withOpacity(0.15)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: isMobile ? Colors.white : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Super Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isMobile
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Tr.get('superadmin_dashboard', lang),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMobile
                              ? Colors.white.withOpacity(0.7)
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Thin divider ──
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),

          const SizedBox(height: 8),

          // ── Menu items ──
          for (int i = 0; i < _menuKeys.length; i++)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  leading: Icon(
                    _menuIcons[i],
                    size: 20,
                    color: _selectedIndex == i
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                  ),
                  title: Text(
                    Tr.get(_menuKeys[i], lang),
                    style: TextStyle(
                      fontWeight: _selectedIndex == i
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
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
      ),
    );
  }
}
