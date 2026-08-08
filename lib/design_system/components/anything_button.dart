/// Anything primary button component.
///
/// Pill-shaped button following the Anything design language.
/// Supports light and dark themes, disabled states, and loading.
library;

import 'package:flutter/material.dart';
import '../tokens/motion.dart';

/// Anything primary button.
class AnythingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isCompact;

  const AnythingButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // ACCESSIBILITY (IS-P03 Phase 5). While loading, the label is replaced by
    // a spinner -- which leaves a screen-reader user with a button that has no
    // name. `Semantics` restores the name and announces the busy state, and
    // `excludeSemantics` stops the bare CircularProgressIndicator adding a
    // second, meaningless node.
    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: isLoading ? '$label, loading' : label,
      excludeSemantics: isLoading,
      child: AnimatedScale(
        scale: onPressed != null ? 1.0 : 0.98,
        duration: AnythingDurations.fast,
        child: SizedBox(
          height: isCompact ? 40 : 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              disabledBackgroundColor: colorScheme.primary.withAlpha(128),
              disabledForegroundColor: colorScheme.onPrimary.withAlpha(128),
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 20 : 32,
                vertical: 0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9999),
              ),
              textStyle: TextStyle(
                fontSize: isCompact ? 14 : 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.01,
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18),
                        const SizedBox(width: 8),
                      ],
                      // ACCESSIBILITY (IS-P03 Phase 5). MEASURED DEFECT: at a
                      // 2.0x text scale this Row overflowed by 184 pixels,
                      // because a bare Text inside a MainAxisSize.min Row
                      // demands its full intrinsic width. Android allows font
                      // scaling well above 1.0, so this was broken for every
                      // user who needs larger type -- silently, because an
                      // overflow paints a warning rather than throwing.
                      //
                      // Flexible + ellipsis keeps the button intact. The full
                      // label is still ANNOUNCED: the Semantics wrapper above
                      // carries it, so a screen reader is unaffected by the
                      // visual truncation.
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Anything ghost/secondary button.
class AnythingGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AnythingGhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.01,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}
