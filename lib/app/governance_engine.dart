/// OperatingSystemGovernanceEngine — Implementation Specification IS-R51.
/// The ONE owner of system GOVERNANCE POLICY: what is permitted, for whom,
/// under which conditions.
///
/// WHAT GOVERNANCE IS, AND IS NOT.
///
/// Governance owns DECISIONS. It owns no implementation, no storage, no
/// registry, no scheduler and no execution path. It answers "is this allowed,
/// and why" and nothing else. Every existing owner keeps its job:
///
///     CapabilityPlatform          ENFORCES capability access, owns the registry
///     RetentionPolicyEngine       owns data retention          (R50)
///     WorkspaceLifecyclePolicyEngine owns runtime lifecycle     (R39)
///     AnythingKernel              owns reasoning                (canonical)
///     ExperienceProtectionService owns protection (Kaalka)
///
/// This engine COORDINATES those owners by supplying the policy they consult.
/// It deliberately imports NONE of them: a governance engine that reached into
/// the retention engine, the scheduler or the Kernel would be exactly the
/// parallel ownership IS-R51 forbids. Composition wires the decision to the
/// enforcer; governance never reaches across.
///
/// THE SAME PURITY DISCIPLINE THAT MADE R50 SAFE. `RetentionPolicyEngine`
/// could be trusted with every retention decision in the application
/// precisely because it cannot delete, cannot reach storage and cannot
/// schedule itself. Governance is trusted with every policy decision on the
/// same terms: it is pure and synchronous, holds no I/O, no `Timer`, no
/// capability, no provider and no repository — all certified (I-49).
///
/// WHY A THIRD ENGINE IS NOT A THIRD OWNER. R50 established two policy
/// engines with disjoint domains (runtime lifecycle, data retention). R51 adds
/// a third with a domain disjoint from both: SYSTEM GOVERNANCE — trust,
/// permissions, resource ceilings, network reach, model access, recovery.
/// None of those is a runtime transition and none is a retention bound. The
/// three vocabularies do not overlap, which is certified in every direction
/// (I-48). What would be forbidden — and is certified against — is a FOURTH
/// engine, or any of the three reaching into another's vocabulary.
///
/// REALITY before R51 (Task 1 audit). Governance decisions were real but
/// scattered, and one did not exist at all:
///
///     HTTP allowed hosts        `AppComposition._defaultHttpAllowedHosts`,
///                               passed into `HttpCapability`
///     Invocation budget         `CapabilityPlatform._maxInvocationsPerCapability`
///     File size ceiling         `FileCapability._maxFileSize`
///     Knowledge size ceiling    `RuntimeSecurityLimits.maxKnowledgeBytes`
///     Capability declaration    `CapabilityPlatform.invoke()`
///     Protection                `ExperienceProtectionService` (opt-in)
///     EXPERIENCE TRUST          *** did not exist anywhere ***
///
/// The last line is the important one. Every Experience — however it arrived —
/// was treated identically by the capability platform. There was no notion of
/// a locally-created Experience being more trusted than an imported one,
/// because there was no notion of trust at all.
library;

/// The canonical governance domains (IS-R51 Task 4). Each owns DECISIONS
/// only, never implementation.
enum GovernanceDomain {
  security,
  privacy,
  permissions,
  resourceManagement,
  backgroundExecution,
  network,
  offline,
  modelAccess,
  workspace,
  experienceTrust,
  dataGovernance,
  recovery,
  backup,
  sync,
}

/// How much authority an Experience carries (IS-R51 Task 6).
///
/// Ordered least-to-most privileged so comparisons are meaningful:
/// `index` is the authority rank. Governance DECIDES using this;
/// `CapabilityPlatform` ENFORCES the decision.
enum ExperienceTrustLevel {
  /// Explicitly distrusted — quarantined, minimum authority.
  untrusted,

  /// Under active development or evaluation; may misbehave.
  experimental,

  /// Arrived from outside this device and has not been verified.
  imported,

  /// Created locally by this user, on this device. The default.
  local,

  /// Verified against a known signature/provenance (future marketplace).
  verified,

  /// First-party, shipped with Anything.
  trusted;

  bool atLeast(ExperienceTrustLevel other) => index >= other.index;
}

/// The verdict of one governance decision.
enum GovernanceOutcome {
  allow,

  /// Refused by policy. The reason is always carried.
  deny,

  /// Permitted only with explicit user consent, which governance does not
  /// itself collect — it says consent is required, a UI obtains it.
  requireApproval,
}

/// Everything a rule may reason about. Deliberately a plain value object with
/// no behaviour and no references to live subsystems: a rule that could reach
/// a repository or a capability would no longer be a policy.
class GovernanceContext {
  final ExperienceTrustLevel trustLevel;
  final String? experienceId;
  final String? sessionId;
  final String? capabilityId;
  final String? operation;

