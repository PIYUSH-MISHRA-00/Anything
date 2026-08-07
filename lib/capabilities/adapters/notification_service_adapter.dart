/// RealNotificationService — Implementation Specification IS-R49 Task 2.
///
/// The real production implementation of `NotificationService`, replacing
/// `FakeNotificationService` in `AppComposition`. Follows the established
/// pattern of `RealHttpTransport` (`http_transport_adapter.dart`): a real
/// adapter in `lib/capabilities/adapters/` implementing a capability
/// abstraction declared in `lib/capabilities/builtin/`.
///
/// WHAT WAS FAKE. `FakeNotificationService` appended to an in-memory `List`
/// and did nothing else. Scheduling did not survive restart, nothing was ever
/// delivered, `cancel()` recorded an id without removing anything, and
/// `cancelAllForExperience()` mutated a list nobody read. It was registered in
/// the REAL production composition.
///
/// WHAT IS REAL HERE.
///   * Durable scheduling — records persist across restart via
///     `SharedPreferences`, the same backend `ActivityRepository` already
///     uses. No new storage system and no new dependency.
///   * Real lifecycle — [pending], [dueAt] and [deliverDue] compute genuine
///     due state from the stored `scheduledTime`.
///   * Real ownership — [cancelAllForExperience] removes exactly that
///     Experience's records and leaves every other Experience untouched.
///   * Real cancellation — [cancel] removes the record; a cancelled
///     notification can never later become due.
///   * Real foreground delivery — [deliverDue] publishes the EXISTING
///     `NotificationGenerated` event (R35) on the EXISTING `EventBus`. No new
///     event hierarchy, no second notification framework.
///
/// WHAT IS HONESTLY NOT DONE, AND WHY. OS-level background delivery (a
/// notification that appears while Anything is not running) requires a
/// platform plugin — `flutter_local_notifications` plus a timezone database,
/// Android manifest permissions and receivers, an iOS `AppDelegate`
/// registration, and a notification icon asset. None of that can be exercised
/// by `flutter test`, which has no platform channels, and no device or
/// emulator is available in this environment. Adding it would mean shipping
/// unverified native configuration and calling it complete — strictly worse
/// than a documented gap, because it would LOOK finished while silently
/// never delivering.
///
/// `lib/runtime_intelligence/background_coordinator.dart` already drew this
/// exact line, in its own words: it "produces the typed plan a future
/// milestone's real scheduler would consume, honestly, never fabricating live
/// execution." This class holds that line.
///
/// The seam is therefore explicit and singular: [NotificationPresenter]. An
/// OS-backed presenter plugs in there and nothing else changes. There is no
/// second scheduler, no second queue and no parallel notification model —
/// `NotificationPlanner`/`BackgroundCoordinator` remain the canonical
/// planning layer and are untouched.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/events/events.dart';
import '../builtin/notification_capability.dart';

/// One durably-scheduled notification.
class ScheduledNotification {
  final String id;
  final String experienceId;
  final String title;
  final String body;
  final DateTime scheduledTime;

  const ScheduledNotification({
    required this.id,
    required this.experienceId,
    required this.title,
    required this.body,
    required this.scheduledTime,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'experienceId': experienceId,
    'title': title,
    'body': body,
    'scheduledTime': scheduledTime.toIso8601String(),
  };

  static ScheduledNotification? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final experienceId = json['experienceId'];
    final scheduledTime = json['scheduledTime'];
    if (id is! String || experienceId is! String || scheduledTime is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(scheduledTime);
    if (parsed == null) return null;
    return ScheduledNotification(
      id: id,
      experienceId: experienceId,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      scheduledTime: parsed,
    );
  }
}

/// Where a due notification is actually presented.
///
/// THE single seam for delivery. The default implementation publishes on the
/// existing `EventBus`, which is real in-app (foreground) delivery. An
/// OS-backed implementation would sit here too — it is deliberately NOT
/// written blind, see this library's doc comment.
abstract class NotificationPresenter {
  Future<void> present(ScheduledNotification notification);
}

/// Real foreground delivery: publishes the EXISTING `NotificationGenerated`
/// event (R35) on the EXISTING `EventBus`. Introduces no event subtype.
class EventBusNotificationPresenter implements NotificationPresenter {
  final EventBus _bus;
  final String _source;
  int _counter = 0;

