import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themeValue = prefs.getString('theme_mode');
    if (themeValue != null) {
      if (themeValue == 'light') _themeMode = ThemeMode.light;
      if (themeValue == 'dark') _themeMode = ThemeMode.dark;
      if (themeValue == 'system') _themeMode = ThemeMode.system;
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    String value = 'system';
    if (mode == ThemeMode.light) value = 'light';
    if (mode == ThemeMode.dark) value = 'dark';
    await prefs.setString('theme_mode', value);
    notifyListeners();
  }

  String getThemeName(BuildContext context) {
    if (_themeMode == ThemeMode.light) return "Light";
    if (_themeMode == ThemeMode.dark) return "Dark";
    return "System Default";
  }
}