  /// Whether the device currently has no usable network. Supplied by the
  /// caller; governance never probes for it.
  final bool isOffline;

  /// User-selected privacy mode: no content may leave the device.
  final bool privacyMode;

  /// Host being contacted, for network decisions.
  final String? host;

  /// Requested size in bytes, for resource decisions.
  final int? requestedBytes;

  const GovernanceContext({
    this.trustLevel = ExperienceTrustLevel.local,
    this.experienceId,
    this.sessionId,
    this.capabilityId,
    this.operation,
    this.isOffline = false,
    this.privacyMode = false,
    this.host,
    this.requestedBytes,
  });
}

/// One decision, always with a reason and the rule that produced it, so a
/// denial is explainable rather than an unattributed refusal.
class GovernanceDecision {
  final GovernanceDomain domain;
  final GovernanceOutcome outcome;
  final String reason;
  final String ruleId;

  const GovernanceDecision({
    required this.domain,
    required this.outcome,
    required this.reason,
    required this.ruleId,
  });

  bool get isAllowed => outcome == GovernanceOutcome.allow;
  bool get isDenied => outcome == GovernanceOutcome.deny;
}

/// One rule. Returns `null` when it has no opinion, so silence is
/// distinguishable from approval — a rule that returned `allow` when it simply
/// did not apply would mask a later denial.
abstract class GovernanceRule {
  const GovernanceRule();

  GovernanceDomain get domain;
  String get id;
  String get description;

  GovernanceDecision? evaluate(GovernanceContext context);
}

/// The rules governing one domain.
class GovernancePolicy {
  final GovernanceDomain domain;
  final List<GovernanceRule> rules;

  const GovernancePolicy({required this.domain, required this.rules});
}

/// The outcome of evaluating a request.
class GovernanceEvaluation {
  final GovernanceContext context;
  final List<GovernanceDecision> decisions;

  const GovernanceEvaluation({required this.context, required this.decisions});

  /// DENY WINS, then requireApproval, then allow.
  ///
  /// Fail-closed on conflict is the only safe precedence: if any rule refuses,
  /// the request is refused, regardless of how many others permitted it.
  GovernanceOutcome get outcome {
    if (decisions.any((d) => d.outcome == GovernanceOutcome.deny)) {
      return GovernanceOutcome.deny;
    }
    if (decisions.any((d) => d.outcome == GovernanceOutcome.requireApproval)) {
      return GovernanceOutcome.requireApproval;
    }
    return GovernanceOutcome.allow;
  }

  bool get isAllowed => outcome == GovernanceOutcome.allow;

  /// The decisions responsible for the effective outcome — what to show a
  /// user, or log, when something is refused.
  List<GovernanceDecision> get decisive {
    final effective = outcome;
    return [
      for (final d in decisions)
        if (d.outcome == effective) d,
    ];
  }

  String get reason => decisive.isEmpty
      ? 'no rule applied'
      : decisive.map((d) => '${d.ruleId}: ${d.reason}').join('; ');
}

// ── Canonical rules ───────────────────────────────────────────────────────
//
// Each is a real, deterministic decision. None performs I/O, holds state, or
// references a live subsystem.

/// Capabilities an Experience may reach only at or above a given trust level.
/// Anything unlisted is available at every trust level (the clock, for
/// instance, reveals nothing and consumes nothing).
const Map<String, ExperienceTrustLevel> canonicalCapabilityTrustFloor = {
  'http': ExperienceTrustLevel.local,
  'ai': ExperienceTrustLevel.local,
  'knowledge': ExperienceTrustLevel.local,
  'files': ExperienceTrustLevel.local,
  'notifications': ExperienceTrustLevel.local,
};

/// EXPERIENCE TRUST — an Experience below a capability's trust floor is denied.
class CapabilityTrustFloorRule extends GovernanceRule {
  final Map<String, ExperienceTrustLevel> floors;

  const CapabilityTrustFloorRule({this.floors = canonicalCapabilityTrustFloor});

  @override
  GovernanceDomain get domain => GovernanceDomain.experienceTrust;
  @override
  String get id => 'trust.capability_floor';
  @override
  String get description =>
      'An Experience may only use capabilities at or above its trust level.';

  @override
  GovernanceDecision? evaluate(GovernanceContext context) {
    final capabilityId = context.capabilityId;
    if (capabilityId == null) return null;
    final floor = floors[capabilityId];
    if (floor == null) return null;

    if (!context.trustLevel.atLeast(floor)) {
      return GovernanceDecision(
        domain: domain,
        outcome: GovernanceOutcome.deny,
        ruleId: id,
        reason:
            '${context.trustLevel.name} Experience may not use "$capabilityId" (requires ${floor.name} or above)',
      );
    }
    return GovernanceDecision(
      domain: domain,
      outcome: GovernanceOutcome.allow,
      ruleId: id,
      reason:
          '${context.trustLevel.name} meets the ${floor.name} floor for "$capabilityId"',
    );
  }
}

