import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// HTTP client untuk memanggil backend Express (geofencing, QR, overtime).
/// Token JWT diambil langsung dari Supabase session — tidak perlu storage manual.
class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio _dio;

  static void Function()? onUnauthorized;

  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.backendUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Inject tenant ID untuk multi-tenant isolation
          options.headers['X-Tenant-ID'] = AppConfig.tenantId;

          // Ambil JWT langsung dari Supabase session — works on web & native
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            try {
              await Supabase.instance.client.auth.refreshSession();
              final session = Supabase.instance.client.auth.currentSession;
              if (session != null) {
                e.requestOptions.headers['Authorization'] =
                    'Bearer ${session.accessToken}';
                final cloneReq = await _dio.fetch(e.requestOptions);
                return handler.resolve(cloneReq);
              }
            } catch (_) {
              await Supabase.instance.client.auth.signOut();
              onUnauthorized?.call();
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
