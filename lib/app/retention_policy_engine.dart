/// RetentionPolicyEngine — Implementation Specification IS-R50. The ONE owner
/// of DATA RETENTION policy: how many stored records to keep, for how long,
/// how large a store may grow, and which records are exempt.
///
/// WHY THIS IS A SIBLING OF `WorkspaceLifecyclePolicyEngine`, NOT AN EXTENSION
/// OF IT.
///
/// IS-R50 asks that `WorkspaceLifecyclePolicyEngine` remain the canonical
/// owner "whenever appropriate", and that it be extended rather than joined by
/// an unrelated engine "if that preserves the established ownership model".
/// Reading that engine, extending it would NOT preserve the model — it would
/// damage it, for four concrete reasons:
///
///   1. DIFFERENT SUBJECT. It decides what a RUNNING RUNTIME should do
///      (pause/resume/terminate/restore) and acts on an
///      `ExperienceRuntimeController`. Retention decides what STORED RECORDS
///      should do, and no controller exists anywhere in that path.
///   2. DIFFERENT INPUT. Its inputs are `AppLifecycleState` and
///      `WorkspaceRuntimeSnapshot`. Retention's inputs are record counts,
///      ages and sizes. Neither can produce the other's input.
///   3. CLOSED VOCABULARY. `RuntimePolicyAction` is a deliberately closed enum
///      that `apply()` exhaustively switches over. Widening it with
///      `evict`/`expire` would make that switch — and every caller's switch —
///      silently incomplete or force a meaningless `noAction` fallthrough.
///      Merging two unrelated vocabularies into one enum is precisely how a
///      clean ownership model rots.
///   4. DIFFERENT CONSUMERS. That engine is consumed by the scheduler and
///      runtime supervisor. Retention is consumed by repositories and
///      capability services, which must never depend on the runtime layer.
///
/// So there are exactly TWO policy engines, owning two DISJOINT domains:
///
///     WorkspaceLifecyclePolicyEngine  ->  runtime lifecycle (R39)
///     RetentionPolicyEngine           ->  data retention     (R50)
///
/// The disjointness is not a claim — it is certified: the retention engine
/// never references a runtime controller or `AppLifecycleState`, and the
/// runtime engine never references retention. Anything else would be the
/// "parallel ownership" IS-R50 forbids.
///
/// WHAT THIS REPLACES. Before R50 retention was invented independently, three
/// times, with three unexplained magic numbers and one domain missing it
/// entirely:
///
///     IntentRepository._maxRecords          = 100   (hardcoded)
///     ActivityRepository._maxEvents         = 200   (hardcoded)
///     RealNotificationService.maxScheduled  = 200   (hardcoded, R49)
///     KnowledgeRepository                   = none  (gap G-18, unbounded)
///     RealFileService temporary files       = none  (cleared only on demand)
///
/// Every one of those now delegates here. The numbers did not change — they
/// moved, so that they are stated once, in one table, and can be reasoned
/// about together instead of rediscovered one file at a time.
///
/// PURE AND DETERMINISTIC. This engine decides; it never deletes. It holds no
/// storage handle, performs no I/O, and owns no `Timer`. A caller applies the
/// decisions to its own store, which is what keeps storage ownership exactly
/// where R46–R49 established it: `KnowledgeRepository` remains storage only,
/// repositories remain repositories.
library;

/// How aggressively a domain's records may be reclaimed.
enum RetentionClass {
  /// Reclaimed as soon as policy allows; nothing here is worth keeping across
  /// sessions (temporary scratch files).
  ephemeral,

  /// Kept while within bounds, then the oldest are reclaimed (history-shaped
  /// data: intents, activity, notifications, cached knowledge).
  bounded,

  /// Never reclaimed by this engine. User-authored artefacts whose deletion is
  /// an explicit user action, not a policy outcome (Experiences themselves).
  durable,

