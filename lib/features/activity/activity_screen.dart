/// Activity screen — shows real local user history.
library;

import 'package:flutter/material.dart';

import '../../design_system/components/anything_empty_state.dart';
import '../../design_system/tokens/spacing.dart';
import '../../storage/activity_repository.dart';

/// Activity screen with real local events.
class ActivityScreen extends StatefulWidget {
  /// The shared `ActivityRepository` (IS-R57). Optional, defaulted, so every
  /// existing caller is unaffected — the same pattern the rest of the app uses.
  final ActivityRepository? repository;

  const ActivityScreen({super.key, this.repository});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final ActivityRepository _repository =
      widget.repository ?? const ActivityRepository();
  List<ActivityEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await _repository.list();
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'created':
        return Icons.auto_awesome;
      case 'opened':
        return Icons.open_in_new;
      case 'updated':
        return Icons.edit;
      case 'deleted':
        return Icons.delete;
      case 'protected':
        return Icons.shield;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AnythingPadding.regular,
              16,
              AnythingPadding.regular,
              0,
            ),
            child: Text(
              'Activity',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                letterSpacing: -0.01,
              ),
            ),
          ),
        ),
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_events.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AnythingEmptyState(
              icon: Icons.notifications_none,
              title: 'No activity yet',
              message: 'Your creation history will appear here.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AnythingPadding.regular,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final event = _events[index];
                return ListTile(
                  leading: Icon(
                    _getEventIcon(event.type),
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  title: Text(event.message),
                  subtitle: Text(
                    '${_formatTime(event.timestamp)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }, childCount: _events.length),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
