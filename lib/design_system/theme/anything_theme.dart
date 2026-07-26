/// Theme configuration for the Anything design system.
///
/// Combines color tokens, typography, and other design tokens
/// into Flutter ThemeData objects for light and dark modes.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/colors.dart';
import '../tokens/radii.dart';
import '../tokens/typography.dart';

/// Creates the Anything light theme.
ThemeData buildAnythingLightTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AnythingColors.primary,
    onPrimary: AnythingColors.onPrimary,
    primaryContainer: AnythingColors.primaryContainer,
    onPrimaryContainer: AnythingColors.onPrimaryContainer,
    secondary: AnythingColors.secondary,
    onSecondary: AnythingColors.onSecondary,
    secondaryContainer: AnythingColors.secondaryContainer,
    onSecondaryContainer: AnythingColors.onSecondaryContainer,
    tertiary: AnythingColors.tertiary,
    onTertiary: AnythingColors.onTertiary,
    tertiaryContainer: AnythingColors.tertiaryContainer,
    onTertiaryContainer: AnythingColors.onTertiaryContainer,
    error: AnythingColors.error,
    onError: AnythingColors.onError,
    errorContainer: AnythingColors.errorContainer,
    onErrorContainer: AnythingColors.onErrorContainer,
    surface: AnythingColors.surface,
    onSurface: AnythingColors.onSurface,
    onSurfaceVariant: AnythingColors.onSurfaceVariant,
    outline: AnythingColors.outline,
    outlineVariant: AnythingColors.outlineVariant,
    shadow: AnythingColors.ambientShadow,
    inverseSurface: AnythingColors.inverseSurface,
    onInverseSurface: AnythingColors.inverseOnSurface,
    surfaceTint: AnythingColors.surfaceTint,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    textTheme: buildAnythingTextTheme(isDark: false),
    scaffoldBackgroundColor: AnythingColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AnythingColors.surface.withAlpha(204),
      elevation: 0,
      scrolledUnderElevation: 1,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: buildAnythingTextTheme(
        isDark: false,
      ).titleMedium?.copyWith(color: AnythingColors.onSurface),
    ),
    cardTheme: CardThemeData(
      color: AnythingColors.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AnythingRadii.card()),
      margin: EdgeInsets.zero,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AnythingColors.primary,
      foregroundColor: AnythingColors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: AnythingRadii.button),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AnythingColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: AnythingRadii.input(),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AnythingRadii.input(),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AnythingRadii.input(),
        borderSide: BorderSide(color: AnythingColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AnythingColors.primary,
        foregroundColor: AnythingColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: AnythingRadii.button),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        elevation: 4,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AnythingColors.surfaceContainerHigh,
      labelStyle: AnythingTypography.labelSm.copyWith(
        color: AnythingColors.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AnythingRadii.chip,
        side: BorderSide(color: AnythingColors.outlineVariant.withAlpha(51)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AnythingColors.surfaceBright.withAlpha(204),
      elevation: 0,
      indicatorColor: AnythingColors.primary,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AnythingTypography.labelSm.copyWith(
            color: AnythingColors.onPrimary,
          );
        }
        return AnythingTypography.labelSm.copyWith(
          color: AnythingColors.secondary,
        );
      }),
    ),
  );
}

/// Creates the Anything dark theme.
ThemeData buildAnythingDarkTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AnythingColorsDark.primary,
    onPrimary: AnythingColorsDark.onPrimary,
    primaryContainer: AnythingColorsDark.primaryContainer,
    onPrimaryContainer: AnythingColorsDark.onPrimaryContainer,
    secondary: AnythingColorsDark.secondary,
    onSecondary: AnythingColorsDark.onSecondary,
    secondaryContainer: AnythingColorsDark.secondaryContainer,
    onSecondaryContainer: AnythingColorsDark.onSecondaryContainer,
    tertiary: AnythingColorsDark.tertiary,
    onTertiary: AnythingColorsDark.onTertiary,
    tertiaryContainer: AnythingColorsDark.tertiaryContainer,
    onTertiaryContainer: AnythingColorsDark.onTertiaryContainer,
    error: AnythingColorsDark.error,
    onError: AnythingColorsDark.onError,
    errorContainer: AnythingColorsDark.errorContainer,
    onErrorContainer: AnythingColorsDark.onErrorContainer,
    surface: AnythingColorsDark.surface,
    onSurface: AnythingColorsDark.onSurface,
    onSurfaceVariant: AnythingColorsDark.onSurfaceVariant,
    outline: AnythingColorsDark.outline,
    outlineVariant: AnythingColorsDark.outlineVariant,
    shadow: Colors.black54,
    inverseSurface: AnythingColorsDark.inverseSurface,
    onInverseSurface: AnythingColorsDark.inverseOnSurface,
    surfaceTint: AnythingColorsDark.surfaceTint,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    textTheme: buildAnythingTextTheme(isDark: true),
    scaffoldBackgroundColor: AnythingColorsDark.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AnythingColorsDark.surface.withAlpha(204),
      elevation: 0,
      scrolledUnderElevation: 1,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: buildAnythingTextTheme(
        isDark: true,
      ).headlineMedium?.copyWith(color: AnythingColorsDark.onSurface),
    ),
    cardTheme: CardThemeData(
      color: AnythingColorsDark.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AnythingRadii.card(isDark: true),
      ),
      margin: EdgeInsets.zero,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AnythingColorsDark.primaryContainer,
      foregroundColor: AnythingColorsDark.onPrimaryContainer,
      shape: RoundedRectangleBorder(borderRadius: AnythingRadii.button),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AnythingColorsDark.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: AnythingRadii.input(isDark: true),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AnythingRadii.input(isDark: true),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AnythingRadii.input(isDark: true),
        borderSide: BorderSide(color: AnythingColorsDark.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AnythingColorsDark.primaryContainer,
        foregroundColor: AnythingColorsDark.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: AnythingRadii.button),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        elevation: 4,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AnythingColorsDark.surfaceContainerHigh,
      labelStyle: AnythingTypography.labelSm.copyWith(
        color: AnythingColorsDark.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AnythingRadii.chip,
        side: BorderSide(
          color: AnythingColorsDark.outlineVariant.withAlpha(51),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AnythingColorsDark.surfaceBright.withAlpha(204),
      elevation: 0,
      indicatorColor: AnythingColorsDark.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AnythingTypography.labelSm.copyWith(
            color: AnythingColorsDark.onPrimaryContainer,
          );
        }
        return AnythingTypography.labelSm.copyWith(
          color: AnythingColorsDark.onSurfaceVariant,
        );
      }),
    ),
  );
}