  /// Exempt from reclamation for as long as the exemption stands, even when
  /// the domain is otherwise over budget (manually protected knowledge).
  protected,
}

/// What should happen to one candidate record.
enum LifecycleAction {
  /// Keep it.
  retain,

  /// Reclaim it because the domain is over its size/count budget.
  evict,

  /// Reclaim it because it is older than the domain allows.
  expire,
}

/// The retention rule for one domain. A `null` bound means "this dimension is
/// not bounded", stated explicitly rather than implied by a sentinel.
class LifecyclePolicy {
  final RetentionClass retentionClass;
  final int? maxEntries;
  final int? maxBytes;
  final Duration? maxAge;

  const LifecyclePolicy({
    required this.retentionClass,
    this.maxEntries,
    this.maxBytes,
    this.maxAge,
  });

  /// Nothing is ever reclaimed by policy.
  static const LifecyclePolicy unbounded = LifecyclePolicy(retentionClass: RetentionClass.durable);

  bool get isBounded => maxEntries != null || maxBytes != null || maxAge != null;
}

/// One record offered to the engine for a decision. Deliberately minimal: an
/// identity, when it happened, optionally how big it is, and whether the user
/// has exempted it. The engine needs nothing else, and asking for more would
/// couple it to each domain's record type.
class LifecycleCandidate {
  final String id;
  final DateTime timestamp;
  final int? sizeBytes;
  final bool isProtected;

  const LifecycleCandidate({
    required this.id,
    required this.timestamp,
    this.sizeBytes,
    this.isProtected = false,
  });
}

/// What to do with one candidate, and why. The reason is carried so a
/// reclamation is always explainable after the fact.
class LifecycleDecision {
  final String id;
  final LifecycleAction action;
  final String reason;

  const LifecycleDecision({required this.id, required this.action, required this.reason});

  bool get reclaims => action != LifecycleAction.retain;
}

/// The complete outcome of evaluating one domain.
class LifecycleEvaluation {
  final String domain;
  final LifecyclePolicy policy;
  final List<LifecycleDecision> decisions;

  const LifecycleEvaluation({required this.domain, required this.policy, required this.decisions});

  /// Ids the caller should remove from its own store, in the order decided.
  List<String> get reclaimedIds => [for (final d in decisions) if (d.reclaims) d.id];

  List<String> get retainedIds => [for (final d in decisions) if (!d.reclaims) d.id];

  List<String> get expiredIds => [for (final d in decisions) if (d.action == LifecycleAction.expire) d.id];

  List<String> get evictedIds => [for (final d in decisions) if (d.action == LifecycleAction.evict) d.id];

  bool get reclaimsAnything => decisions.any((d) => d.reclaims);
}

/// The canonical retention domains. String-keyed with named constants rather
/// than an enum so a future domain can be registered without editing a closed
/// type that other packages switch over.
abstract final class LifecycleDomain {
  static const String knowledge = 'knowledge';
  static const String intents = 'intents';
  static const String activity = 'activity';
  static const String notifications = 'notifications';
  static const String temporaryFiles = 'temporary_files';
  static const String exports = 'exports';

  static const List<String> all = [knowledge, intents, activity, notifications, temporaryFiles, exports];
}

class RetentionPolicyEngine {
  /// THE retention table. Every bound in the application is stated here, once.
  ///
  /// The three pre-R50 numbers are preserved exactly (intents 100, activity
  /// 200, notifications 200) so R50 changes ownership without silently
  /// changing behaviour. Knowledge gains the bound it never had (gap G-18);
  /// temporary files gain an age bound so scratch space cannot accumulate
  /// indefinitely.
  static const Map<String, LifecyclePolicy> defaultPolicies = {
    LifecycleDomain.knowledge: LifecyclePolicy(
      retentionClass: RetentionClass.bounded,
      maxEntries: 500,
      maxBytes: 20 * 1024 * 1024,
      maxAge: Duration(days: 30),
    ),
    LifecycleDomain.intents: LifecyclePolicy(retentionClass: RetentionClass.bounded, maxEntries: 100),
    LifecycleDomain.activity: LifecyclePolicy(retentionClass: RetentionClass.bounded, maxEntries: 200),
    LifecycleDomain.notifications: LifecyclePolicy(retentionClass: RetentionClass.bounded, maxEntries: 200),
    LifecycleDomain.temporaryFiles: LifecyclePolicy(
      retentionClass: RetentionClass.ephemeral,
      maxAge: Duration(days: 1),
    ),
    LifecycleDomain.exports: LifecyclePolicy(
      retentionClass: RetentionClass.ephemeral,
      maxAge: Duration(days: 7),
    ),
  };

