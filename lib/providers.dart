import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import './Counter.dart';

// Tema durumu için state sınıfı
class ThemeState {
  final bool isDarkMode;

  ThemeState({required this.isDarkMode});

  ThemeState copyWith({bool? isDarkMode}) {
    return ThemeState(isDarkMode: isDarkMode ?? this.isDarkMode);
  }
}

// Tema için provider
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(ThemeState(isDarkMode: false)) {
    _loadTheme();
  }

  final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF5DADE2),
    scaffoldBackgroundColor: const Color(0xFFF4F7FC),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      secondary: const Color(0xFF5DADE2),
      brightness: Brightness.light,
    ),
  );

  final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF7FB3D5),
    scaffoldBackgroundColor: const Color(0xFF1C2A38),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      secondary: const Color(0xFF7FB3D5),
      brightness: Brightness.dark,
    ),
  );

  Future<void> _loadTheme() async {
    final themeBox = await Hive.openBox('themeBox');
    final isDarkMode = themeBox.get('isDarkMode', defaultValue: false);
    state = ThemeState(isDarkMode: isDarkMode);
  }

  Future<void> toggleTheme() async {
    final themeBox = await Hive.openBox('themeBox');
    await themeBox.put('isDarkMode', !state.isDarkMode);
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }
}

// Dil durumu için state sınıfı
class LocaleState {
  final Locale locale;

  LocaleState({required this.locale});

  LocaleState copyWith({Locale? locale}) {
    return LocaleState(locale: locale ?? this.locale);
  }
}

// Dil için provider
class LocaleNotifier extends StateNotifier<LocaleState> {
  LocaleNotifier() : super(LocaleState(locale: const Locale('tr'))) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final settingsBox = await Hive.openBox('settingsBox');
    final String languageCode = settingsBox.get('languageCode', defaultValue: 'tr');
    state = LocaleState(locale: Locale(languageCode));
  }

  Future<void> setLocale(String languageCode) async {
    final settingsBox = await Hive.openBox('settingsBox');
    await settingsBox.put('languageCode', languageCode);
    state = LocaleState(locale: Locale(languageCode));
  }
}

final counterProvider = StateNotifierProvider<Counter, CounterState>((ref) {
  return Counter();
});

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

final localeProvider = StateNotifierProvider<LocaleNotifier, LocaleState>((ref) {
  return LocaleNotifier();
});