/// PRIVACY — in privacy mode nothing may leave the device.
class PrivacyModeRule extends GovernanceRule {
  static const Set<String> egressCapabilities = {'http', 'ai', 'knowledge'};

  const PrivacyModeRule();

  @override
  GovernanceDomain get domain => GovernanceDomain.privacy;
  @override
  String get id => 'privacy.no_egress';
  @override
  String get description =>
      'Privacy mode forbids any capability that sends data off the device.';

  @override
  GovernanceDecision? evaluate(GovernanceContext context) {
    if (!context.privacyMode) return null;
    final capabilityId = context.capabilityId;
    if (capabilityId == null || !egressCapabilities.contains(capabilityId)) {
      return null;
    }
    return GovernanceDecision(
      domain: domain,
      outcome: GovernanceOutcome.deny,
      ruleId: id,
      reason:
          'privacy mode is on; "$capabilityId" would send data off the device',
    );
  }
}

/// OFFLINE — network-dependent capabilities are unavailable with no network.
class OfflineRule extends GovernanceRule {
  static const Set<String> networkCapabilities = {'http', 'knowledge'};

  const OfflineRule();

  @override
  GovernanceDomain get domain => GovernanceDomain.offline;
  @override
  String get id => 'offline.network_required';
  @override
  String get description =>
      'Network-dependent capabilities are denied while offline.';

  @override
  GovernanceDecision? evaluate(GovernanceContext context) {
    if (!context.isOffline) return null;
    final capabilityId = context.capabilityId;
    if (capabilityId == null || !networkCapabilities.contains(capabilityId)) {
      return null;
    }
    return GovernanceDecision(
      domain: domain,
      outcome: GovernanceOutcome.deny,
      ruleId: id,
      reason: 'device is offline; "$capabilityId" requires network',
    );
  }
}

/// NETWORK — host allowlist. Governance DECIDES which hosts are reachable;
/// `HttpCapability` continues to ENFORCE it. This centralises the policy
/// without moving the enforcement point (IS-R51 Task 9).
class NetworkHostAllowlistRule extends GovernanceRule {
  final List<String> allowedHosts;

  const NetworkHostAllowlistRule({required this.allowedHosts});

  @override
  GovernanceDomain get domain => GovernanceDomain.network;
  @override
  String get id => 'network.host_allowlist';
  @override
  String get description => 'Only allowlisted hosts may be contacted.';

  @override
  GovernanceDecision? evaluate(GovernanceContext context) {
    final host = context.host;
    if (host == null) return null;
    if (allowedHosts.contains(host)) {
      return GovernanceDecision(
        domain: domain,
        outcome: GovernanceOutcome.allow,
        ruleId: id,
        reason: 'host "$host" is allowlisted',
      );
    }
    return GovernanceDecision(
      domain: domain,
      outcome: GovernanceOutcome.deny,
      ruleId: id,
      reason: 'host "$host" is not allowlisted',
    );
  }
}

/// MODEL ACCESS — an untrusted or experimental Experience may not reach a
/// cloud model without explicit approval (IS-R51 Task 8). The Kernel keeps
/// owning reasoning; governance only decides whether access is permitted.
class ModelAccessRule extends GovernanceRule {
  const ModelAccessRule();

  @override
  GovernanceDomain get domain => GovernanceDomain.modelAccess;
  @override
  String get id => 'model.cloud_access';
  @override
  String get description =>
      'Low-trust Experiences need explicit approval to reach a cloud model.';

  @override
  GovernanceDecision? evaluate(GovernanceContext context) {
    if (context.capabilityId != 'ai') return null;
    if (context.trustLevel.atLeast(ExperienceTrustLevel.local)) return null;
    return GovernanceDecision(
      domain: domain,
      outcome: GovernanceOutcome.requireApproval,
      ruleId: id,
      reason:
          '${context.trustLevel.name} Experience requires explicit approval for model access',
    );
  }
}

/// RESOURCE MANAGEMENT — a requested size beyond the ceiling is refused.
class ResourceCeilingRule extends GovernanceRule {
  final int maxRequestBytes;

  const ResourceCeilingRule({this.maxRequestBytes = 5 * 1024 * 1024});

  @override
  GovernanceDomain get domain => GovernanceDomain.resourceManagement;
  @override
  String get id => 'resource.request_ceiling';
  @override
  String get description =>
      'A single request may not exceed the trusted byte ceiling.';