  final Map<String, LifecyclePolicy> policies;

  const RetentionPolicyEngine({this.policies = defaultPolicies});

  /// The policy for [domain]. An unregistered domain is `unbounded` — a
  /// deliberate fail-safe: an unknown domain must never have its data silently
  /// reclaimed by a default nobody chose.
  LifecyclePolicy policyFor(String domain) => policies[domain] ?? LifecyclePolicy.unbounded;

  /// Evaluates [candidates] against [domain]'s policy.
  ///
  /// Order of reasoning, and why:
  ///   1. PROTECTED candidates are retained unconditionally. A manual
  ///      exemption outranks every budget, or it is not an exemption.
  ///   2. AGE. Expiry is evaluated before budgets so an over-budget domain
  ///      reports the honest reason (`expire`) for records that were going to
  ///      be reclaimed anyway, rather than mislabelling them `evict`.
  ///   3. COUNT, newest-first. The oldest surplus is evicted.
  ///   4. BYTES, newest-first. Evicts until the remainder fits.
  ///
  /// Deterministic: candidates are ordered newest-first by timestamp, ties
  /// broken by id, so the same input always produces the same decisions.
  LifecycleEvaluation evaluate({
    required String domain,
    required List<LifecycleCandidate> candidates,
    DateTime? now,
  }) {
    final policy = policyFor(domain);
    final at = now ?? DateTime.now();

    final ordered = [...candidates]..sort((a, b) {
      final byTime = b.timestamp.compareTo(a.timestamp);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });

    final decisions = <LifecycleDecision>[];
    var keptCount = 0;
    var keptBytes = 0;

    for (final candidate in ordered) {
      if (candidate.isProtected) {
        decisions.add(LifecycleDecision(
          id: candidate.id,
          action: LifecycleAction.retain,
          reason: 'protected — exempt from $domain retention',
        ));
        continue;
      }

      final maxAge = policy.maxAge;
      if (maxAge != null && at.difference(candidate.timestamp) > maxAge) {
        decisions.add(LifecycleDecision(
          id: candidate.id,
          action: LifecycleAction.expire,
          reason: 'older than ${maxAge.inDays}d $domain maximum age',
        ));
        continue;
      }

      final maxEntries = policy.maxEntries;
      if (maxEntries != null && keptCount >= maxEntries) {
        decisions.add(LifecycleDecision(
          id: candidate.id,
          action: LifecycleAction.evict,
          reason: 'beyond $domain maximum of $maxEntries entries',
        ));
        continue;
      }

      final maxBytes = policy.maxBytes;
      final size = candidate.sizeBytes ?? 0;
      if (maxBytes != null && keptBytes + size > maxBytes) {
        decisions.add(LifecycleDecision(
          id: candidate.id,
          action: LifecycleAction.evict,
          reason: 'beyond $domain maximum of $maxBytes bytes',
        ));
        continue;
      }

      keptCount++;
      keptBytes += size;
      decisions.add(LifecycleDecision(
        id: candidate.id,
        action: LifecycleAction.retain,
        reason: 'within $domain retention budget',
      ));
    }

    return LifecycleEvaluation(domain: domain, policy: policy, decisions: decisions);
  }
}
