/// Structural field + relationship inference for deterministic SemanticApps.
///
/// Cue-driven and entity-token-driven — not product-domain factories.
/// Hallucinates nothing the prompt/entity labels do not structurally support.
library;

import 'app_blueprint.dart';
import 'application_reasoner.dart';
import 'structural_entity_extractor.dart';

/// Infers typed [SemanticField]s (including references) for extracted entities.
abstract final class StructuralFieldInferrer {
  /// Build fields for [entity] given the full objective and peer entities.
  static List<SemanticField> fieldsFor(
    StructuralEntityName entity, {
    required String objective,
    required List<StructuralEntityName> peers,
  }) {
    final fields = <SemanticField>[];
    final seen = <String>{};

    void add(SemanticField field) {
      if (seen.add(field.id)) fields.add(field);
    }

    add(
      const SemanticField(
        id: 'name',
        name: 'Name',
        type: BlueprintFieldType.text,
        required: true,
      ),
    );
    add(
      const SemanticField(
        id: 'details',
        name: 'Details',
        type: BlueprintFieldType.multilineText,
      ),
    );

    for (final f in _explicitWithFields(entity, objective, peers)) {
      add(f);
    }
    for (final f in _tokenFields(entity, objective)) {
      add(f);
    }
    for (final f in _referenceFields(entity, peers)) {
      add(f);
    }

    add(
      const SemanticField(
        id: 'created_at',
        name: 'Created At',
        type: BlueprintFieldType.dateTime,
      ),
    );
    return fields;
  }

  /// Parse `Entity with a, b and c` clauses attached to this entity.
  static List<SemanticField> _explicitWithFields(
    StructuralEntityName entity,
    String objective,
    List<StructuralEntityName> peers,
  ) {
    final out = <SemanticField>[];
    final entityKey = entity.name.toLowerCase();
    final entityId = entity.id;
    final withRe = RegExp(
      r'(?:^|[-*•]\s*)(.+?)\s+\bwith\b\s+(.+)$',
      caseSensitive: false,
      multiLine: true,
    );
    for (final m in withRe.allMatches(objective)) {
      final head = m.group(1)!.trim().toLowerCase();
      final headId = head
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      if (head != entityKey &&
          !head.contains(entityKey) &&
          headId != entityId &&
          !entityId.contains(headId) &&
          !headId.contains(entityId)) {
        continue;
      }
      final phrases = m
          .group(2)!
          .replaceAll(RegExp(r'\band\b', caseSensitive: false), ',')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      for (final phrase in phrases) {
        final field = _fieldFromPhrase(phrase, peers);
        if (field != null) out.add(field);
      }
    }
    return out;
  }

  static SemanticField? _fieldFromPhrase(
    String phrase,
    List<StructuralEntityName> peers,
  ) {
    final lower = phrase.toLowerCase().trim();
    if (lower.isEmpty || lower == 'name' || lower == 'details') return null;
    final id = lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (id.isEmpty) return null;

    final peer = _peerMatching(lower, peers);
    if (peer != null) {
      return SemanticField(
        id: '${peer.id}_ref',
        name: peer.name,
        type: BlueprintFieldType.reference,
        referenceEntityId: peer.id,
      );
    }

    final type = _typeForCue(lower);
    final label = phrase[0].toUpperCase() + phrase.substring(1);
    return SemanticField(id: id, name: label, type: type);
  }

  static BlueprintFieldType _typeForCue(String lower) {
    if (RegExp(
      r'quantity|count|threshold|stock|minutes|hours|score|vote|progress',
    ).hasMatch(lower)) {
      return BlueprintFieldType.integer;
    }
    if (RegExp(
      r'cost|price|amount|total|budget|fee|currency',
    ).hasMatch(lower)) {
      return BlueprintFieldType.decimal;
    }
    if (RegExp(
      r'\b(active|enabled|done|complete|boolean|flag)\b',
    ).hasMatch(lower)) {
      return BlueprintFieldType.boolean;
    }
    if (RegExp(
      r'date time|datetime|timestamp|due at|scheduled',
    ).hasMatch(lower)) {
      return BlueprintFieldType.dateTime;
    }
    if (RegExp(r'\bdate\b|deadline|expiry|expires').hasMatch(lower)) {
      return BlueprintFieldType.date;
    }
    if (RegExp(r'status|priority|category|state').hasMatch(lower)) {
      return BlueprintFieldType.category;
    }
    if (RegExp(r'photo|image|media|url|uri').hasMatch(lower)) {
      return BlueprintFieldType.url;
    }
    if (RegExp(r'instruction|notes|summary|description|body').hasMatch(lower)) {
      return BlueprintFieldType.multilineText;
    }
    return BlueprintFieldType.text;
  }

