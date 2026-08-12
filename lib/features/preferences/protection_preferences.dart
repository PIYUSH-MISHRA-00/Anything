/// Default protection-time preference (IS-P26).
///
/// Kaalka protection is applied PER EXPERIENCE with a time-of-day seed
/// (`hour`/`minute`, seconds pinned to 0 — see `ExperienceProtectionService`).
/// This preference stores the DEFAULT seed the per-Experience Protect action
/// offers, so a user who always wants a fixed protection time does not have to
/// re-pick it every time.
///
/// It NEVER retroactively changes an already-protected Experience: each one
/// stores its own seed in its protected envelope, so recoverability is
/// unaffected. That is the whole reason this is a *default for new
/// protections* and not a global clock override — a global override would make
/// existing protected apps unrecoverable, which is exactly why the previous
/// Settings screen declined to offer one.
///
/// Persisted with SharedPreferences, matching `AnythingThemeNotifier`.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// The resolved default protection-time choice.
class ProtectionTimePreference {
  /// When true, protecting uses the live clock at the moment of protection.
  final bool useCurrentTime;

  /// Fixed time-of-day seed, used only when [useCurrentTime] is false.
  final int hour; // 0–23
  final int minute; // 0–59

  const ProtectionTimePreference({
    required this.useCurrentTime,
    this.hour = 0,
    this.minute = 0,
  });

  /// `HH:MM` for display (24-hour, matching the picker the user sees).
  String get label => useCurrentTime
      ? 'Use current time'
      : '${hour.toString().padLeft(2, '0')}:'
            '${minute.toString().padLeft(2, '0')}';
}

/// Reads/writes the default protection-time preference.
class ProtectionPreferences {
  static const String _modeKey = 'anything_protection_time_mode'; // 0/1
  static const String _hourKey = 'anything_protection_time_hour';
  static const String _minuteKey = 'anything_protection_time_minute';

  const ProtectionPreferences();

  /// Load the default. Absent → `useCurrentTime` (unchanged legacy behavior).
  Future<ProtectionTimePreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = (prefs.getInt(_modeKey) ?? 0) == 1;
    return ProtectionTimePreference(
      useCurrentTime: !custom,
      hour: (prefs.getInt(_hourKey) ?? 0).clamp(0, 23),
      minute: (prefs.getInt(_minuteKey) ?? 0).clamp(0, 59),
    );
  }

  Future<void> setUseCurrentTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, 0);
  }

  /// Persist a fixed time-of-day default. Values are clamped to valid ranges
  /// so an invalid seed can never be written.
  Future<void> setCustomTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, 1);
    await prefs.setInt(_hourKey, hour.clamp(0, 23));
    await prefs.setInt(_minuteKey, minute.clamp(0, 59));
  }
}
