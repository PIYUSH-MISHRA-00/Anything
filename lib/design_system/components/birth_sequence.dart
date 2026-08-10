/// Cinematic Birth Sequence — coordinates with real creation readiness.
library;

import 'package:flutter/material.dart';

/// The cinematic creation sequence widget.
/// Coordinates animation with actual creation state.
class BirthSequence extends StatefulWidget {
  final String experienceName;
  final IconData? icon;
  final ValueNotifier<bool> creationReady;
  final VoidCallback onComplete;
  final bool reducedMotion;

  const BirthSequence({
    super.key,
    required this.experienceName,
    this.icon,
    required this.creationReady,
    required this.onComplete,
    this.reducedMotion = false,
  });

  @override
  State<BirthSequence> createState() => _BirthSequenceState();
}

class _BirthSequenceState extends State<BirthSequence>
    with SingleTickerProviderStateMixin {
  late AnimationController _mainController;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.reducedMotion) {
      _waitForReady();
      return;
    }

    // Start animation and wait for readiness
    _mainController.forward();
    _waitForReady();
  }

  void _waitForReady() {
    widget.creationReady.addListener(_onCreationReady);
    // Check if already ready
    if (widget.creationReady.value) {
      _complete();
    }
  }

  void _onCreationReady() {
    if (widget.creationReady.value && !_hasCompleted) {
      _complete();
    }
  }

  void _complete() {
    if (_hasCompleted) return;
    _hasCompleted = true;

    if (widget.reducedMotion) {
      widget.onComplete();
      return;
    }

    // Complete the animation then call onComplete
    _mainController.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    widget.creationReady.removeListener(_onCreationReady);
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reducedMotion) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        final progress = _mainController.value;
        return Container(
          color: Colors.black.withValues(alpha: progress * 0.3),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glow and icon
                Opacity(
                  opacity: progress.clamp(0.0, 1.0),
                  child: ScaleTransition(
                    scale: AlwaysStoppedAnimation(progress.clamp(0.0, 1.0)),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(
                              alpha: 0.3 * progress,
                            ),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primaryContainer,
                        ),
                        child: Icon(
                          widget.icon ?? Icons.auto_awesome,
                          size: 32,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Name
                Opacity(
                  opacity: progress.clamp(0.3, 1.0),
                  child: Text(
                    widget.experienceName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