  static List<SemanticField> _tokenFields(
    StructuralEntityName entity,
    String objective,
  ) {
    final tokens = _tokens(entity.name);
    final id = entity.id;
    final obj = objective.toLowerCase();
    final out = <SemanticField>[];

    void add(
      String fieldId,
      String name,
      BlueprintFieldType type, {
      List<String> allowed = const [],
      bool required = false,
    }) {
      out.add(
        SemanticField(
          id: fieldId,
          name: name,
          type: type,
          required: required,
          allowedValues: allowed,
        ),
      );
    }

    if (_has(tokens, const [
          'quantity',
          'inventory',
          'stock',
          'batch',
          'batches',
          'parts',
          'part',
        ]) ||
        (obj.contains('quantity') && id.contains('inventory'))) {
      add('quantity', 'Quantity', BlueprintFieldType.integer);
    }
    if (obj.contains('reorder') &&
        (id.contains('inventory') || tokens.contains('inventory'))) {
      add('reorder_threshold', 'Reorder Threshold', BlueprintFieldType.integer);
    }
    if (_has(tokens, const [
      'cost',
      'costs',
      'price',
      'invoice',
      'invoices',
      'budget',
      'budgets',
      'amount',
      'fee',
    ])) {
      add('amount', 'Amount', BlueprintFieldType.decimal);
    }
    if (_has(tokens, const [
      'schedule',
      'schedules',
      'appointment',
      'appointments',
      'session',
      'sessions',
      'reminder',
      'reminders',
    ])) {
      add('scheduled_at', 'Scheduled At', BlueprintFieldType.dateTime);
    }
    if (_has(tokens, const [
          'photo',
          'photos',
          'image',
          'images',
          'media',
          'submission',
          'submissions',
        ]) ||
        id.contains('photo')) {
      add('media_uri', 'Media', BlueprintFieldType.url);
    }
    if (_has(tokens, const [
      'progress',
      'statistic',
      'statistics',
      'score',
      'vote',
      'voting',
      'result',
      'results',
    ])) {
      add('value', 'Value', BlueprintFieldType.integer);
    }
    if (_has(tokens, const ['warranty', 'warranties'])) {
      add('expires_at', 'Expires At', BlueprintFieldType.date);
    }
    if (_has(tokens, const ['status']) ||
        id.endsWith('_status') ||
        id.contains('production_status') ||
        _has(tokens, const [
          'order',
          'orders',
          'job',
          'jobs',
          'batch',
          'batches',
        ])) {
      add(
        'status',
        'Status',
        BlueprintFieldType.category,
        allowed: const ['active', 'pending', 'done'],
      );
    }
    return out;
  }

  /// Dependent-role entities get references to earlier anchor peers.
  static List<SemanticField> _referenceFields(
    StructuralEntityName entity,
    List<StructuralEntityName> peers,
  ) {
    if (!_isDependent(entity)) return const [];
    final anchors = peers
        .where((p) => p.id != entity.id && !_isDependent(p))
        .toList();
    if (anchors.isEmpty) return const [];

    final preferred = <StructuralEntityName>[];
    for (final a in anchors) {
      if (_sharesStem(entity, a) || _nameMentions(entity, a)) {
        preferred.add(a);
      }
    }
    final chosen = (preferred.isNotEmpty ? preferred : anchors).take(2);
    return [
      for (final a in chosen)
        SemanticField(
          id: '${a.id}_ref',
          name: a.name,
          type: BlueprintFieldType.reference,
          referenceEntityId: a.id,
        ),
    ];
  }

  static bool _isDependent(StructuralEntityName e) {
    const roles = {
      'schedule',
      'schedules',
      'batch',
      'batches',
      'job',
      'jobs',
      'order',
      'orders',
      'planting',
      'plantings',
      'watering',
      'submission',
      'submissions',
      'vote',
      'voting',
      'votes',
      'session',
      'sessions',
      'appointment',
      'appointments',
      'invoice',
      'invoices',
      'transaction',
      'transactions',
      'reminder',
      'reminders',
      'record',
      'records',
      'judging',
      'result',
      'results',
      'entry',
      'entries',
    };
    return _tokens(e.name).any(roles.contains) ||
        roles.any((r) => e.id.contains(r));
  }

  static bool _sharesStem(StructuralEntityName a, StructuralEntityName b) {
    final at = _tokens(a.name);
    final bt = _tokens(b.name);
    for (final t in at) {
      if (t.length < 4) continue;
      for (final u in bt) {
        if (u.length < 4) continue;
        if (t.contains(u) || u.contains(t)) return true;
      }
    }
    return false;
  }

  static bool _nameMentions(StructuralEntityName a, StructuralEntityName b) {
    final hay = a.id;
    final needle = _singularStem(b.id);
    return needle.length >= 3 && hay.contains(needle);
  }

  static String _singularStem(String id) {
    var s = id.split('_').last;
    if (s.endsWith('ies') && s.length > 4) {
      s = '${s.substring(0, s.length - 3)}y';
    } else if (s.endsWith('ses') && s.length > 4) {
      s = s.substring(0, s.length - 2);
    } else if (s.endsWith('s') && s.length > 3) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static StructuralEntityName? _peerMatching(
    String phrase,
    List<StructuralEntityName> peers,
  ) {
    final p = phrase.toLowerCase();
    for (final peer in peers) {
      final n = peer.name.toLowerCase();
      final stem = _singularStem(peer.id);
      if (p == n || p.contains(n) || n.contains(p) || p.contains(stem)) {
        return peer;
      }
    }
    return null;
  }

  static List<String> _tokens(String name) => name
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  static bool _has(List<String> tokens, Iterable<String> needles) {
    final set = needles is Set<String> ? needles : needles.toSet();
    return tokens.any(set.contains);
  }
}
