/// Structural entity-name extraction from natural-language intents.
///
/// Purely syntactic: bullets, "manage X, Y, Z", "with A, B and C".
/// No product-domain vocabulary and no application factories.
library;

/// Extracted entity label (display name + stable id).
class StructuralEntityName {
  final String id;
  final String name;

  const StructuralEntityName({required this.id, required this.name});
}

/// Open-world entity noun extraction for deterministic collection reasoning.
abstract final class StructuralEntityExtractor {
  /// Returns 1–12 entity names, or empty when nothing structural is found.
  static List<StructuralEntityName> extract(String objective) {
    final names = <String>[];
    names.addAll(_fromBullets(objective));
    if (names.length < 2) {
      names.addAll(_fromManageClause(objective));
    }
    if (names.length < 2) {
      names.addAll(_fromWithClause(objective));
    }
    if (names.isEmpty) {
      final single = _fromListOf(objective);
      if (single != null) names.add(single);
    }

    final seen = <String>{};
    final out = <StructuralEntityName>[];
    for (final raw in names) {
      final cleaned = _clean(raw);
      if (cleaned == null) continue;
      final id = _toId(cleaned);
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(StructuralEntityName(id: id, name: cleaned));
      if (out.length >= 12) break;
    }
    return out;
  }

  /// True when the objective structurally asks for durable managed records.
  static bool looksLikeManagedRecords(String objective) {
    final o = objective.toLowerCase();
    if (extract(objective).length >= 2) return true;
    return o.contains('manage') ||
        o.contains('manager') ||
        o.contains('operations') ||
        o.contains('maintenance') ||
        o.contains('inventory') ||
        o.contains('schedule') ||
        o.contains('schedules') ||
        o.contains('records') ||
        o.contains('track') ||
        o.contains('tracker') ||
        o.contains('log ') ||
        o.endsWith(' log') ||
        o.contains('planner');
  }

  static List<String> _fromBullets(String objective) {
    final out = <String>[];
    for (final line in objective.split(RegExp(r'[\r\n]+'))) {
      final m = RegExp(r'^\s*[-*•]\s+(.+)$').firstMatch(line.trim());
      if (m != null) out.add(m.group(1)!.trim());
    }
    return out;
  }

  static List<String> _fromManageClause(String objective) {
    // Word boundaries matter: bare `track` must not match inside `tracker`
    // (that previously produced a garbage entity named "Er").
    final m = RegExp(
      r'\b(?:manage|managing|track|tracking|include|including|support|supporting)\b\s*:?\s*(.+)$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(objective);
    if (m == null) return const [];
    return _splitNounList(m.group(1)!);
  }

  static List<String> _fromWithClause(String objective) {
    final m = RegExp(
      r'\bwith\s+(.+)$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(objective);
    if (m == null) return const [];
    final clause = m.group(1)!;
    // Ignore short "with photos" style tails unless comma-separated.
    if (!clause.contains(',') && !clause.toLowerCase().contains(' and ')) {
      return const [];
    }
    return _splitNounList(clause);
  }

  static String? _fromListOf(String objective) {
    final m = RegExp(
      r'(?:list|collection)\s+of\s+([A-Za-z][\w\s-]{1,40})',
      caseSensitive: false,
    ).firstMatch(objective);
    return m?.group(1)?.trim();
  }

  static List<String> _splitNounList(String clause) {
    final normalized = clause
        .replaceAll(RegExp(r'\band\b', caseSensitive: false), ',')
        .replaceAll(RegExp(r'[\r\n]+'), ',')
        .replaceAll(RegExp(r'[-*•]'), ',');
    return normalized
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String? _clean(String raw) {
    var t = raw.trim();
    // "inventory with quantity…" → entity "inventory"; fields inferred elsewhere.
    final withHead = RegExp(
      r'^(.+?)\s+\bwith\b\s+',
      caseSensitive: false,
    ).firstMatch(t);
    if (withHead != null) {
      t = withHead.group(1)!.trim();
    }
    t = t.replaceAll(RegExp(r'[.。;:]+$'), '').trim();
    if (t.isEmpty) return null;
    // Drop verb-y fragments and filler.
    const stop = {
      'a',
      'an',
      'the',
      'my',
      'our',
      'your',
      'app',
      'application',
      'system',
      'tool',
      'complete',
      'full',
      'stack',
      'users',
      'must',
      'be',
      'able',
      'to',
      'create',
      'edit',
      'delete',
      'search',
      'filter',
      'data',
      'persist',
      'after',
      'restart',
      'it',
      'and',
      'or',
      'for',
      'of',
      'records',
      'record',
    };
    final words = t
        .split(RegExp(r'\s+'))
        .where((w) => !stop.contains(w.toLowerCase()))
        .toList();
    if (words.isEmpty) return null;
    // Keep short noun phrases (1–4 words).
    final phrase = words.take(4).join(' ');
    if (phrase.length < 2 || phrase.length > 48) return null;
    if (!RegExp(r'[A-Za-z]').hasMatch(phrase)) return null;
    return phrase[0].toUpperCase() + phrase.substring(1);
  }

  static String _toId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
