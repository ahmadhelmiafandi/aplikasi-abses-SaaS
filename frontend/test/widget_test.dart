import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:absensi_app/main.dart';
import 'package:absensi_app/features/auth/presentation/auth_provider.dart';
import 'package:absensi_app/features/auth/presentation/login_screen.dart';
import 'package:absensi_app/core/providers/realtime_provider.dart';

/// Fake AuthNotifier untuk testing tanpa memanggil SDK Supabase asli.
class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.state);

  @override
  Future<void> login(String email, String password) async {
    state = const AuthState(
      status: AuthStatus.authenticated,
      user: {
        'id': 'user-123',
        'email': 'karyawan@interia.com',
        'nama': 'Test Karyawan',
        'role': 'karyawan',
        'status_aktif': true,
      },
    );
  }

  @override
  Future<String?> register({
    required String nama,
    required String email,
    required String password,
    String? nomorHp,
    String? alamat,
  }) async {
    return null;
  }

  @override
  Future<void> reloadProfile() async {}

  @override
  Future<void> logout() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  void updateCachedUser(Map<String, dynamic> updatedData) {}

  @override
  Future<String?> sendPasswordResetEmail(String email) async => null;
}

/// Fake RealtimeNotifier untuk testing tanpa memanggil SDK Supabase asli.
class FakeRealtimeNotifier extends StateNotifier<RealtimeState> implements RealtimeNotifier {
  FakeRealtimeNotifier() : super(const RealtimeState());

  @override
  void startListening() {}

  @override
  void stopListening() {}

  @override
  void markAllRead() {}

  @override
  void clearEvents() {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Splash Screen Renders Correctly', (WidgetTester tester) async {
    // Pasang ProviderScope dengan authProvider di-set ke loading
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) {
            return FakeAuthNotifier(const AuthState(status: AuthStatus.loading)) as AuthNotifier;
          }),
          realtimeProvider.overrideWith((ref) {
            return FakeRealtimeNotifier() as RealtimeNotifier;
          }),
        ],
        child: const MyApp(),
      ),
    );

    // Verifikasi logo/judul pada Splash Screen dirender
    expect(find.text('SiAbsen'), findsOneWidget);
    expect(find.text('Sistem Absensi Karyawan'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Login Screen Renders Correctly when Unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) {
            return FakeAuthNotifier(const AuthState(status: AuthStatus.unauthenticated)) as AuthNotifier;
          }),
          realtimeProvider.overrideWith((ref) {
            return FakeRealtimeNotifier() as RealtimeNotifier;
          }),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );


    // Cari elemen-elemen form input login
    expect(find.byType(TextFormField), findsNWidgets(2)); // Email & Password
    expect(find.text('Alamat Email'), findsOneWidget);
    expect(find.text('Kata Sandi'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget); // Default localization ID
  });

  testWidgets('Login Screen Validation Errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) {
            return FakeAuthNotifier(const AuthState(status: AuthStatus.unauthenticated)) as AuthNotifier;
          }),
          realtimeProvider.overrideWith((ref) {
            return FakeRealtimeNotifier() as RealtimeNotifier;
          }),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Tap tombol Masuk tanpa mengisi form
    await tester.tap(find.text('Masuk'));
    await tester.pump();

    // Verifikasi pesan validasi muncul
    expect(find.text('Email tidak boleh kosong'), findsOneWidget);
    expect(find.text('Password tidak boleh kosong'), findsOneWidget);
  });

  testWidgets('Login Screen Language Button Toggle', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) {
            return FakeAuthNotifier(const AuthState(status: AuthStatus.unauthenticated)) as AuthNotifier;
          }),
          realtimeProvider.overrideWith((ref) {
            return FakeRealtimeNotifier() as RealtimeNotifier;
          }),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Default adalah Bahasa Indonesia (Masuk)
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);

    // Cari tombol bahasa (EN) dan klik
    final langBtn = find.text('EN');
    expect(langBtn, findsOneWidget);
    await tester.tap(langBtn);
    await tester.pumpAndSettle();

    // Verifikasi teks berubah menjadi Bahasa Inggris (Sign In)
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Masuk'), findsNothing);
  });
}
