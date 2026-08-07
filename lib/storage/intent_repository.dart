/// Local Intent persistence repository.
///
/// Persists submitted Intent metadata for history and Activity.
/// Does NOT persist API keys, secrets, or raw audio.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/retention_policy_engine.dart';
import '../core/contracts/intent.dart';

/// Persistent record of a submitted Intent.
class IntentRecord {
  final IntentId id;
  final String expression;
  final InputModality modality;
  final IntentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AttachmentRecord> attachments;

  const IntentRecord({
    required this.id,
    required this.expression,
    required this.modality,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const [],
  });

  factory IntentRecord.fromIntent(Intent intent) {
    return IntentRecord(
      id: intent.id,
      expression: intent.expression,
      modality: intent.modality,
      status: intent.status,
      createdAt: intent.createdAt,
      updatedAt: intent.updatedAt,
      attachments: intent.attachments
          .map(
            (a) => AttachmentRecord(id: a.id, name: a.name, type: a.type.name),
          )
          .toList(),
    );
  }

  IntentRecord copyWith({IntentStatus? status}) {
    return IntentRecord(
      id: id,
      expression: expression,
      modality: modality,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      attachments: attachments,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'expression': expression,
    'modality': modality.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
  };

  factory IntentRecord.fromJson(Map<String, dynamic> json) {
    return IntentRecord(
      id: json['id'] as String,
      expression: json['expression'] as String,
      modality: InputModality.values.firstWhere(
        (m) => m.name == json['modality'],
        orElse: () => InputModality.text,
      ),
      status: IntentStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => IntentStatus.draft,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      attachments:
          (json['attachments'] as List?)
              ?.map((a) => AttachmentRecord.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Persistent record of an attachment (metadata only, no binary).
class AttachmentRecord {
  final String id;
  final String name;
  final String type;

  const AttachmentRecord({
    required this.id,
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type};

  factory AttachmentRecord.fromJson(Map<String, dynamic> json) {
    return AttachmentRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }
}

/// Repository for persisting Intent records locally.
///
/// IS-R50: this repository no longer owns retention. It previously carried
/// `static const int _maxRecords = 100` and enforced it inline — one of three
/// independently-invented retention rules in the codebase. The bound is
/// unchanged (still 100), but it now lives in `RetentionPolicyEngine`'s single
/// table and is applied by delegating to it. Storage stays here; policy does
/// not.
class IntentRepository {
  static const String _storageKey = 'anything_intent_history';

  /// The canonical retention owner. Injectable for tests; defaults to the
  /// canonical engine so every existing caller is unaffected (no API break).
  final RetentionPolicyEngine retention;

  const IntentRepository({this.retention = const RetentionPolicyEngine()});

  /// Save an intent record.
  Future<void> save(IntentRecord record) async {
    final records = await list(limit: 1 << 30);

    // Remove existing record with same ID
    records.removeWhere((r) => r.id == record.id);

    // Add new record at the beginning
    records.insert(0, record);

    await _saveRecords(_applyRetention(records));
  }

  /// Delegates every retention decision to the ONE canonical engine. This
  /// repository decides nothing about how much history to keep.
  List<IntentRecord> _applyRetention(List<IntentRecord> records) {
    final evaluation = retention.evaluate(
      domain: LifecycleDomain.intents,
      candidates: [
        for (final r in records) LifecycleCandidate(id: r.id, timestamp: r.createdAt),
      ],
    );
    if (!evaluation.reclaimsAnything) return records;
    final reclaimed = evaluation.reclaimedIds.toSet();
    return [for (final r in records) if (!reclaimed.contains(r.id)) r];
  }

  /// Update the status of an intent record.
  Future<void> updateStatus(IntentId id, IntentStatus status) async {
    final records = await list();

    final index = records.indexWhere((r) => r.id == id);
    if (index >= 0) {
      records[index] = records[index].copyWith(status: status);
      await _saveRecords(records);
    }
  }

  /// Get recent intent records.
  Future<List<IntentRecord>> list({int limit = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    final records = jsonList
        .map((j) => IntentRecord.fromJson(j as Map<String, dynamic>))
        .toList();

    return records.take(limit).toList();
  }

  /// Get an intent record by ID.
  Future<IntentRecord?> getById(IntentId id) async {
    final records = await list();
    try {
      return records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Delete an intent record.
  Future<void> delete(IntentId id) async {
    final records = await list();
    records.removeWhere((r) => r.id == id);
    await _saveRecords(records);
  }

  /// Clear all intent history.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _saveRecords(List<IntentRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = records.map((r) => r.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }
}
