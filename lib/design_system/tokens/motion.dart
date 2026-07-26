/// Motion tokens for the Anything design system.
///
/// Defines reusable animation durations and curves.
/// Anything should feel alive but restrained.
library;

import 'package:flutter/material.dart';

/// Animation duration presets.
class AnythingDurations {
  AnythingDurations._();

  /// Fast transitions (100ms) — micro-interactions, toggles.
  static const Duration fast = Duration(milliseconds: 100);

  /// Standard transitions (200ms) — buttons, cards, general UI.
  static const Duration standard = Duration(milliseconds: 200);

  /// Emphasized transitions (350ms) — page transitions, significant state changes.
  static const Duration emphasized = Duration(milliseconds: 350);

  /// Slow transitions (500ms) — entrance/exit animations.
  static const Duration slow = Duration(milliseconds: 500);

  /// Creation sequence reserved duration (~2-3s) — Experience birth.
  static const Duration creation = Duration(milliseconds: 2500);
}

/// Animation curve presets.
class AnythingCurves {
  AnythingCurves._();

  /// Standard easing — smooth, natural feel.
  static const Curve standard = Curves.easeInOut;

  /// Emphasized easing — more pronounced acceleration.
  static const Curve emphasized = Curves.easeOutCubic;

  /// Decelerate — elements entering the screen.
  static const Curve decelerate = Curves.easeOut;

  /// Accelerate — elements leaving the screen.
  static const Curve accelerate = Curves.easeIn;

  /// Spring-like bounce for playful interactions.
  static const Curve spring = Curves.elasticOut;
}
