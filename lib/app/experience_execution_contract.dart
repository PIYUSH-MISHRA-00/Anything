/// Canonical Experience Execution Contract — Implementation Specification
/// IS-R61. The ONE declaration of what executing an Experience means.
///
/// WHAT THE PHASE 1 AUDIT FOUND, AND HOW IT SHAPED THIS FILE.
///
/// Most of what IS-R61 Phase 2 lists already exists, owned elsewhere and
/// certified. Re-declaring any of it would create the parallel ownership this
/// specification's ABSOLUTE RULES forbid:
///
///     required / optional capabilities   ExperienceManifest (canonical, I-60)
///     compatibility requirements         ExperienceCompatibilityEvaluator (R54)
///     suspension / resume / termination  RuntimePolicyAction +
///                                        WorkspaceLifecyclePolicyEngine (R39)
///     background eligibility DECISION    BackgroundExecutionRule, a governance
///                                        rule with a trust floor (R51)
///     capability ENFORCEMENT             CapabilityPlatform (R49/R51)
///     activation                         ExperienceEntryPipeline (R45)
///     scheduling                         WorkspaceSchedulingEngine
///
/// So this contract DERIVES rather than duplicates. [ExperienceExecutionContract]
/// holds the canonical `ExperienceManifest` and reads capabilities THROUGH it —
/// it re-declares not one capability field. What it adds is the one thing the
/// audit found nowhere in `lib/`: **execution mode**, and the declarative
/// eligibility, isolation and recovery policy that goes with it.
///
/// DECLARATIVE ONLY — THIS IS THE LOAD-BEARING PROPERTY.
///
/// A contract states what an Experience ASKS FOR. It never decides and never
/// enforces:
///
///   * `BackgroundExecutionRule` already refuses background work below `local`
///     trust. A contract declaring `background` does not get it.
///   * `CapabilityPlatform` already refuses an unregistered capability.
///   * `WorkspaceLifecyclePolicyEngine` already decides pause/resume/terminate.
///
/// If a contract could decide any of those, it would become a second governance
/// engine reachable by anything that can write a manifest — which is exactly
/// backwards, because a package is untrusted input. Certified by I-90.
///
/// NOT A SCHEDULER, NOT A RUNTIME, NOT A LIFECYCLE ENGINE. This file computes
/// no schedule, starts no runtime and performs no I/O.
library;

import '../creation/experience_package.dart';

/// How an Experience asks to run.
///
/// Genuinely new: the Phase 1 audit found no execution-mode concept anywhere in
/// `lib/`. Deliberately NOT `ExperienceRuntimeType`
/// (`core/contracts/experience.dart`), which describes how an Experience is
/// RENDERED (auil / flutter / web / hybrid) rather than how it executes — a
/// different subject, and one that lives in the unreachable v1 contracts set
/// (IS-R59 classified it EXPERIMENTAL).
enum ExecutionMode {
  /// Runs while the user is looking at it. The default, and the only mode any
  /// Experience in this repository uses today.
  foreground,

  /// Asks to continue while not in the foreground. Governance decides whether
  /// it may — `BackgroundExecutionRule` requires `local` trust or above.
  background,

  /// Asks to be run at a time rather than on demand. Nothing schedules from a
  /// contract; `WorkspaceSchedulingEngine` remains the only scheduler.
  scheduled,

  /// Runs once and is expected to be torn down; keeps nothing across sessions.
  transient,

  /// Expects its session to survive being backgrounded.
  persistent,

  /// RESERVED — no UI surface. Declared so the vocabulary does not need
  /// widening later; nothing consumes it and no runtime implements it.
  headless,

  /// RESERVED — acts without a user present. Same status: architecture only.
  autonomous,
}

/// What an Experience needs before it can run.
///
/// SPECIFICATION ONLY (Phase 3). Nothing here is enforced by this file; these
/// are declarations a governance or capability decision can later consult.
/// Every field is optional, because a manifest that declares nothing is making
/// the honest statement that it asks for nothing special.
class ExecutionRequirements {
  /// Approximate working-set ceiling in bytes, when the Experience knows it.
  /// Null means "not declared", never "no limit" — those are different claims.
  final int? memoryBytes;

  /// Approximate durable storage in bytes.
  final int? storageBytes;

  /// Experience ids that must already be installed. Distinct from the R53
  /// distribution envelope's `dependencies`, which are a TRANSPORT concern;
  /// these are an EXECUTION precondition.
  final List<String> requiredExperiences;

  /// Whether the Experience expects to run only while Kaalka protection is
  /// active. Declarative — `ExperienceProtectionService` remains the sole owner
  /// of protection, and nothing here can turn it on.
  final bool requiresProtection;

  const ExecutionRequirements({
    this.memoryBytes,
    this.storageBytes,
    this.requiredExperiences = const [],
    this.requiresProtection = false,
  });

  static const ExecutionRequirements none = ExecutionRequirements();

  Map<String, dynamic> toJson() => {
    'memoryBytes': memoryBytes,
    'storageBytes': storageBytes,
    'requiredExperiences': requiredExperiences,
    'requiresProtection': requiresProtection,
  };

