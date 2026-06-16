import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// State untuk realtime events
class RealtimeState {
  final List<Map<String, dynamic>> events;
  final int unreadCount;
  final bool isListening;

  const RealtimeState({
    this.events = const [],
    this.unreadCount = 0,
    this.isListening = false,
  });

  RealtimeState copyWith({
    List<Map<String, dynamic>>? events,
    int? unreadCount,
    bool? isListening,
  }) {
    return RealtimeState(
      events: events ?? this.events,
      unreadCount: unreadCount ?? this.unreadCount,
      isListening: isListening ?? this.isListening,
    );
  }
}

/// Provider untuk mendengarkan perubahan data secara real-time
/// dari Supabase Realtime (Postgres Changes).
///
/// Fitur:
///   - Notifikasi izin baru/diupdate untuk admin
///   - Notifikasi absensi masuk untuk monitoring dashboard
///   - Auto-reconnect saat koneksi terputus
class RealtimeNotifier extends StateNotifier<RealtimeState> {
  RealtimeNotifier() : super(const RealtimeState());

  RealtimeChannel? _izinChannel;
  RealtimeChannel? _absensiChannel;
  final SupabaseClient _client = Supabase.instance.client;

  /// Mulai subscribe ke channel realtime.
  /// Panggil setelah user berhasil login.
  void startListening() {
    if (state.isListening) return;

    final tenantId = AppConfig.tenantId;

    // ── Channel: Izin ──────────────────────────────────────────────────────
    _izinChannel = _client
        .channel('izin-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'izin',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_tenant',
            value: tenantId,
          ),
          callback: (payload) {
            _handleEvent('izin', payload);
          },
        )
        .subscribe();

    // ── Channel: Absensi ───────────────────────────────────────────────────
    _absensiChannel = _client
        .channel('absensi-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'absensi',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_tenant',
            value: tenantId,
          ),
          callback: (payload) {
            _handleEvent('absensi', payload);
          },
        )
        .subscribe();

    state = state.copyWith(isListening: true);
    debugPrint('[Realtime] Listening started for tenant: $tenantId');
  }

  void _handleEvent(String table, PostgresChangePayload payload) {
    final event = {
      'table': table,
      'eventType': payload.eventType.name,
      'newRecord': payload.newRecord,
      'oldRecord': payload.oldRecord,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final updatedEvents = [event, ...state.events];
    // Simpan max 50 events
    final trimmed =
        updatedEvents.length > 50 ? updatedEvents.sublist(0, 50) : updatedEvents;

    state = state.copyWith(
      events: trimmed,
      unreadCount: state.unreadCount + 1,
    );

    debugPrint('[Realtime] $table ${payload.eventType.name}');
  }

  /// Reset unread counter (saat user membuka halaman notifikasi)
  void markAllRead() {
    state = state.copyWith(unreadCount: 0);
  }

  /// Clear semua events
  void clearEvents() {
    state = state.copyWith(events: [], unreadCount: 0);
  }

  /// Stop listening (saat logout)
  void stopListening() {
    _izinChannel?.unsubscribe();
    _absensiChannel?.unsubscribe();
    _izinChannel = null;
    _absensiChannel = null;
    state = const RealtimeState();
    debugPrint('[Realtime] Listening stopped');
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

final realtimeProvider =
    StateNotifierProvider<RealtimeNotifier, RealtimeState>(
        (ref) => RealtimeNotifier());
