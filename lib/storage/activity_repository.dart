/// Activity Repository — local persistence for meaningful user events.
library;

import 'dart:convert';
import '../app/retention_policy_engine.dart';
import 'durable_collection_store.dart';

/// An activity event record.
class ActivityEvent {
  final String id;
  final String type;
  final String? experienceId;
  final String experienceName;
  final String message;
  final DateTime timestamp;

  /// Real, measured wall-clock duration of the operation this event
  /// records, when the caller tracked one (Implementation Milestone R7)
  /// — `null` for every pre-R7 event and any caller that doesn't measure
  /// it. Never fabricated: `ExperienceModificationCoordinator.applyEvolutionPlan()`/
  /// `.rollback()` populate this from a real `Stopwatch`.
  final int? durationMs;

  const ActivityEvent({
    required this.id,
    required this.type,
    this.experienceId,
    required this.experienceName,
    required this.message,
    required this.timestamp,
    this.durationMs,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'experienceId': experienceId,
    'experienceName': experienceName,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    if (durationMs != null) 'durationMs': durationMs,
  };

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] as String,
      type: json['type'] as String,
      experienceId: json['experienceId'] as String?,
      experienceName: json['experienceName'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      durationMs: json['durationMs'] as int?,
    );
  }
}

/// Activity repository, persisted through the ONE `DurableCollectionStore`
/// (IS-R56) rather than touching `SharedPreferences` itself.
///
/// IS-R50: this repository no longer owns retention. It previously carried
/// `static const int _maxEvents = 200` and enforced it inline. The bound is
/// unchanged (still 200), but it now lives in `RetentionPolicyEngine`'s single
/// table. Storage stays here; policy does not.
class ActivityRepository {
  static const String _storageKey = 'anything_activity';

  /// The canonical retention owner. Injectable for tests; defaults to the
  /// canonical engine so every existing caller is unaffected.
  final RetentionPolicyEngine retention;

  /// The ONE owner of read-modify-write against a durable key (IS-R56).
  ///
  /// `record()` was read-the-whole-list, insert, write-the-whole-list, with
  /// awaits in between and nothing serialising them — the same shape that was
  /// MEASURED losing nine of ten concurrent writes in
  /// `RealNotificationService`. The R56 probe against this class happened to
  /// store all ten, but that is an accident of await ordering, not a
  /// guarantee, and nothing asserted it. R56 does NOT claim this class was
  /// broken; it removes the duplicated pattern so it cannot become broken.
  ///
  /// It matters more here than anywhere else that the lock is keyed by storage
  /// key rather than by instance: this repository is constructed in NINE
  /// separate places (see the R56 audit) and has no composition ownership, so
  /// per-instance locking would protect nothing.
  final DurableCollectionStore store;

  const ActivityRepository({
    this.retention = const RetentionPolicyEngine(),
    this.store = const DurableCollectionStore(),
  });

  /// Record an activity event.
  Future<void> record(ActivityEvent event) async {
    await store.update<void>(_storageKey, (current) {
      final events = _decode(current)..insert(0, event);

      final evaluation = retention.evaluate(
        domain: LifecycleDomain.activity,
        candidates: [
          for (final e in events) LifecycleCandidate(id: e.id, timestamp: e.timestamp),
        ],
      );
      final reclaimed = evaluation.reclaimedIds.toSet();
      final retained = [for (final e in events) if (!reclaimed.contains(e.id)) e];

      return (value: jsonEncode([for (final e in retained) e.toJson()]), result: null);
    });
  }

  static List<ActivityEvent> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> jsonList = jsonDecode(raw);
    return [for (final j in jsonList) ActivityEvent.fromJson(j as Map<String, dynamic>)];
  }

  /// List activity events.
  Future<List<ActivityEvent>> list({int limit = 50}) async =>
      _decode(await store.read(_storageKey)).take(limit).toList();

  /// Clear all activity.
  Future<void> clearAll() => store.clear(_storageKey);
}
