/// Activity Repository — local persistence for meaningful user events.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/retention_policy_engine.dart';

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

/// Activity repository using SharedPreferences.
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

  const ActivityRepository({this.retention = const RetentionPolicyEngine()});

  /// Record an activity event.
  Future<void> record(ActivityEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final events = await list(limit: 1 << 30);
    events.insert(0, event);

    final evaluation = retention.evaluate(
      domain: LifecycleDomain.activity,
      candidates: [
        for (final e in events) LifecycleCandidate(id: e.id, timestamp: e.timestamp),
      ],
    );
    final reclaimed = evaluation.reclaimedIds.toSet();
    final retained = [for (final e in events) if (!reclaimed.contains(e.id)) e];

    final jsonList = retained.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// List activity events.
  Future<List<ActivityEvent>> list({int limit = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList
        .map((j) => ActivityEvent.fromJson(j as Map<String, dynamic>))
        .take(limit)
        .toList();
  }

  /// Clear all activity.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
