import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/realtime_provider.dart';

final notifikasiProvider = FutureProvider.autoDispose((ref) async {
  ref.watch(realtimeProvider);
  return SupabaseService.getNotifikasi();
});

final unreadCountProvider = FutureProvider.autoDispose((ref) async {
  ref.watch(realtimeProvider);
  return SupabaseService.getUnreadCount();
});

class NotifikasiScreen extends ConsumerWidget {
  const NotifikasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang    = ref.watch(langProvider);
    final notifAsync = ref.watch(notifikasiProvider);
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.get('notifications', lang)),
        actions: [
          notifAsync.maybeWhen(
            data: (list) {
              final hasUnread = list.any((n) => n['status_baca'] == false);
              if (!hasUnread) return const SizedBox();
              return TextButton.icon(
                icon: const Icon(Icons.done_all, size: 16),
                label: Text(Tr.get('mark_all_read', lang)),
                onPressed: () async {
                  await SupabaseService.markAllAsRead();
                  ref.invalidate(notifikasiProvider);
                  ref.invalidate(unreadCountProvider);
                },
              );
            },
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notifikasiProvider);
          ref.invalidate(unreadCountProvider);
        },
        child: notifAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.notifications_none_outlined,
                title: Tr.get('no_notifications', lang),
                subtitle: Tr.get('notif_subtitle', lang),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _NotifCard(
                item: list[i],
                lang: lang,
                isDark: isDark,
                onTap: () async {
                  if (list[i]['status_baca'] == false) {
                    await SupabaseService.markAllAsRead();
                    ref.invalidate(notifikasiProvider);
                    ref.invalidate(unreadCountProvider);
                  }
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: Tr.get('error', lang),
            onRetry: () => ref.invalidate(notifikasiProvider),
          ),
        ),
      ),
    );
  }
}

// ── Notifikasi Card ───────────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String lang;
  final bool isDark;
  final VoidCallback onTap;

  const _NotifCard({
    required this.item,
    required this.lang,
    required this.isDark,
    required this.onTap,
  });

  static IconData _icon(String? jenis) {
    switch (jenis) {
      case 'izin':    return Icons.event_available_outlined;
      case 'absensi': return Icons.fingerprint;
      case 'sistem':  return Icons.settings_outlined;
      default:        return Icons.notifications_outlined;
    }
  }

  static Color _color(String? jenis) {
    switch (jenis) {
      case 'izin':    return AppColors.statusIzin;
      case 'absensi': return AppColors.success;
      case 'sistem':  return AppColors.primary;
      default:        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread  = item['status_baca'] == false;
    final judul     = item['judul']?.toString() ?? '';
    final pesan     = item['pesan']?.toString() ?? '';
    final jenis     = item['jenis']?.toString();
    final createdAt = item['created_at']?.toString();
    final color     = _color(jenis);

    String timeAgo = '';
    if (createdAt != null) {
      try {
        final dt  = DateTime.parse(createdAt).toLocal();
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 60) {
          timeAgo = lang == 'id'
              ? '${diff.inMinutes} ${Tr.get("menit_lalu", lang)}'
              : '${diff.inMinutes} ${Tr.get("menit_lalu", lang)}';
        } else if (diff.inHours < 24) {
          timeAgo = lang == 'id'
              ? '${diff.inHours} ${Tr.get("jam_lalu", lang)}'
              : '${diff.inHours} ${Tr.get("jam_lalu", lang)}';
        } else {
          final locale = lang == 'id' ? 'id_ID' : 'en_US';
          timeAgo = DateFormat('d MMM, HH:mm', locale).format(dt);
        }
      } catch (_) {}
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUnread
                ? (isDark
                    ? AppColors.primary.withOpacity(0.08)
                    : AppColors.primaryLight)
                : (isDark ? AppColors.darkSurface : AppColors.surface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? AppColors.primary.withOpacity(0.25)
                  : (isDark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon(jenis), color: color, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            judul,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pesan,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (timeAgo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
