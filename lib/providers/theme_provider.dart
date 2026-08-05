import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مزود حالة الثيم (فاتح/داكن)
class ThemeProvider with ChangeNotifier {
  static const String _prefKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// تحميل التفضيل المحفوظ
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// تبديل الثيم
  Future<void> toggle() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }

  /// تعيين ثيم معين
  Future<void> setDarkMode(bool dark) async {
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, dark ? 'dark' : 'light');
    } catch (_) {}
  }
}
