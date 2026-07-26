/// Layout tokens for the Anything design system.
///
/// Defines responsive breakpoints, content widths, and safe zones.
library;

/// Responsive breakpoints.
class AnythingBreakpoints {
  AnythingBreakpoints._();

  /// Compact: phones in portrait (< 600px).
  static const double compact = 600;

  /// Medium: tablets, phones in landscape (600-1200px).
  static const double medium = 1200;

  /// Expanded: desktop (> 1200px).
  static const double expanded = 1200;
}

/// Content width constraints.
class AnythingContentWidth {
  AnythingContentWidth._();

  /// Maximum content width for readable text.
  static const double maxContent = 600;

  /// Maximum width for the entire layout on large screens.
  static const double maxLayout = 1440;

  /// Minimum touch target size (48dp per Material spec).
  static const double minTouchTarget = 48;
}

/// Padding presets.
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

/// Navigation dimensions.
class AnythingNavigation {
  AnythingNavigation._();

  /// Bottom navigation bar height.
  static const double bottomNavHeight = 80;

  /// Floating bottom nav height.
  static const double floatingNavHeight = 64;

  /// Top app bar height.
  static const double topBarHeight = 64;

  /// Floating nav horizontal margin.
  static const double floatingNavMargin = 16;

  /// Floating nav bottom offset.
  static const double floatingNavBottomOffset = 32;
}
