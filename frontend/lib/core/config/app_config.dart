/// Konfigurasi app-wide.
/// baseUrl masih dipakai untuk memanggil backend Express
/// (geofencing, QR generation, overtime detection).
class AppConfig {
  /// Backend Express — tetap dipakai untuk business logic berat.
  /// Auto-detect: jika diakses via HTTPS, backend juga pakai HTTPS.
  /// Override manual: --dart-define=BACKEND_URL=https://192.168.x.x:3000/api
  static String get backendUrl {
    const envUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    if (envUrl.isNotEmpty) return envUrl;

    // Auto-detect dari browser URL — supaya HP bisa konek ke backend
    final scheme   = Uri.base.scheme;   // 'http' atau 'https'
    final hostname = Uri.base.host;
    final host     = hostname.isNotEmpty ? hostname : 'localhost';

    // Gunakan scheme yang sama dengan frontend (http→3000, https→3000)
    return '$scheme://$host:3000/api';
  }

  /// Tenant ID — Multi-tenant SaaS.
  /// Prioritas:
  ///   1. --dart-define=TENANT_ID=interia
  ///   2. Auto-detect dari subdomain (e.g. interia.siabsen.id → 'interia')
  ///   3. Default: 'interia'
  static String get tenantId {
    const envTenantId = String.fromEnvironment('TENANT_ID', defaultValue: '');
    if (envTenantId.isNotEmpty) return envTenantId;

    // Auto-detect dari subdomain
    final hostname = Uri.base.host;
    final parts = hostname.split('.');
    // interia.siabsen.id → parts = ['interia', 'siabsen', 'id']
    if (parts.length >= 3 && parts[0] != 'www') {
      return parts[0];
    }

    return 'interia'; // default tenant
  }
}

