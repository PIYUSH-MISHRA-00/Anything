/// Runtime Security Limits — the single trusted source of truth for every
/// resource/size/count boundary enforced against untrusted generated
/// Experience content (packages, behavior graphs, component trees, queries,
/// HTTP, knowledge, files).
///
/// A generated ExperiencePackage can *request* values (a query limit, an
/// HTTP timeout, a redirect count); it can never *raise* a value defined
/// here. Enforcement is always `min(requested, trusted)` or an outright
/// rejection — never a silent grant of more than what's declared below.
///
/// See docs/security/RUNTIME_LIMITS.md for the rationale and enforcement
/// site behind each constant.
library;

abstract final class RuntimeSecurityLimits {
  // ── Component tree (lib/runtime/component_registry.dart is the other
  //    copy of these three — kept in sync there because ComponentTreeValidator
  //    depends on RuntimeComponentRegistry, not the reverse; do not diverge).
  static const int maxComponentDepth = 20;
  static const int maxChildrenPerNode = 50;
  static const int maxTotalComponentsPerScreen = 500;

  /// Trusted maximum screens in one ExperiencePackage.
  static const int maxScreensPerPackage = 100;

  /// Trusted maximum behavior graph nodes declared in one package
  /// (independent of the *per-event execution* budget below — this bounds
  /// package size/parsing cost, the execution budget bounds runtime cost).
  static const int maxBehaviorNodesPerPackage = 5000;

  /// Trusted maximum behavior nodes executed per dispatched event
  /// (lib/runtime/behavior_interpreter.dart `_maxNodesPerExecution`).
  /// Duplicated here as documentation of intent; the interpreter's private
  /// constant is the actual enforcement site.
  static const int maxBehaviorNodesPerEvent = 100;

  // ── Text / string size limits (denial-of-service via multi-MB strings).
  static const int maxComponentPropertyTextLength = 20000;
  static const int maxMetadataFieldLength = 500;

  // ── Data query / pagination.
  /// Maximum rows a single ExperienceDataRuntime.query() fetch may return
  /// from SQLite in one call, regardless of table size. Client-side
  /// filter/sort/search (DataQuery) then operates on at most this many
  /// rows — equal to maxQueryResultLimit, since a bigger fetch buffer than
  /// the largest result the caller could ever see just costs memory for no
  /// benefit. See docs/security/RUNTIME_LIMITS.md "Search scalability".
  static const int maxFetchRowsPerQuery = maxQueryResultLimit;

  /// Maximum rows returned to a caller after DataQuery filter/sort/paginate
  /// (lib/runtime/data_query.dart `DataQuery.maxResultLimit`).
  static const int maxQueryResultLimit = 1000;
  static const int maxQueryFilters = 20;
  static const int maxQuerySorts = 5;

  // ── ExperiencePackage size.
  /// Trusted maximum serialized package size in bytes. Rejected before
  /// persistence/rendering.
  static const int maxPackageBytes = 5 * 1024 * 1024; // 5 MB

  // ── HTTP capability.
  static const int maxHttpRedirects = 5;
  static const Duration maxHttpConnectTimeout = Duration(seconds: 10);
  static const Duration maxHttpOverallTimeout = Duration(seconds: 30);
  static const int maxHttpRequestBytes = 1 * 1024 * 1024; // 1 MB
  static const int maxHttpResponseBytes = 5 * 1024 * 1024; // 5 MB

  // ── Knowledge / WebWeaveX.
  /// Trusted maximum bytes of retrieved web content admitted into a
  /// reasoning prompt in one KnowledgeBundle.
  static const int maxKnowledgeBytes = 200 * 1024; // 200 KB

  // ── File capability.
  static const int maxFileBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxFileNameLength = 255;

  // ── Model output (untrusted LLM response).
  static const int maxModelOutputBytes = 2 * 1024 * 1024; // 2 MB

  // ── AI capability (Experience-facing, prompt in / text out).
  static const int maxAiPromptBytes = 20000;
  static const int maxAiResponseBytes = 100000;
}
