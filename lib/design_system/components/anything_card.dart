/// Anything card components.
///
/// Cards are the primary vessel for information in Anything.
/// Supports light/dark themes with ambient shadows.
library;

import 'package:flutter/material.dart';
import '../tokens/shadows.dart';

/// Standard Anything card.
class AnythingCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final Color? color;
  final BorderRadiusGeometry? borderRadius;

  const AnythingCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.elevation,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? colorScheme.surfaceContainer,
        borderRadius:
            borderRadius ??
            BorderRadius.circular(
              theme.brightness == Brightness.dark ? 16 : 32,
            ),
        boxShadow: AnythingShadows.ambient,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius:
            borderRadius ??
            BorderRadius.circular(
              theme.brightness == Brightness.dark ? 16 : 32,
            ),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              (borderRadius ??
                      BorderRadius.circular(
                        theme.brightness == Brightness.dark ? 16 : 32,
                      ))
                  as BorderRadius?,
          child: Padding(
            padding:
                padding ??
                EdgeInsets.all(theme.brightness == Brightness.dark ? 16 : 32),
            child: child,
          ),
        ),
      ),
    );

    return card;
  }
}

/// Anything glass card — used for floating surfaces.
class AnythingGlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const AnythingGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xB30B1326) // 70% opacity dark surface
            : const Color(0xB3FCF9F8), // 70% opacity light surface
        borderRadius: BorderRadius.circular(isDark ? 16 : 32),
        border: Border.all(
          color: isDark
              ? const Color(0x1AFFFFFF) // 10% white
              : const Color(0x4DFFFFFF), // 30% white
        ),
        boxShadow: AnythingShadows.ambientGlow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isDark ? 16 : 32),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isDark ? 16 : 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isDark ? 16 : 32),
            child: BackdropFilter(
              filter: const ColorFilter.matrix([
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                0,
                18,
                -7,
              ]),
              child: Padding(
                padding: padding ?? EdgeInsets.all(isDark ? 16 : 32),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
