/// Spacing tokens for the Anything design system.
///
/// Extracted from Google Stitch design exports.
/// Base unit: 8px.
library;

import 'package:flutter/material.dart';

/// Spacing constants for the Anything design system.
class AnythingSpacing {
  AnythingSpacing._();

  /// Base unit (8px).
  static const double unit = 8;

  /// Small spacing (16px) — internal card padding, small vertical spacers.
  static const double stackSm = 16;

  /// Gutter (24px) — gap between grid items and cards.
  static const double gutter = 24;

  /// Medium spacing (32px) — horizontal page margins, section vertical spacing.
  static const double stackMd = 32;

  /// Container padding (32px) — alias for stackMd.
  static const double containerPadding = 32;

  /// Large spacing (64px) — major section separation.
  static const double stackLg = 64;

  // --- EdgeInsets presets ---

  /// Horizontal page margin.
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: containerPadding,
  );

  /// Standard card padding.
  static const EdgeInsets cardPadding = EdgeInsets.all(stackSm);

  /// Large card padding.
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(containerPadding);

  /// Screen padding (top + horizontal).
  static const EdgeInsets screenPadding = EdgeInsets.only(
    top: stackMd,
    left: containerPadding,
    right: containerPadding,
  );

  /// Bottom padding to clear floating nav.
  static const EdgeInsets bottomNavClearance = EdgeInsets.only(bottom: 100);
}

/// Padding presets for the Anything design system.
class AnythingPadding {
  AnythingPadding._();

  /// Compact padding (16px) — phone edges.
  static const double compact = 16;

  /// Regular padding (24px) — standard content padding.
  static const double regular = 24;

  /// Wide padding (32px) — tablet/desktop content.
  static const double wide = 32;

  /// Section spacing (64px) — between major sections.
  static const double section = 64;
}
