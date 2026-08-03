/// Path Template — Implementation Milestone R12. A real, minimal,
/// deterministic naming/directory rule: `{placeholder}` substitution
/// against a small, closed set of real fields a [BuildGraphNode] (R11)
/// actually carries (`id`, `label`). Deliberately NOT a general-purpose
/// templating engine (no conditionals, no loops, no expressions) — a
/// bounded, real, checkable string-replace, matching the milestone's own
/// explicit "keep it small and real, not a new templating language"
/// scope boundary. Never capable of path traversal: placeholder values
/// are substituted verbatim from already-validated node
/// id/label data (never raw external input), and the template string
/// itself is real, author-supplied, typed data — never `eval`-shaped.
library;

class PathTemplate {
  final String pattern;

  const PathTemplate(this.pattern);

  /// Deterministic substitution: the same (`pattern`, `id`, `label`)
  /// always produces the same path (Rule 7).
  String resolve({required String id, required String label}) =>
      pattern.replaceAll('{id}', id).replaceAll('{label}', label);
}
