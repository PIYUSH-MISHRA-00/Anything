/// Typography tokens for the Anything design system.
///
/// Extracted from Google Stitch design exports.
/// Light theme uses Public Sans + Inter.
/// Dark theme uses Manrope + Inter + Geist.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale for the Anything design system.
///
/// Canonical baseline: Public Sans for headlines, Inter for body/labels.
class AnythingTypography {
  AnythingTypography._();

  // --- Font Families ---

  /// Primary headline font (light theme).
  static TextStyle get headlineLg => GoogleFonts.publicSans(
    fontSize: 48,
    height: 1.1,
    letterSpacing: -0.02,
    fontWeight: FontWeight.w600,
  );

  /// Mobile headline font (light theme).
  static TextStyle get headlineLgMobile => GoogleFonts.publicSans(
    fontSize: 32,
    height: 1.2,
    letterSpacing: -0.01,
    fontWeight: FontWeight.w600,
  );

  /// Medium headline (light theme).
  static TextStyle get headlineMd => GoogleFonts.publicSans(
    fontSize: 24,
    height: 1.3,
    letterSpacing: 0,
    fontWeight: FontWeight.w500,
  );

  /// Large body text.
  static TextStyle get bodyLg => GoogleFonts.inter(
    fontSize: 18,
    height: 1.6,
    letterSpacing: 0.01,
    fontWeight: FontWeight.w400,
  );

  /// Medium body text.
  static TextStyle get bodyMd => GoogleFonts.inter(
    fontSize: 16,
    height: 1.5,
    letterSpacing: 0.01,
    fontWeight: FontWeight.w400,
  );

  /// Small label text.
  static TextStyle get labelSm => GoogleFonts.inter(
    fontSize: 12,
    height: 1.2,
    letterSpacing: 0.08,
    fontWeight: FontWeight.w600,
  );

  // --- Dark Theme Variants ---

  /// Dark theme display font.
  static TextStyle get displayLgDark => GoogleFonts.manrope(
    fontSize: 56,
    height: 64 / 56,
    letterSpacing: -0.02,
    fontWeight: FontWeight.w700,
  );

  /// Dark theme headline font.
  static TextStyle get headlineLgDark => GoogleFonts.manrope(
    fontSize: 32,
    height: 40 / 32,
    letterSpacing: -0.01,
    fontWeight: FontWeight.w600,
  );

  /// Dark theme mobile headline.
  static TextStyle get headlineLgMobileDark => GoogleFonts.manrope(
    fontSize: 24,
    height: 32 / 24,
    letterSpacing: -0.01,
    fontWeight: FontWeight.w600,
  );

  /// Dark theme medium title.
  static TextStyle get titleMdDark => GoogleFonts.manrope(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w500,
  );

  /// Dark theme body text (slightly smaller).
  static TextStyle get bodyLgDark => GoogleFonts.inter(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// Dark theme medium body.
  static TextStyle get bodyMdDark => GoogleFonts.inter(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
}

/// Build a Flutter TextTheme for the Anything design system.
TextTheme buildAnythingTextTheme({required bool isDark}) {
  if (isDark) {
    return TextTheme(
      displayLarge: AnythingTypography.displayLgDark,
      headlineLarge: AnythingTypography.headlineLgDark,
      headlineMedium: AnythingTypography.headlineLgMobileDark,
      titleMedium: AnythingTypography.titleMdDark,
      bodyLarge: AnythingTypography.bodyLgDark,
      bodyMedium: AnythingTypography.bodyMdDark,
      labelSmall: AnythingTypography.labelSm,
    );
  }

  return TextTheme(
    headlineLarge: AnythingTypography.headlineLg,
    headlineMedium: AnythingTypography.headlineLgMobile,
    titleMedium: AnythingTypography.headlineMd,
    bodyLarge: AnythingTypography.bodyLg,
    bodyMedium: AnythingTypography.bodyMd,
    labelSmall: AnythingTypography.labelSm,
  );
}