  EventBusNotificationPresenter({
    required EventBus bus,
    String source = 'notifications',
  }) : _bus = bus,
       _source = source;

  @override
  Future<void> present(ScheduledNotification notification) async {
    _bus.publish(
      NotificationGenerated(
        id: '$_source-${notification.id}-${_counter++}',
        timestamp: DateTime.now(),
        source: _source,
        sessionId: notification.experienceId,
        outcome: notification.title,
      ),
    );
  }
}

/// A presenter that drops everything, for the composition case where no
/// event bus is available. Explicit and named, so "nothing is presented" is
/// a visible decision rather than a silent one.
class NoOpNotificationPresenter implements NotificationPresenter {
  const NoOpNotificationPresenter();

  @override
  Future<void> present(ScheduledNotification notification) async {}
}

class RealNotificationService implements NotificationService {
  static const String _storageKey = 'anything_scheduled_notifications';

  final NotificationPresenter _presenter;

  /// Ceiling on stored records, mirroring `ActivityRepository`'s own
  /// `_maxEvents` convention so a runaway Experience cannot grow storage
  /// without bound. Oldest-by-scheduled-time is dropped first.
  final int maxScheduled;

  RealNotificationService({
    NotificationPresenter? presenter,
    this.maxScheduled = 200,
  }) : _presenter = presenter ?? const NoOpNotificationPresenter();

  @override
  Future<void> schedule({
    required String id,
    required String experienceId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final all = await pending();
    // Re-scheduling an existing id replaces it rather than duplicating —
    // the same replace-on-put semantics the rest of this codebase uses.
    all.removeWhere((n) => n.id == id);
    all.add(
      ScheduledNotification(
        id: id,
        experienceId: experienceId,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
      ),
    );
    all.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    if (all.length > maxScheduled) {
      all.removeRange(0, all.length - maxScheduled);
    }
    await _write(all);
  }

  @override
  Future<void> cancel(String id) async {
    final all = await pending();
    final before = all.length;
    all.removeWhere((n) => n.id == id);
    if (all.length != before) await _write(all);
  }

  @override
  Future<void> cancelAllForExperience(String experienceId) async {
    final all = await pending();
    final before = all.length;
    all.removeWhere((n) => n.experienceId == experienceId);
    if (all.length != before) await _write(all);
  }

  /// Every scheduled notification still outstanding, earliest first.
  /// Unparseable records are DROPPED rather than repaired or surfaced.
  Future<List<ScheduledNotification>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final result = <ScheduledNotification>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final parsed = ScheduledNotification.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (parsed != null) result.add(parsed);
      }
      result.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Notifications whose scheduled time has arrived at or before [now].
  Future<List<ScheduledNotification>> dueAt(DateTime now) async {
    final all = await pending();
    return all.where((n) => !n.scheduledTime.isAfter(now)).toList();
  }

  /// Presents everything due at [now] and removes it from the pending set,
  /// so a notification is delivered exactly once. Returns what was delivered.
  Future<List<ScheduledNotification>> deliverDue(DateTime now) async {
    final all = await pending();
    final due = all.where((n) => !n.scheduledTime.isAfter(now)).toList();
    if (due.isEmpty) return const [];

    for (final notification in due) {
      await _presenter.present(notification);
    }

    final remaining = all.where((n) => n.scheduledTime.isAfter(now)).toList();
    await _write(remaining);
    return due;
  }

  Future<void> _write(List<ScheduledNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode([for (final n in notifications) n.toJson()]),
    );
  }
}
