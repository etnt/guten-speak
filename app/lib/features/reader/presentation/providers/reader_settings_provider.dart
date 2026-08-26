import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/theme/app_theme.dart';

/// Per-page reading preferences: the reading colour scheme and the font scale.
/// Distinct from the global app light/dark chrome (see `themeModeProvider`).
class ReaderSettings {
  const ReaderSettings({
    this.themeMode = AppThemeMode.dark,
    this.fontScale = 1,
  });

  final AppThemeMode themeMode;

  /// Multiplier applied to the base reading font size (clamped 0.8–2.0).
  final double fontScale;

  ReaderSettings copyWith({AppThemeMode? themeMode, double? fontScale}) {
    return ReaderSettings(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.themeMode == themeMode &&
      other.fontScale == fontScale;

  @override
  int get hashCode => Object.hash(themeMode, fontScale);
}

/// Persisted [ReaderSettings], loaded on construction.
class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  ReaderSettingsNotifier() : super(const ReaderSettings()) {
    _load();
  }

  static const String _themeKey = 'reader_theme_mode';
  static const String _fontKey = 'reader_font_scale';
  static const double _minScale = 0.8;
  static const double _maxScale = 2;
  static const double _scaleStep = 0.1;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    final fontScale = prefs.getDouble(_fontKey);
    state = ReaderSettings(
      themeMode: themeIndex != null && themeIndex < AppThemeMode.values.length
          ? AppThemeMode.values[themeIndex]
          : AppThemeMode.dark,
      fontScale: fontScale ?? 1,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<void> increaseFont() => _setFontScale(state.fontScale + _scaleStep);

  Future<void> decreaseFont() => _setFontScale(state.fontScale - _scaleStep);

  Future<void> _setFontScale(double scale) async {
    final clamped = scale.clamp(_minScale, _maxScale).toDouble();
    if (clamped == state.fontScale) return;
    state = state.copyWith(fontScale: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontKey, clamped);
  }
}

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
      (ref) => ReaderSettingsNotifier(),
    );
