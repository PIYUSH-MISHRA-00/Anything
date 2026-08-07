/// Local Intent persistence repository.
///
/// Persists submitted Intent metadata for history and Activity.
/// Does NOT persist API keys, secrets, or raw audio.
library;

import 'dart:convert';
import '../app/retention_policy_engine.dart';
import 'durable_collection_store.dart';
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

  /// The ONE owner of read-modify-write against a durable key (IS-R56).
  final DurableCollectionStore store;

  const IntentRepository({
    this.retention = const RetentionPolicyEngine(),
    this.store = const DurableCollectionStore(),
  });

  /// Save an intent record.
  Future<void> save(IntentRecord record) async {
    await store.update<void>(_storageKey, (current) {
      final records = _decode(current)
        ..removeWhere((r) => r.id == record.id)
        ..insert(0, record);
      return (value: _encode(_applyRetention(records)), result: null);
    });
  }

  static List<IntentRecord> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> jsonList = jsonDecode(raw);
    return [for (final j in jsonList) IntentRecord.fromJson(j as Map<String, dynamic>)];
  }

  static String _encode(List<IntentRecord> records) =>
      jsonEncode([for (final r in records) r.toJson()]);

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
  /// Update the status of an intent record.
  ///
  /// IS-R56 FIXED A SILENT TRUNCATION HERE. This read through `list()`, whose
  /// default limit is 50, and wrote the result back as the WHOLE history —
  /// so with more than 50 records stored (retention allows 100) every record
  /// past the 50th was silently discarded on any status update. The mutation
  /// now runs against the full stored list inside the critical section, where
  /// no limit applies. Found while consolidating the read-modify-write
  /// pattern; unrelated to concurrency.
  Future<void> updateStatus(IntentId id, IntentStatus status) async {
    await store.update<void>(_storageKey, (current) {
      final records = _decode(current);
      final index = records.indexWhere((r) => r.id == id);
      if (index < 0) return (value: current, result: null);
      records[index] = records[index].copyWith(status: status);
      return (value: _encode(records), result: null);
    });
  }

  /// Get recent intent records.
  Future<List<IntentRecord>> list({int limit = 50}) async =>
      _decode(await store.read(_storageKey)).take(limit).toList();

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
  /// Delete an intent record. See [updateStatus] — this had the identical
  /// limit-50 truncation and is fixed the same way.
  Future<void> delete(IntentId id) async {
    await store.update<void>(_storageKey, (current) {
      final records = _decode(current)..removeWhere((r) => r.id == id);
      return (value: _encode(records), result: null);
    });
  }

  /// Clear all intent history.
  Future<void> clearAll() => store.clear(_storageKey);
}
