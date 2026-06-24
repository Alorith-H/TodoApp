import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app settings, loaded from / saved to SharedPreferences.
class AppSettings {
  final ThemeMode themeMode;
  final int seedColorValue;
  final int defaultDueHour;
  final int defaultDueMinute;
  final bool showCompleted;
  final String sortMode;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedColorValue = 0xFF2196F3,
    this.defaultDueHour = 18,
    this.defaultDueMinute = 0,
    this.showCompleted = true,
    this.sortMode = 'due_date',
  });

  Color get seedColor => Color(seedColorValue);

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? seedColorValue,
    int? defaultDueHour,
    int? defaultDueMinute,
    bool? showCompleted,
    String? sortMode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      defaultDueHour: defaultDueHour ?? this.defaultDueHour,
      defaultDueMinute: defaultDueMinute ?? this.defaultDueMinute,
      showCompleted: showCompleted ?? this.showCompleted,
      sortMode: sortMode ?? this.sortMode,
    );
  }

  // ── SharedPreferences keys ──

  static const String _keyThemeMode = 'theme_mode';
  static const String _keySeedColor = 'seed_color';
  static const String _keyDefaultDueHour = 'default_due_hour';
  static const String _keyDefaultDueMinute = 'default_due_minute';
  static const String _keyShowCompleted = 'show_completed';
  static const String _keySortMode = 'sort_mode';

  /// Load settings from SharedPreferences. Returns defaults for any missing key.
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: _parseThemeMode(prefs.getString(_keyThemeMode)),
      seedColorValue: prefs.getInt(_keySeedColor) ?? 0xFF2196F3,
      defaultDueHour: prefs.getInt(_keyDefaultDueHour) ?? 18,
      defaultDueMinute: prefs.getInt(_keyDefaultDueMinute) ?? 0,
      showCompleted: prefs.getBool(_keyShowCompleted) ?? true,
      sortMode: prefs.getString(_keySortMode) ?? 'due_date',
    );
  }

  /// Persist this settings object to SharedPreferences.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _themeModeToString(themeMode));
    await prefs.setInt(_keySeedColor, seedColorValue);
    await prefs.setInt(_keyDefaultDueHour, defaultDueHour);
    await prefs.setInt(_keyDefaultDueMinute, defaultDueMinute);
    await prefs.setBool(_keyShowCompleted, showCompleted);
    await prefs.setString(_keySortMode, sortMode);
  }

  static ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

/// A named seed-color option for the theme-color picker.
class SeedColorOption {
  final String name;
  final int value;
  Color get color => Color(value);

  const SeedColorOption(this.name, this.value);

  static const List<SeedColorOption> options = [
    SeedColorOption('蓝色', 0xFF2196F3),
    SeedColorOption('绿色', 0xFF4CAF50),
    SeedColorOption('紫色', 0xFF9C27B0),
    SeedColorOption('橙色', 0xFFFF9800),
    SeedColorOption('红色', 0xFFF44336),
    SeedColorOption('青色', 0xFF00BCD4),
    SeedColorOption('粉色', 0xFFE91E63),
    SeedColorOption('靛蓝', 0xFF3F51B5),
    SeedColorOption('青绿', 0xFF009688),
    SeedColorOption('琥珀', 0xFFFFC107),
  ];
}
