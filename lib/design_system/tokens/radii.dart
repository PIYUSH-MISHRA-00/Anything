/// Border radius tokens for the Anything design system.
///
/// Extracted from Google Stitch design exports.
/// Light theme: generous radii (16px default).
/// Dark theme: compact radii (8px default).
library;

import 'package:flutter/material.dart';

/// Border radius scale for the Anything design system.
class AnythingRadii {
  AnythingRadii._();

  /// Small radius (8px light / 4px dark).
  static BorderRadius small({bool isDark = false}) =>
      BorderRadius.circular(isDark ? 4 : 8);

  /// Default radius (16px light / 8px dark).
  static BorderRadius medium({bool isDark = false}) =>
      BorderRadius.circular(isDark ? 8 : 16);

  /// Medium radius (24px light / 12px dark).
  static BorderRadius large({bool isDark = false}) =>
      BorderRadius.circular(isDark ? 12 : 24);

  /// Large radius (32px light / 16px dark).
  static BorderRadius xLarge({bool isDark = false}) =>
      BorderRadius.circular(isDark ? 16 : 32);

  /// Extra large radius (48px light / 24px dark).
  static BorderRadius xxLarge({bool isDark = false}) =>
      BorderRadius.circular(isDark ? 24 : 48);

  /// Pill shape (always full).
  static const BorderRadius pill = BorderRadius.all(Radius.circular(9999));

  /// Full circle.
  static const BorderRadius full = BorderRadius.all(Radius.circular(9999));

  // --- Contextual presets ---

  /// Card border radius.
  static BorderRadius card({bool isDark = false}) => xxLarge(isDark: isDark);

  /// Button border radius (always pill).
  static const BorderRadius button = pill;

  /// Input field border radius.
  static BorderRadius input({bool isDark = false}) =>
      BorderRadius.circular(isDark ? 16 : 24);

  /// Chip border radius (always pill).
  static const BorderRadius chip = pill;

  /// Bottom nav border radius.
  static const BorderRadius bottomNav = pill;
}