  @override
  GovernanceDecision? evaluate(GovernanceContext context) {
    final requested = context.requestedBytes;
    if (requested == null) return null;
    if (requested > maxRequestBytes) {
      return GovernanceDecision(
        domain: domain,
        outcome: GovernanceOutcome.deny,
        ruleId: id,
        reason:
            'requested $requested bytes exceeds the $maxRequestBytes ceiling',
      );
    }
    return null;
  }
}

/// BACKGROUND EXECUTION — only sufficiently trusted Experiences may run work
/// in the background (IS-R51 Task 7). Scheduler ownership is unchanged;
/// governance only decides eligibility.
class BackgroundExecutionRule extends GovernanceRule {
  const BackgroundExecutionRule();

  @override
  GovernanceDomain get domain => GovernanceDomain.backgroundExecution;
  @override
  String get id => 'background.trust_floor';
  @override
  String get description => 'Background work requires local trust or above.';

  @override
  GovernanceDecision? evaluate(GovernanceContext context) {
    if (context.operation != 'background') return null;
    if (context.trustLevel.atLeast(ExperienceTrustLevel.local)) {
      return GovernanceDecision(
        domain: domain,
        outcome: GovernanceOutcome.allow,
        ruleId: id,
        reason: '${context.trustLevel.name} may run background work',
      );
    }
    return GovernanceDecision(
      domain: domain,
      outcome: GovernanceOutcome.deny,
      ruleId: id,
      reason:
          '${context.trustLevel.name} Experience may not run background work',
    );
  }
}

/// RECOVERY — an Experience that failed to open is quarantined from automatic
/// restore until a user intervenes (IS-R51 Task 10).
class RecoveryQuarantineRule extends GovernanceRule {
  const RecoveryQuarantineRule();

  @override
  GovernanceDomain get domain => GovernanceDomain.recovery;
  @override
  String get id => 'recovery.untrusted_quarantine';
  @override
  String get description =>
      'An untrusted Experience is not automatically restored.';

  @override
  GovernanceDecision? evaluate(GovernanceContext context) {
    if (context.operation != 'restore') return null;
    if (context.trustLevel == ExperienceTrustLevel.untrusted) {
      return GovernanceDecision(
        domain: domain,
        outcome: GovernanceOutcome.deny,
        ruleId: id,
        reason: 'untrusted Experience is quarantined from automatic restore',
      );
    }
    return GovernanceDecision(
      domain: domain,
      outcome: GovernanceOutcome.allow,
      ruleId: id,
      reason: 'restore permitted for ${context.trustLevel.name}',
    );
  }
}

class OperatingSystemGovernanceEngine {
  /// THE canonical rule set. Every governance decision in the application
  /// comes from here, stated once.
  static const List<GovernanceRule> canonicalRules = [
    CapabilityTrustFloorRule(),
    PrivacyModeRule(),
    OfflineRule(),
    ModelAccessRule(),
    ResourceCeilingRule(),
    BackgroundExecutionRule(),
    RecoveryQuarantineRule(),
  ];

  final List<GovernanceRule> rules;

  const OperatingSystemGovernanceEngine({this.rules = canonicalRules});

  /// Rules registered for [domain].
  List<GovernanceRule> rulesFor(GovernanceDomain domain) => [
    for (final r in rules)
      if (r.domain == domain) r,
  ];

  GovernancePolicy policyFor(GovernanceDomain domain) =>
      GovernancePolicy(domain: domain, rules: rulesFor(domain));

  /// Evaluates every rule that has an opinion about [context].
  ///
  /// Rules that return `null` are silent, not approving — which is why
  /// `GovernanceEvaluation.outcome` fails closed on any denial rather than
  /// counting votes.
  GovernanceEvaluation evaluate(
    GovernanceContext context, {
    GovernanceDomain? domain,
  }) {
    final applicable = domain == null ? rules : rulesFor(domain);
    return GovernanceEvaluation(
      context: context,
      decisions: [
        for (final rule in applicable)
          if (rule.evaluate(context) case final decision?) decision,
      ],
    );
  }

  /// Capability authorization (IS-R51 Task 5) — the ONE question
  /// `CapabilityPlatform` asks before enforcing.
  ///
  /// Governance decides; the platform enforces. This method introduces no
  /// registry, no permission manager and no second authorization path: it
  /// returns a verdict and nothing else.
  GovernanceEvaluation authorizeCapability({
    required String capabilityId,
    String? operation,
    ExperienceTrustLevel trustLevel = ExperienceTrustLevel.local,
    String? experienceId,
    String? sessionId,
    bool isOffline = false,
    bool privacyMode = false,
    String? host,
    int? requestedBytes,
  }) {
    return evaluate(
      GovernanceContext(
        capabilityId: capabilityId,
        operation: operation,
        trustLevel: trustLevel,
        experienceId: experienceId,
        sessionId: sessionId,
        isOffline: isOffline,
        privacyMode: privacyMode,
        host: host,
        requestedBytes: requestedBytes,
      ),
    );
  }
}
