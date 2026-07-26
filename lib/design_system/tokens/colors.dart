/// Color tokens for the Anything design system.
///
/// Extracted from Google Stitch design exports.
/// These tokens define the complete color palette for light and dark themes.
library;

import 'package:flutter/material.dart';

/// Anything color tokens — light theme.
///
/// Based on Material 3 warm neutral palette with deep indigo primary.
class AnythingColors {
  AnythingColors._();

  // --- Primary ---
  static const Color primary = Color(0xFF11278A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF2E41A1);
  static const Color onPrimaryContainer = Color(0xFFAAB6FF);
  static const Color inversePrimary = Color(0xFFBAC3FF);
  static const Color primaryFixed = Color(0xFFDEE0FF);
  static const Color primaryFixedDim = Color(0xFFBAC3FF);
  static const Color onPrimaryFixed = Color(0xFF00105A);
  static const Color onPrimaryFixedVariant = Color(0xFF2A3D9D);

  // --- Secondary ---
  static const Color secondary = Color(0xFF5E5F5C);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE0E0DC);
  static const Color onSecondaryContainer = Color(0xFF626360);

  // --- Tertiary ---
  static const Color tertiary = Color(0xFF34342E);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF4B4B44);
  static const Color onTertiaryContainer = Color(0xFFBCBBB2);

  // --- Error ---
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // --- Surface ---
  static const Color background = Color(0xFFFCF9F8);
  static const Color onBackground = Color(0xFF1C1B1B);
  static const Color surface = Color(0xFFFCF9F8);
  static const Color surfaceDim = Color(0xFFDCD9D9);
  static const Color surfaceBright = Color(0xFFFCF9F8);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF6F3F2);
  static const Color surfaceContainer = Color(0xFFF0EDED);
  static const Color surfaceContainerHigh = Color(0xFFEAE7E7);
  static const Color surfaceContainerHighest = Color(0xFFE5E2E1);
  static const Color surfaceVariant = Color(0xFFE5E2E1);
  static const Color onSurface = Color(0xFF1C1B1B);
  static const Color onSurfaceVariant = Color(0xFF454652);
  static const Color surfaceTint = Color(0xFF4456B6);

  // --- Outline ---
  static const Color outline = Color(0xFF757683);
  static const Color outlineVariant = Color(0xFFC5C5D4);

  // --- Inverse ---
  static const Color inverseSurface = Color(0xFF313030);
  static const Color inverseOnSurface = Color(0xFFF3F0EF);

  // --- Glass panel (light) ---
  static const Color glassPanelBackground = Color(0xB3FCF9F8); // 70% opacity
  static const Color glassPanelBorder = Color(0x4DFFFFFF); // 30% opacity

  // --- Ambient shadow tint ---
  static const Color ambientShadow = Color(0x2611278A); // 15% opacity indigo
}

/// Anything color tokens — dark theme.
///
/// Based on Material 3 deep indigo-charcoal palette.
class AnythingColorsDark {
  AnythingColorsDark._();

  // --- Primary ---
  static const Color primary = Color(0xFFBDC2FF);
  static const Color onPrimary = Color(0xFF131E8C);
  static const Color primaryContainer = Color(0xFF818CF8);
  static const Color onPrimaryContainer = Color(0xFF101B8A);

  // --- Secondary ---
  static const Color secondary = Color(0xFFBAC5F0);
  static const Color onSecondary = Color(0xFF242F52);
  static const Color secondaryContainer = Color(0xFF3A456A);
  static const Color onSecondaryContainer = Color(0xFFA9B4DE);

  // --- Tertiary ---
  static const Color tertiary = Color(0xFFC3C0FF);
  static const Color onTertiary = Color(0xFF272377);
  static const Color tertiaryContainer = Color(0xFF8E8CE4);
  static const Color onTertiaryContainer = Color(0xFF242075);

  // --- Error ---
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // --- Surface ---
  static const Color background = Color(0xFF0B1326);
  static const Color onBackground = Color(0xFFDAE2FD);
  static const Color surface = Color(0xFF0B1326);
  static const Color surfaceDim = Color(0xFF0B1326);
  static const Color surfaceBright = Color(0xFF31394D);
  static const Color surfaceContainerLowest = Color(0xFF060E20);
  static const Color surfaceContainerLow = Color(0xFF131B2E);
  static const Color surfaceContainer = Color(0xFF171F33);
  static const Color surfaceContainerHigh = Color(0xFF222A3D);
  static const Color surfaceContainerHighest = Color(0xFF2D3449);
  static const Color surfaceVariant = Color(0xFF2D3449);
  static const Color onSurface = Color(0xFFDAE2FD);
  static const Color onSurfaceVariant = Color(0xFFC6C5D5);
  static const Color surfaceTint = Color(0xFFBDC2FF);

  // --- Outline ---
  static const Color outline = Color(0xFF908F9E);
  static const Color outlineVariant = Color(0xFF454653);

  // --- Inverse ---
  static const Color inverseSurface = Color(0xFFDAE2FD);
  static const Color inverseOnSurface = Color(0xFF283044);

  // --- Glass panel (dark) ---
  static const Color glassPanelBackground = Color(0xB30B1326); // 70% opacity
  static const Color glassPanelBorder = Color(0x1AFFFFFF); // 10% opacity
}
