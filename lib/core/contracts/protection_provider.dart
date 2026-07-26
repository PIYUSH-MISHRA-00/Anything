/// Protection Provider boundary for Anything v2.
///
/// This defines the contract through which Anything accesses
/// security and encryption functionality, including the
/// existing Kaalka integration.
///
/// Kaalka uses time as part of its encryption/decryption mechanism.
/// This contract preserves that behavior without coupling
/// business logic to Kaalka's implementation.
///
/// Future UX requirements:
/// - Use Current Time (default)
/// - Choose Custom Date/Time
library;

import 'dart:async';

/// A time seed for Kaalka encryption.
///
/// Kaalka uses time as part of its key derivation.
/// The seed represents a specific point in time.
class TimeSeed {
  /// Hours (0-23).
  final int hours;

  /// Minutes (0-59).
  final int minutes;

  /// Seconds (0-59).
  final int seconds;

  const TimeSeed({
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  /// Creates a seed from the current system time.
  factory TimeSeed.now() {
    final now = DateTime.now();
    return TimeSeed(hours: now.hour, minutes: now.minute, seconds: now.second);
  }

  /// Format as HH:MM:SS string.
  String toSeedString() {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSeed &&
          hours == other.hours &&
          minutes == other.minutes &&
          seconds == other.seconds;

  @override
  int get hashCode => Object.hash(hours, minutes, seconds);
}

/// Mode for time seed generation.
enum TimeSeedMode {
  /// Use current system time (default).
  live,

  /// Use a user-specified custom time.
  custom,
}

/// Configuration for the protection engine.
class ProtectionConfig {
  /// Whether protection is enabled.
  final bool enabled;

  /// Time seed mode.
  final TimeSeedMode timeSeedMode;

  /// Custom time seed (only used when timeSeedMode is custom).
  final TimeSeed? customTimeSeed;

  const ProtectionConfig({
    this.enabled = false,
    this.timeSeedMode = TimeSeedMode.live,
    this.customTimeSeed,
  });

  ProtectionConfig copyWith({
    bool? enabled,
    TimeSeedMode? timeSeedMode,
    TimeSeed? customTimeSeed,
  }) {
    return ProtectionConfig(
      enabled: enabled ?? this.enabled,
      timeSeedMode: timeSeedMode ?? this.timeSeedMode,
      customTimeSeed: customTimeSeed ?? this.customTimeSeed,
    );
  }
}

/// Abstract interface for the protection engine.
///
/// Kaalka implements this contract. Business logic interacts
/// with protection through this boundary.
abstract class ProtectionProvider {
  /// Provider identifier.
  String get providerId;

  /// Whether protection is currently enabled.
  bool get isEnabled;

  /// Get the current protection configuration.
  ProtectionConfig get config;

  /// Update the protection configuration.
  Future<void> updateConfig(ProtectionConfig config);

  /// Encrypt data.
  Future<String> encrypt(String plainText);

  /// Decrypt data.
  Future<String> decrypt(String cipherText);

  /// Generate a time seed string from the given parameters.
  String generateSeed(int hours, int minutes, int seconds);

  /// Generate a seed from the current system time.
  String generateLiveSeed();

  /// Get the current effective time seed.
  TimeSeed getCurrentSeed();
}
