/// Shadow tokens for the Anything design system.
///
/// Extracted from Google Stitch design exports.
library;

import 'package:flutter/material.dart';

import 'colors.dart';

/// Shadow presets for the Anything design system.
class AnythingShadows {
  AnythingShadows._();

  /// Ambient shadow — the signature Anything shadow.
  /// `0 10px 30px -10px rgba(17, 39, 138, 0.15)`
  static List<BoxShadow> get ambient => const [
    BoxShadow(
      color: AnythingColors.ambientShadow,
      blurRadius: 30,
      offset: Offset(0, 10),
      spreadRadius: -10,
    ),
  ];

  /// Enhanced ambient shadow with glow.
  /// `0 10px 40px -10px rgba(17, 39, 138, 0.1), 0 0 20px rgba(17, 39, 138, 0.05)`
  static List<BoxShadow> get ambientGlow => const [
    BoxShadow(
      color: Color(0x1A11278A),
      blurRadius: 40,
      offset: Offset(0, 10),
      spreadRadius: -10,
    ),
    BoxShadow(color: Color(0x0D11278A), blurRadius: 20, offset: Offset.zero),
  ];

  /// Small elevation shadow.
  static List<BoxShadow> get small => const [
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Medium elevation shadow.
  static List<BoxShadow> get medium => const [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Large elevation shadow.
  static List<BoxShadow> get large => const [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Bottom navigation bar shadow.
  static List<BoxShadow> get bottomNav => const [
    BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, -4)),
  ];

  /// Dark theme ambient shadow (deeper, more pronounced).
  static List<BoxShadow> get ambientDark => const [
    BoxShadow(
      color: Color(0x2611278A),
      blurRadius: 40,
      offset: Offset(0, 10),
      spreadRadius: -10,
    ),
    BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset.zero),
  ];
}