  factory ExecutionRequirements.fromJson(Map<String, dynamic> json) =>
      ExecutionRequirements(
        memoryBytes: (json['memoryBytes'] as num?)?.toInt(),
        storageBytes: (json['storageBytes'] as num?)?.toInt(),
        requiredExperiences: [
          for (final e in (json['requiredExperiences'] as List? ?? []))
            e as String,
        ],
        requiresProtection: json['requiresProtection'] == true,
      );
}

/// What an Experience asks to happen when it is interrupted.
///
/// Deliberately expressed with the EXISTING vocabulary: the values mirror
/// `RuntimePolicyAction` (pause / resume / terminate / restore / noAction),
/// which `WorkspaceLifecyclePolicyEngine` has owned since R39. A contract
/// states a preference; that engine still decides, and this file does not
/// import it — the vocabulary is shared, the authority is not.
enum InterruptionPolicy {
  /// Prefer to be paused and resumed later.
  suspend,

  /// Prefer to be terminated; nothing worth preserving.
  terminate,

  /// No preference — the lifecycle engine's default applies.
  unspecified,
}

/// How much separation an Experience asks for.
///
/// Declarative. `CapabilityPlatform` remains the only thing that actually
/// isolates anything, and per-Experience data isolation is already real via
/// `ExperienceDatabase` (one database per Experience).
enum IsolationPolicy {
  /// The default and the only behaviour implemented today: the Experience gets
  /// its own `ExperienceDatabase` and its own capability session.
  standard,

  /// RESERVED — asks for stronger separation than the platform currently
  /// provides. Nothing implements it; declaring it changes nothing today.
  strict,
}

/// THE canonical execution contract (IS-R61 Phase 2).
///
/// One per Experience. It EMBEDS the canonical `ExperienceManifest` and reads
/// identity and capabilities through it, so there is still exactly one manifest
/// and this adds no second declaration of anything the manifest owns.
class ExperienceExecutionContract {
  /// The canonical manifest, embedded unchanged — the same relationship the
  /// R53 distribution envelope has with it.
  final ExperienceManifest manifest;

  /// Contract schema version, so a future field addition is detectable rather
  /// than a silent parse difference.
  final int contractVersion;

  final ExecutionMode mode;
  final ExecutionRequirements requirements;
  final InterruptionPolicy onInterruption;
  final IsolationPolicy isolation;

  /// Whether the Experience asks to be restored after an unclean shutdown.
  /// Declarative: nothing here performs recovery.
  final bool recoverable;

  /// Reserved extension area, carried verbatim. Declared so adding a field
  /// later needs no contract version bump for callers that only pass it
  /// through.
  final Map<String, dynamic> extensions;

  const ExperienceExecutionContract({
    required this.manifest,
    this.contractVersion = currentContractVersion,
    this.mode = ExecutionMode.foreground,
    this.requirements = ExecutionRequirements.none,
    this.onInterruption = InterruptionPolicy.unspecified,
    this.isolation = IsolationPolicy.standard,
    this.recoverable = false,
    this.extensions = const {},
  });

  static const int currentContractVersion = 1;

  /// Identity comes from the manifest. There is no second identity model —
  /// R52 owns identity and provenance.
  String get experienceId => manifest.experienceId;

  /// Capabilities are READ THROUGH the manifest, never re-declared here.
  List<String> get requiredCapabilities => manifest.requiredCapabilities;
  List<String> get optionalCapabilities => manifest.optionalCapabilities;

  /// The default contract for an Experience that declares no execution
  /// preferences — which is every Experience in this repository today.
  ///
  /// This is what makes the contract adoptable without touching creation: an
  /// Experience that says nothing gets a truthful foreground contract rather
  /// than a fabricated one.
  factory ExperienceExecutionContract.defaultFor(ExperienceManifest manifest) =>
      ExperienceExecutionContract(manifest: manifest);

  Map<String, dynamic> toJson() => {
    'contractVersion': contractVersion,
    'manifest': manifest.toJson(),
    'mode': mode.name,
    'requirements': requirements.toJson(),
    'onInterruption': onInterruption.name,
    'isolation': isolation.name,
    'recoverable': recoverable,
    'extensions': extensions,
  };

  factory ExperienceExecutionContract.fromJson(Map<String, dynamic> json) {
    return ExperienceExecutionContract(
      contractVersion: (json['contractVersion'] as num?)?.toInt() ?? 0,
      manifest: ExperienceManifest.fromJson(
        Map<String, dynamic>.from(json['manifest'] as Map),
      ),
      mode: ExecutionMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => ExecutionMode.foreground,
      ),
      requirements: json['requirements'] == null
          ? ExecutionRequirements.none
          : ExecutionRequirements.fromJson(
              Map<String, dynamic>.from(json['requirements'] as Map),
            ),
      onInterruption: InterruptionPolicy.values.firstWhere(
        (p) => p.name == json['onInterruption'],
        orElse: () => InterruptionPolicy.unspecified,
      ),
      isolation: IsolationPolicy.values.firstWhere(
        (i) => i.name == json['isolation'],
        orElse: () => IsolationPolicy.standard,
      ),
      recoverable: json['recoverable'] == true,
      extensions: json['extensions'] == null
          ? const {}
          : Map<String, dynamic>.from(json['extensions'] as Map),
    );
  }
}

