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
  ];

  final List<IconData> _menuIcons = [
    Icons.grid_view_rounded,
    Icons.business_rounded,
    Icons.card_membership_rounded,
    Icons.people_alt_rounded,
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
      default:
        return const OverviewPanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final isDark = ref.watch(darkModeProvider);
    final user = ref.watch(currentUserProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    final activeTitle = Tr.get(_menuKeys[_selectedIndex], lang);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: isDesktop ? 24 : 0,
        title: Row(
          children: [
            Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
            ),
            Text(
              activeTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          // 🌐 Language Switcher Pill
          Center(
            child: InkWell(
              onTap: () => ref.read(langProvider.notifier).toggle(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang == 'id' ? '🇮🇩 ID' : '🇬🇧 EN',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isDark ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 🌙 Dark Mode Toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF475569),
              size: 20,
            ),
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            onPressed: () => ref.read(darkModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 4),
          // 🚪 Logout Button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/');
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: isDesktop
          ? null
          : Drawer(
              child: _buildSidebar(lang, isDark, user, isMobile: true),
            ),
      body: Row(
        children: [
          if (isDesktop)
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: _buildSidebar(lang, isDark, user, isMobile: false),
            ),
          Expanded(
            child: _buildActivePanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(String lang, bool isDark, Map<String, dynamic>? user,
      {required bool isMobile}) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          // ── Brand Header ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: isMobile ? MediaQuery.of(context).padding.top + 16 : 24,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'siAbsen',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SaaS Super Admin',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 16),

          // ── Navigation Menu Items ───────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _menuKeys.length,
              itemBuilder: (ctx, idx) {
                final isSelected = _selectedIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : AppColors.primary.withOpacity(0.2),
                            )
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(
                        _menuIcons[idx],
                        size: 20,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF64748B) : const Color(0xFF64748B)),
                      ),
                      title: Text(
                        Tr.get(_menuKeys[idx], lang),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : AppColors.primary)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
                        ),
                      ),
                      trailing: isSelected
                          ? Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                      onTap: () {
                        setState(() => _selectedIndex = idx);
                        if (isMobile) Navigator.pop(context);
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // ── User Profile Footer ─────────────────────────────────
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (user?['nama']?.toString().isNotEmpty == true)
                        ? user!['nama'][0].toString().toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?['nama']?.toString() ?? 'Super Admin',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        user?['email']?.toString() ?? 'helmikeren211@gmail.com',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
