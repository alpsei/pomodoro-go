import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class ThemeState {
  final bool isDarkMode;
  final bool isLoading;

  const ThemeState({required this.isDarkMode, this.isLoading = false});

  ThemeState copyWith({bool? isDarkMode, bool? isLoading}) {
    return ThemeState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ThemeProvider extends StateNotifier<ThemeState> {
  Box? _themeBox;

  ThemeProvider() : super(const ThemeState(
    isDarkMode: false,
    isLoading: true,
  )) {
    _initializeBox();
  }

  Future<void> _initializeBox() async {
    try {
      if (!Hive.isBoxOpen('themeBox')) {
        _themeBox = await Hive.openBox('themeBox');
      } else {
        _themeBox = Hive.box('themeBox');
      }

      if (_themeBox != null) {
        final savedIsDarkMode = _themeBox!.get('isDarkMode');
        state = ThemeState(
          isDarkMode: savedIsDarkMode is bool ? savedIsDarkMode : false,
          isLoading: false,
        );
      }
      debugPrint('Theme verileri yüklendi');
    } catch (e) {
      debugPrint("Theme kutusu yükleme hatası: $e");
      state = state.copyWith(
        isDarkMode: false,
        isLoading: false,
      );
    }
  }

  void toggleTheme() async {
    try {
      if (_themeBox != null && _themeBox!.isOpen) {
        state = state.copyWith(isDarkMode: !state.isDarkMode);
        await _themeBox!.put('isDarkMode', state.isDarkMode);
        debugPrint("Theme verileri kaydedildi: ${state.isDarkMode}");
      }
    } catch (e) {
      debugPrint("Theme kaydetme hatası: $e");
      state = state.copyWith(isDarkMode: !state.isDarkMode); // Hata durumunda geri al
    }
  }

  ThemeData get lightTheme => ThemeData.light().copyWith(
    scaffoldBackgroundColor: const Color(0xFFF4F7FC),
    textTheme: ThemeData.light().textTheme.apply(fontFamily: 'PlaywriteGBS'),
  );

  ThemeData get darkTheme => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF1C2A38),
    textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'PlaywriteGBS'),
  );
}
