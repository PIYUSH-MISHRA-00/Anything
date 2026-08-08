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

import '../../app/retention_policy_engine.dart';
import '../../storage/durable_collection_store.dart';
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

  /// THE canonical retention owner (IS-R50).
  ///
  /// R49 shipped this class with its own `maxScheduled = 200` field — a
  /// fourth independently-invented retention rule. R50 removed it: this
  /// service no longer decides how many schedules to keep, it asks. The bound
  /// is unchanged (still 200) and now lives in `RetentionPolicyEngine`'s
  /// single table.
  final RetentionPolicyEngine retention;

  /// The ONE owner of read-modify-write against a durable key (IS-R56).
  ///
  /// R49 built every mutation below as read-the-whole-list, change it, write
  /// the whole list, with awaits in between and nothing preventing two callers
  /// interleaving. The R56 audit MEASURED the result: ten concurrent
  /// `schedule()` calls left ONE notification stored, and two concurrent
  /// `deliverDue()` calls presented the same notification TWICE, breaking the
  /// exactly-once contract stated in `deliverDue`'s own doc comment. Both are
  /// reachable in production, since `NotificationCapability` exposes
  /// schedule/cancel to any running Experience while `BackgroundCoordinator`
  /// polls `deliverDue`.
  final DurableCollectionStore store;

  RealNotificationService({
    NotificationPresenter? presenter,
    this.retention = const RetentionPolicyEngine(),
    this.store = const DurableCollectionStore(),
  }) : _presenter = presenter ?? const NoOpNotificationPresenter();

  @override
  Future<void> schedule({
    required String id,
    required String experienceId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await store.update<void>(_storageKey, (current) {
      final all = _decode(current);
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
      return (value: _encode(_applyRetention(all)), result: null);
    });
  }

  /// Delegates every retention decision to the ONE canonical engine. This
  /// service decides nothing about how many schedules to keep.
  List<ScheduledNotification> _applyRetention(List<ScheduledNotification> all) {
    final evaluation = retention.evaluate(
      domain: LifecycleDomain.notifications,
      candidates: [
        for (final n in all)
          LifecycleCandidate(id: n.id, timestamp: n.scheduledTime),
      ],
    );
    if (!evaluation.reclaimsAnything) return all;
    final reclaimed = evaluation.reclaimedIds.toSet();
    return [
      for (final n in all)
        if (!reclaimed.contains(n.id)) n,
    ];
  }

  @override
  Future<void> cancel(String id) async {
    await store.update<void>(_storageKey, (current) {
      final all = _decode(current)..removeWhere((n) => n.id == id);
      return (value: _encode(all), result: null);
    });
  }

  @override
  Future<void> cancelAllForExperience(String experienceId) async {
    await store.update<void>(_storageKey, (current) {
      final all = _decode(current)
        ..removeWhere((n) => n.experienceId == experienceId);
      return (value: _encode(all), result: null);
    });
  }

  /// Every scheduled notification still outstanding, earliest first.
  /// Unparseable records are DROPPED rather than repaired or surfaced.
  Future<List<ScheduledNotification>> pending() async =>
      _decode(await store.read(_storageKey));

  /// Parses the stored list. Unparseable records are DROPPED rather than
  /// repaired or surfaced — unchanged from R49.
  static List<ScheduledNotification> _decode(String? raw) {
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

  static String _encode(List<ScheduledNotification> all) =>
      jsonEncode([for (final n in all) n.toJson()]);

  /// Notifications whose scheduled time has arrived at or before [now].
  Future<List<ScheduledNotification>> dueAt(DateTime now) async {
    final all = await pending();
    return all.where((n) => !n.scheduledTime.isAfter(now)).toList();
  }

  /// Presents everything due at [now] and removes it from the pending set,
  /// so a notification is delivered exactly once.
  ///
  /// CLAIM FIRST, PRESENT SECOND — and that order is the whole fix.
  ///
  /// R49 presented and THEN persisted the remainder. `await present(...)` is a
  /// yield point, so a second concurrent caller entered while the due set was
  /// still stored, read the same due set, and presented it again. The R56
  /// audit measured exactly that: one scheduled notification, two
  /// presentations.
  ///
  /// The due set is now REMOVED inside the store's critical section and
  /// returned here; presentation happens afterwards. A second caller arriving
  /// later finds nothing due and presents nothing.
  ///
  /// THE TRADE, STATED PLAINLY: this makes delivery AT-MOST-once rather than
  /// at-least-once. If the process dies between the claim and the
  /// presentation, that notification is not delivered and will not be retried.
  /// That is the correct trade for this contract — the method promises exactly
  /// once, a duplicate alarm is worse than a missed one, and the previous
  /// behaviour was neither. Recorded as gap G-38.
  Future<List<ScheduledNotification>> deliverDue(DateTime now) async {
    final due = await store.update<List<ScheduledNotification>>(_storageKey, (
      current,
    ) {
      final all = _decode(current);
      final claimed = all.where((n) => !n.scheduledTime.isAfter(now)).toList();
      if (claimed.isEmpty) {
        return (value: current, result: const <ScheduledNotification>[]);
      }
      final remaining = all.where((n) => n.scheduledTime.isAfter(now)).toList();
      return (value: _encode(remaining), result: claimed);
    });

    for (final notification in due) {
      await _presenter.present(notification);
    }
    return due;
  }
}
