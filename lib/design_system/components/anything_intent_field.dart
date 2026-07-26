/// Universal Intent Surface — the most important component in Anything.
///
/// This is the visual and interaction shell only.
/// Kernel processing is NOT implemented in Stage 2.
///
/// The user should see something conceptually equivalent to:
/// "What do you want?"
/// not a technical prompt engineering interface.
library;

import 'package:flutter/material.dart';
import '../tokens/motion.dart';

/// Callback types for the intent field.
typedef IntentSubmittedCallback = void Function(String text);
typedef VoiceRequestedCallback = void Function();
typedef AttachmentRequestedCallback = void Function();

/// The Universal Intent Surface visual shell.
class AnythingIntentField extends StatefulWidget {
  final String hintText;
  final IntentSubmittedCallback? onSubmit;
  final VoiceRequestedCallback? onVoiceTap;
  final AttachmentRequestedCallback? onAttachmentTap;
  final bool isLoading;

  const AnythingIntentField({
    super.key,
    this.hintText = 'What do you want?',
    this.onSubmit,
    this.onVoiceTap,
    this.onAttachmentTap,
    this.isLoading = false,
  });

  @override
  State<AnythingIntentField> createState() => _AnythingIntentFieldState();
}

class _AnythingIntentFieldState extends State<AnythingIntentField>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit?.call(text);
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label: 'Intent input field',
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(isDark ? 8 : 24),
          border: Border.all(
            color: _focusNode.hasFocus
                ? colorScheme.primary.withAlpha(128)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: _focusNode.hasFocus
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withAlpha(26),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Attachment button
            if (widget.onAttachmentTap != null)
              IconButton(
                onPressed: widget.isLoading ? null : widget.onAttachmentTap,
                icon: Icon(
                  Icons.attach_file,
                  color: colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                tooltip: 'Attach file',
              ),

            // Text field
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onSubmitted: (_) => _handleSubmit(),
                enabled: !widget.isLoading,
                style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withAlpha(128),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 16,
                  ),
                ),
              ),
            ),

            // Voice / Submit button
            AnimatedSwitcher(
              duration: AnythingDurations.fast,
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: _hasText
                  ? IconButton(
                      key: const ValueKey('submit'),
                      onPressed: widget.isLoading ? null : _handleSubmit,
                      icon: Icon(
                        Icons.arrow_upward,
                        color: colorScheme.onPrimary,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'Submit',
                    )
                  : IconButton(
                      key: const ValueKey('voice'),
                      onPressed: widget.isLoading ? null : widget.onVoiceTap,
                      icon: Icon(
                        Icons.mic,
                        color: colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      tooltip: 'Voice input',
                    ),
            ),

            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
