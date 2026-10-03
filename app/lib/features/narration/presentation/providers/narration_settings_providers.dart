import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted narration defaults, configurable from the Settings screen and read
/// when a narration session starts.

/// How many "head start" sections (units) to pre-render before playback begins.
/// Larger = longer wait up front but smoother, longer-lasting playback before
/// it needs to catch up. Persisted across launches.
class HeadStartNotifier extends StateNotifier<int> {
  HeadStartNotifier() : super(_default) {
    _load();
  }

  static const String _prefsKey = 'narration_head_start';
  static const int _default = 8;
  static const int min = 1;
  static const int max = 40;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_prefsKey);
    if (stored != null) state = stored.clamp(min, max);
  }

  Future<void> set(int value) async {
    final clamped = value.clamp(min, max);
    if (clamped == state) return;
    state = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, clamped);
  }
}

final headStartProvider = StateNotifierProvider<HeadStartNotifier, int>(
  (ref) => HeadStartNotifier(),
);

/// Default playback speed for new narration sessions. Persisted across launches;
/// the in-player speed control still adjusts the live session independently.
class NarrationSpeedNotifier extends StateNotifier<double> {
  NarrationSpeedNotifier() : super(_default) {
    _load();
  }

  static const String _prefsKey = 'narration_speed';
  static const double _default = 1;

  /// The speeds offered in the UI.
  static const List<double> options = [0.75, 1, 1.25, 1.5, 1.75, 2];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_prefsKey);
    if (stored != null && options.contains(stored)) state = stored;
  }

  Future<void> set(double value) async {
    if (!options.contains(value) || value == state) return;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, value);
  }
}

final narrationSpeedProvider =
    StateNotifierProvider<NarrationSpeedNotifier, double>(
      (ref) => NarrationSpeedNotifier(),
    );

/// Whether the sleep timer is enabled. Persisted across launches.
class SleepTimerEnabledNotifier extends StateNotifier<bool> {
  SleepTimerEnabledNotifier() : super(false) {
    _load();
  }

  static const String _key = 'sleep_timer_enabled';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_key);
    if (stored != null) state = stored;
  }

  Future<void> set(bool value) async {
    if (value == state) return;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final sleepTimerEnabledProvider =
    StateNotifierProvider<SleepTimerEnabledNotifier, bool>(
      (ref) => SleepTimerEnabledNotifier(),
    );

/// Duration (in seconds) of inactivity before the sleep timer fires.
/// Persisted across launches.
class SleepTimerTimeoutNotifier extends StateNotifier<int> {
  SleepTimerTimeoutNotifier() : super(_default) {
    _load();
  }

  static const String _key = 'sleep_timer_timeout_seconds';
  static const String _legacyKey = 'sleep_timer_timeout_minutes';
  static const int _default = 15 * 60;

  /// Timeout options in seconds, including short values for testing.
  static const List<int> options = [
    30,
    60,
    5 * 60,
    10 * 60,
    15 * 60,
    20 * 60,
    30 * 60,
    60 * 60,
  ];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedSeconds = prefs.getInt(_key);
    if (storedSeconds != null && options.contains(storedSeconds)) {
      state = storedSeconds;
      return;
    }

    // Preserve the original minute-based setting if it was saved by an earlier
    // build of the sleep timer feature.
    final storedMinutes = prefs.getInt(_legacyKey);
    if (storedMinutes != null && options.contains(storedMinutes * 60)) {
      state = storedMinutes * 60;
      await prefs.setInt(_key, state);
    }
  }

  Future<void> set(int value) async {
    if (!options.contains(value) || value == state) return;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value);
  }
}

final sleepTimerTimeoutProvider =
    StateNotifierProvider<SleepTimerTimeoutNotifier, int>(
      (ref) => SleepTimerTimeoutNotifier(),
    );