/// Why a contract is not executable as written.
enum ExecutionContractFault {
  /// The contract schema is newer than this build understands.
  unsupportedContractVersion,

  /// The embedded manifest is missing something execution depends on.
  manifestIncomplete,

  /// A capability is declared in both the required and optional lists — the
  /// Experience has not decided whether it needs it.
  contradictoryCapabilities,

  /// A required experience id names the Experience itself.
  circularRequirement,

  /// A reserved mode was declared. Nothing implements it, so accepting it
  /// silently would promise execution semantics that do not exist.
  reservedModeNotImplemented,

  /// A declared requirement is not a sane value.
  invalidRequirement,
}

class ExecutionContractFinding {
  final ExecutionContractFault fault;
  final String detail;

  const ExecutionContractFinding(this.fault, this.detail);

  @override
  String toString() => '${fault.name}: $detail';
}

class ExecutionContractValidation {
  final List<ExecutionContractFinding> findings;

  const ExecutionContractValidation(this.findings);

  static const ExecutionContractValidation valid = ExecutionContractValidation(
    [],
  );

  bool get isValid => findings.isEmpty;
}

/// THE execution contract validator (IS-R61 Phase 4).
///
/// PURE. It holds no repository, no platform, no scheduler and no runtime, so
/// it CANNOT execute or schedule even by accident — the type system enforces
/// "validate only" before certification does.
///
/// IT NEVER COMPUTES TRUST and NEVER EVALUATES BUILD COMPATIBILITY. Compatibility
/// against this build is `ExperienceCompatibilityEvaluator`'s job (IS-R54) and
/// this deliberately does not duplicate it: a second compatibility evaluator is
/// forbidden by R54's own I-61, and this validator would be the obvious place
/// to grow one. It checks the contract's INTERNAL consistency and nothing else.
class ExperienceExecutionValidator {
  const ExperienceExecutionValidator();

  ExecutionContractValidation validate(ExperienceExecutionContract contract) {
    final findings = <ExecutionContractFinding>[];

    if (contract.contractVersion <= 0 ||
        contract.contractVersion >
            ExperienceExecutionContract.currentContractVersion) {
      findings.add(
        ExecutionContractFinding(
          ExecutionContractFault.unsupportedContractVersion,
          'contract v${contract.contractVersion} exceeds supported '
          'v${ExperienceExecutionContract.currentContractVersion}',
        ),
      );
    }

    if (contract.manifest.experienceId.isEmpty) {
      findings.add(
        const ExecutionContractFinding(
          ExecutionContractFault.manifestIncomplete,
          'manifest has no experienceId',
        ),
      );
    }
    if (contract.manifest.entryPoint.isEmpty) {
      findings.add(
        const ExecutionContractFinding(
          ExecutionContractFault.manifestIncomplete,
          'manifest has no entryPoint, so there is nothing to execute',
        ),
      );
    }

    // A capability in both lists is a contradiction, not a preference: the
    // Experience has not decided whether it can run without it, and the two
    // answers lead to different enforcement outcomes.
    final both = contract.requiredCapabilities.toSet().intersection(
      contract.optionalCapabilities.toSet(),
    );
    for (final c in both) {
      findings.add(
        ExecutionContractFinding(
          ExecutionContractFault.contradictoryCapabilities,
          'capability "$c" is declared both required and optional',
        ),
      );
    }

    for (final id in contract.requirements.requiredExperiences) {
      if (id == contract.experienceId) {
        findings.add(
          ExecutionContractFinding(
            ExecutionContractFault.circularRequirement,
            'requires itself: "$id"',
          ),
        );
      }
    }

    // Reserved modes are refused rather than accepted-and-ignored. Accepting
    // one would promise execution semantics no runtime implements.
    if (contract.mode == ExecutionMode.headless ||
        contract.mode == ExecutionMode.autonomous) {
      findings.add(
        ExecutionContractFinding(
          ExecutionContractFault.reservedModeNotImplemented,
          '${contract.mode.name} is reserved architecture; no runtime '
          'implements it',
        ),
      );
    }

    final memory = contract.requirements.memoryBytes;
    if (memory != null && memory <= 0) {
      findings.add(
        ExecutionContractFinding(
          ExecutionContractFault.invalidRequirement,
          'memoryBytes must be positive when declared, got $memory',
        ),
      );
    }
    final storage = contract.requirements.storageBytes;
    if (storage != null && storage <= 0) {
      findings.add(
        ExecutionContractFinding(
          ExecutionContractFault.invalidRequirement,
          'storageBytes must be positive when declared, got $storage',
        ),
      );
    }

    return ExecutionContractValidation(findings);
  }
}
