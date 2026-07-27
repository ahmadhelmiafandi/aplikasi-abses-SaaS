import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/config/app_config.dart';

class SuperAdminService {
  static final Options _superOpt = Options(
    headers: {'x-super-admin-key': AppConfig.superAdminKey},
  );

  // ── TENANTS ─────────
  static Future<List<dynamic>> fetchTenants() async {
    try {
      final res = await SupabaseConfig.client
          .from('tenant')
          .select('*, subscription_plans(*), tenant_settings(*)');
      return List<dynamic>.from(res);
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase fetchTenants failed: $e. Trying backend...');
      final res = await DioClient().dio.get('/superadmin/tenants', options: _superOpt);
      return res.data['data'] ?? [];
    }
  }

  static Future<void> createTenant(Map<String, dynamic> payload) async {
    try {
      final tenantData = {
        'name': payload['name'],
        'subdomain': payload['subdomain'],
        'id_plan': payload['id_plan'],
        'subscription_status': payload['status'] ?? 'active',
      };
      final res = await SupabaseConfig.client.from('tenant').insert(tenantData).select().single();
      
      // Save settings if provided
      if (res['id'] != null) {
        await SupabaseConfig.client.from('tenant_settings').upsert({
          'id_tenant': res['id'],
          'office_lat': payload['office_lat'] ?? -6.9826,
          'office_lng': payload['office_lng'] ?? 110.4092,
          'geofence_radius_meter': payload['geofence_radius_meter'] ?? 100,
        });
      }
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase createTenant failed: $e. Fallback to Dio...');
      await DioClient().dio.post('/superadmin/tenants', data: payload, options: _superOpt);
    }
  }

  static Future<void> updateTenant(String id, Map<String, dynamic> payload) async {
    try {
      final tenantData = {
        'name': payload['name'],
        'id_plan': payload['id_plan'],
        'subscription_status': payload['status'],
      };
      await SupabaseConfig.client.from('tenant').update(tenantData).eq('id', id);
      
      await SupabaseConfig.client.from('tenant_settings').upsert({
        'id_tenant': id,
        'office_lat': payload['office_lat'],
        'office_lng': payload['office_lng'],
        'geofence_radius_meter': payload['geofence_radius_meter'],
      });
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase updateTenant failed: $e. Fallback to Dio...');
      await DioClient().dio.put('/superadmin/tenants/$id', data: payload, options: _superOpt);
    }
  }

  static Future<void> deleteTenant(String id) async {
    try {
      await SupabaseConfig.client.from('tenant').delete().eq('id', id);
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase deleteTenant failed: $e. Fallback to Dio...');
      await DioClient().dio.delete('/superadmin/tenants/$id', options: _superOpt);
    }
  }

  // ── PLANS ─────────
  static Future<List<dynamic>> fetchPlans() async {
    try {
      final res = await SupabaseConfig.client.from('subscription_plans').select('*');
      return List<dynamic>.from(res);
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase fetchPlans failed: $e. Trying backend...');
      final res = await DioClient().dio.get('/superadmin/plans', options: _superOpt);
      return res.data['data'] ?? [];
    }
  }

  static Future<void> savePlan({String? id, required Map<String, dynamic> data}) async {
    try {
      if (id == null) {
        await SupabaseConfig.client.from('subscription_plans').insert(data);
      } else {
        await SupabaseConfig.client.from('subscription_plans').update(data).eq('id', id);
      }
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase savePlan failed: $e. Fallback to Dio...');
      if (id == null) {
        await DioClient().dio.post('/superadmin/plans', data: data, options: _superOpt);
      } else {
        await DioClient().dio.put('/superadmin/plans/$id', data: data, options: _superOpt);
      }
    }
  }

  static Future<void> deletePlan(String id) async {
    try {
      await SupabaseConfig.client.from('subscription_plans').delete().eq('id', id);
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase deletePlan failed: $e. Fallback to Dio...');
      await DioClient().dio.delete('/superadmin/plans/$id', options: _superOpt);
    }
  }

  // ── USERS ─────────
  static Future<List<dynamic>> fetchUsers() async {
    try {
      final res = await SupabaseConfig.client
          .from('profiles')
          .select('*, tenants(name)');
      return List<dynamic>.from(res);
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase fetchUsers failed: $e. Trying backend...');
      final res = await DioClient().dio.get('/superadmin/users', options: _superOpt);
      return res.data['data'] ?? [];
    }
  }

  static Future<void> updateUserStatus(String userId, bool active, String role) async {
    try {
      await SupabaseConfig.client
          .from('profiles')
          .update({'status_aktif': active, 'role': role})
          .eq('id', userId);
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase updateUserStatus failed: $e. Fallback to Dio...');
      await DioClient().dio.put('/superadmin/users/$userId/status', data: {'status_aktif': active, 'role': role}, options: _superOpt);
    }
  }

  static Future<void> deleteUser(String userId) async {
    try {
      await SupabaseConfig.client.from('profiles').delete().eq('id', userId);
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase deleteUser failed: $e. Fallback to Dio...');
      await DioClient().dio.delete('/superadmin/users/$userId', options: _superOpt);
    }
  }

  // ── ABSENSI ─────────
  static Future<List<dynamic>> fetchAbsensi() async {
    try {
      final res = await SupabaseConfig.client
          .from('absensi')
          .select('*, profiles(nama, email), shift(nama_shift)');
      return List<dynamic>.from(res);
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase fetchAbsensi failed: $e. Trying backend...');
      final res = await DioClient().dio.get('/superadmin/absensi', options: _superOpt);
      return res.data['data'] ?? [];
    }
  }

  // ── IZIN / CUTI ─────────
  static Future<List<dynamic>> fetchLeaves() async {
    try {
      final res = await SupabaseConfig.client
          .from('izin_cuti')
          .select('*, profiles(nama, email)');
      return List<dynamic>.from(res);
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase fetchLeaves failed: $e. Trying backend...');
      final res = await DioClient().dio.get('/superadmin/izin', options: _superOpt);
      return res.data['data'] ?? [];
    }
  }

  static Future<void> updateLeaveStatus(String id, String status) async {
    try {
      await SupabaseConfig.client
          .from('izin_cuti')
          .update({'status': status})
          .eq('id', id);
    } catch (e) {
      debugPrint('[SuperAdminService] Supabase updateLeaveStatus failed: $e. Fallback to Dio...');
      await DioClient().dio.put('/superadmin/izin/$id/status', data: {'status': status}, options: _superOpt);
    }
  }
}
