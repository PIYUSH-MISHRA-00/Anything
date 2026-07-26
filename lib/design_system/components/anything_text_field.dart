/// Anything text field components.
///
/// Large, minimal input fields following the Anything design language.
/// Supports light/dark themes, icons, and the universal intent field variant.
library;

import 'package:flutter/material.dart';

/// Standard Anything text field.
class AnythingTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? semanticsLabel;

  const AnythingTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label: semanticsLabel ?? label ?? hint,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
        obscureText: obscureText,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withAlpha(128),
          ),
          labelText: label,
          labelStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: colorScheme.onSurfaceVariant)
              : null,
          suffixIcon: suffixIcon != null
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Icon(suffixIcon, color: colorScheme.onSurfaceVariant),
                )
              : null,
          filled: true,
          fillColor: isDark
              ? colorScheme.surfaceContainer
              : colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isDark ? 8 : 24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isDark ? 8 : 24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isDark ? 8 : 24),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
