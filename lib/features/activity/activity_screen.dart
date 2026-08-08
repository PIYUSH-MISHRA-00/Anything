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

  /// IS-P05 finding 14 — remove one entry.
  ///
  /// Delegates to `ActivityRepository.remove`, so the storage key stays
  /// private to the repository that owns it.
  Future<void> _dismissEvent(ActivityEvent event) async {
    await _repository.remove(event.id);
    if (!mounted) return;
    setState(
      () => _events = [
        for (final e in _events)
          if (e.id != event.id) e,
      ],
    );
  }

  /// IS-P05 finding 15 — destructive, therefore confirmed.
  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all activity?'),
        content: Text(
          'This removes all ${_events.length} entries from this device. '
          'Your apps are not affected — only the history of what happened.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear all', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _repository.clearAll();
    await _loadEvents();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Activity cleared')));
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.01,
                  ),
                ),
                // IS-P05 finding 15. History accumulated with no way to clear
                // it. `ActivityRepository.clearAll()` already existed and had
                // no caller -- this is wiring, not new machinery.
                if (_events.isNotEmpty)
                  TextButton.icon(
                    onPressed: _confirmClearAll,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Clear all'),
                  ),
              ],
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
                // IS-P05 finding 14 — dismiss a single entry by swiping.
                // Removal is persisted by rewriting the retained set through
                // the same repository that owns the list.
                return Dismissible(
                  key: ValueKey(event.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  onDismissed: (_) => _dismissEvent(event),
                  child: ListTile(
                    leading: Icon(
                      _getEventIcon(event.type),
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    title: Text(event.message),
                    subtitle: Text(
                      _formatTime(event.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
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
