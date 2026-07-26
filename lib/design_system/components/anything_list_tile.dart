/// Anything list tile component.
///
/// Used for settings, navigation items, and list content.
library;

import 'package:flutter/material.dart';

/// Anything list tile.
class AnythingListTile extends StatelessWidget {
  final IconData? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const AnythingListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: leading != null
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(leading, size: 20, color: colorScheme.primary),
                )
              : null,
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          trailing:
              trailing ??
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ),
        if (showDivider)
          Divider(height: 1, color: colorScheme.outlineVariant.withAlpha(51)),
      ],
    );
  }
}
