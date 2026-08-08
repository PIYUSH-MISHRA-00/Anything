/// Anything empty state component.
///
/// Intentional empty states that teach the user what can happen next.
library;

import 'package:flutter/material.dart';
import 'anything_button.dart';

/// Empty state display.
class AnythingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AnythingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // ACCESSIBILITY (IS-P03 Phase 5). MEASURED DEFECT: at a 2.0x text scale
    // this Column overflowed its viewport vertically. Android allows font
    // scaling well above 1.0, and an empty state is the FIRST thing a new
    // user sees -- so this was broken at exactly the worst moment, silently,
    // because an overflow paints a warning rather than throwing.
    //
    // SingleChildScrollView is the standard remedy: content that fits stays
    // centred, and content that does not becomes scrollable instead of
    // clipped. `Center` inside keeps the centred look at normal scale.
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ACCESSIBILITY (IS-P03 Phase 5). The icon is decorative -- the
              // title and message already say everything it conveys. Excluding
              // it stops a screen reader announcing an unnamed graphic before
              // the text that matters.
              ExcludeSemantics(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: colorScheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                semanticsLabel: title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                AnythingButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
