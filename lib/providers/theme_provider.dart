// // lib/providers/theme_provider.dart (신규 파일)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // 기본값은 시스템 설정
  final String _key = 'theme_mode'; // 저장용 키

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadThemeFromPrefs(); // 앱 시작 시 저장된 테마 불러오기
  }

  // 테마 변경
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveThemeToPrefs();
    notifyListeners();
  }

  // 기기에서 테마 불러오기
  Future<void> _loadThemeFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String theme = prefs.getString(_key) ?? 'system';
    
    if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  // 기기에 테마 저장하기
  Future<void> _saveThemeToPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_themeMode == ThemeMode.dark) {
      prefs.setString(_key, 'dark');
    } else if (_themeMode == ThemeMode.light) {
      prefs.setString(_key, 'light');
    } else {
      prefs.setString(_key, 'system');
    }
  }
}