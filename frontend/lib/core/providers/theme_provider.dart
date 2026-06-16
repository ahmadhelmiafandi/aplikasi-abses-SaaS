import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Dark Mode Provider ────────────────────────────────────────────────────────
class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('dark_mode') ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', state);
  }
}

final darkModeProvider =
    StateNotifierProvider<ThemeNotifier, bool>((ref) => ThemeNotifier());

// ── Language Provider ─────────────────────────────────────────────────────────
class LangNotifier extends StateNotifier<String> {
  LangNotifier() : super('id') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('lang') ?? 'id';
  }

  Future<void> toggle() async {
    state = state == 'id' ? 'en' : 'id';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', state);
  }
}

final langProvider =
    StateNotifierProvider<LangNotifier, String>((ref) => LangNotifier());
