/// Canonical Experience Orchestrator — Implementation Specification IS-R62.
/// The ONE place an execution request is decided before it reaches the
/// scheduler.
///
/// WHAT THE PHASE 1 AUDIT FOUND, AND HOW IT SHAPED THIS FILE.
///
/// `ExperienceEntryPipeline` (R45) is already the ONE canonical ENTRY
/// mechanism, certified by I-02/I-16/I-17. Every user-initiated open —
/// Recent list, the Experiences list, protection resume, the workspace
/// switcher's live-runtime case — flows through it and reaches
/// `WorkspaceSchedulingEngine` via `ExperienceActivationManager.activate()`.
/// Building a second thing that accepts execution requests and navigates
/// would be a parallel entry pipeline, which R45's invariants forbid.
///
/// So R62 does NOT re-enter that ground. The audit found only three real
/// calls into the scheduler anywhere in reachable `lib/`:
///
///     experience_activation_manager.dart:105  scheduleForeground()
///     workspace_switcher.dart:105             scheduleForeground()
///     experience_host_screen.dart:399         scheduleActiveTransition()
///
/// The last two BYPASS the entry pipeline entirely: the switcher's
/// no-live-runtime fallback and the host screen's lifecycle notification each
/// reach the scheduler directly. Between them there was no single point where
/// an execution request could be represented, refused, or reasoned about —
/// which is also why nothing has ever consumed the IS-R61 execution contract
/// (gap G-56).
///
/// This file is that single point. It is what R62 adds and all it adds.
///
/// OWNERSHIP — WHAT THIS DOES NOT DO.
///
///     ExperienceOrchestrator          DECIDES whether and how       R62
///     WorkspaceSchedulingEngine       SCHEDULES                     R42
///     WorkspaceRuntimeSupervisor      SUPERVISES runtimes           R40/R41
///     AnythingRuntime                 EXECUTES                      —
///     ExperienceEntryPipeline         ENTERS / navigates            R45
///     WorkspaceLifecyclePolicyEngine  DECIDES pause/resume          R39
///     ExperienceExecutionContract     DECLARES                      R61
///     OperatingSystemGovernanceEngine DECIDES governance            R51
///     CapabilityPlatform              ENFORCES                      R49/R51
///
/// THE ORCHESTRATOR NEVER EXECUTES AN EXPERIENCE. It opens no package,
/// constructs no runtime, pushes no route, touches no `AnythingRuntime`,
/// computes no trust and enforces no capability. It resolves a request into a
/// decision and, when admitted, forwards to the scheduler — which remains the
/// sole owner of scheduling. Certified by I-92.
library;

import 'experience_execution_contract.dart';
import 'workspace_scheduling_engine.dart';

/// Why execution was requested.
///
/// These are the triggers the Phase 1 audit found in reachable `lib/`, not an
/// invented taxonomy. IS-R62 Phase 1 also lists "scheduled", "retained" and
/// "startup"; the audit found no such trigger:
///
///   * nothing schedules a FUTURE execution — `WorkspaceSchedulingEngine`
///     moves already-open runtimes between foreground and background;
///   * `RetentionPolicyEngine` (R50) decides DATA retention, not execution;
///   * `main()` executes no Experience at startup;
///   * `BackgroundCoordinator` is DORMANT — zero `lib/` importers (IS-R59).
///
/// They are therefore absent here rather than fabricated.
enum ExecutionTrigger {
  /// A person tapped something: Recent, the Experiences list, or protection
  /// resume. Six real call sites, all through `ExperienceEntryPipeline`.
  userInitiated,

  /// The workspace switcher selected a session. Two real paths — one with a
  /// live runtime (through the entry pipeline) and one without (which reached
  /// the scheduler directly before R62).
  workspaceSwitch,

  /// An OS-level app lifecycle transition. `ExperienceHostScreen` reached the
  /// scheduler directly for this before R62.
  lifecycle,

  /// RESERVED — acting without a person present. Nothing produces this
  /// trigger; it is REFUSED, not silently accepted. Same position IS-R61 took
  /// on `ExecutionMode.autonomous`.
  autonomous,
}

/// How execution should proceed. The vocabulary IS-R62 Phase 3 names.
///
/// A policy is a decision ABOUT execution; it performs none. No branch of this
/// enum runs work.
enum ExecutionPolicy {
  /// A person is waiting. Becomes a foreground schedule.
  userInitiated,

  /// Should be the active runtime.
  foreground,

  /// Should continue, but not as the active runtime.
  background,

  /// Admitted but not to be scheduled now. Nothing defers today; a deferred
  /// decision forwards nothing, and says so.
  deferred,

  /// Asked to run at a time rather than now. Reachable only from a contract
  /// declaring `ExecutionMode.scheduled`. No future-execution mechanism
  /// exists, so this forwards nothing — recorded as gap G-59 rather than
  /// faked with a `Timer`.
  scheduled,

  /// RESERVED. Refused.
  autonomous,
}

/// Canonical priority (IS-R62 Phase 4).
///
/// Priority INFLUENCES ORCHESTRATION ONLY — it orders decisions within a
/// batch ([ExperienceOrchestrator.orchestrateAll]) and is reported on every
/// decision. It is deliberately NOT passed to the scheduler: scheduling
/// remains `WorkspaceSchedulingEngine`'s, and inventing a priority parameter
/// on it would be redesigning the scheduler, which R62 forbids.
enum ExecutionPriority {
  /// A person is waiting on it.
  interactive,

  /// Everything else that runs now.
  normal,

  /// Runs, but yields to anything above.
  background,

  /// Not now.
  idle,
}

/// Why a request was refused. A closed vocabulary, so a caller reacts to a
/// reason rather than parsing a message.
enum OrchestrationRefusal {
  /// A reserved trigger or policy. Nothing implements it.
  reserved,

  /// An execution contract was supplied and is not valid as written.
  invalidContract,

  /// The request names no session, so there is nothing the scheduler could
  /// act on. Not an error — the pre-R62 code path for this was a plain
  /// navigator push with no scheduling, and that stays true.
  noSchedulableSession,
}

/// One request to execute an Experience.
///
/// [contract] is optional because nothing produces one from a real package
/// yet (G-25/G-56). When absent, the orchestrator decides from the trigger
/// alone — which is exactly what the three pre-R62 call sites did implicitly.
/// When present, it is VALIDATED, making this the first consumer of IS-R61.
class ExecutionRequest {
  final ExecutionTrigger trigger;

  /// The workspace session to act on. Null for a request that has no
  /// resolvable session — the real "Recent list" case R44 documented.
  final String? sessionId;

  final String? experienceId;

  /// The IS-R61 execution contract, when one is known.
  final ExperienceExecutionContract? contract;

  const ExecutionRequest({
    required this.trigger,
    this.sessionId,
    this.experienceId,
    this.contract,
  });
}

/// What the orchestrator decided. Never what happened — the scheduler owns
/// that.
class OrchestrationDecision {
  final bool admitted;
  final ExecutionPolicy policy;
  final ExecutionPriority priority;
  final OrchestrationRefusal? refusal;

  /// Contract faults, when a contract was supplied and rejected. Surfaced
  /// verbatim from `ExperienceExecutionValidator` — never re-worded and never
  /// re-derived.
  final List<ExecutionContractFinding> findings;

  /// Whether this decision actually reached the scheduler. False for a
  /// refusal, and false for an admitted-but-not-schedulable decision
  /// (`deferred`, `scheduled`, or no session) — so a caller can tell
  /// "declined" from "admitted, nothing to do yet".
  final bool forwarded;

  const OrchestrationDecision({
    required this.admitted,
    required this.policy,
    required this.priority,
    this.refusal,
    this.findings = const [],
    this.forwarded = false,
  });

  OrchestrationDecision _forwarded(bool value) => OrchestrationDecision(
    admitted: admitted,
    policy: policy,
    priority: priority,
    refusal: refusal,
    findings: findings,
    forwarded: value,
  );
}

/// THE Experience Orchestrator (IS-R62 Phase 2).
///
/// A coordinator. It accepts execution requests, validates the execution
/// contract when one is present, resolves a policy and a priority, and
/// forwards an admitted request to the scheduler.
///
/// IT NEVER EXECUTES. The scheduler schedules, the supervisor supervises and
/// `AnythingRuntime` executes; none of them is reachable from here except the
/// scheduler, and only through its own existing public API.
class ExperienceOrchestrator {
  /// The ONE scheduler. Optional for the same reason every other seam in this
  /// repository is optional since R32: the two UI call sites that hold a
  /// nullable scheduler must keep working when it is absent.
  final WorkspaceSchedulingEngine? scheduler;

  /// The canonical IS-R61 validator. This orchestrator re-implements no
  /// validation rule of its own.
  final ExperienceExecutionValidator validator;

  const ExperienceOrchestrator({
    this.scheduler,
    this.validator = const ExperienceExecutionValidator(),
  });

  /// Decide, then forward.
  Future<OrchestrationDecision> orchestrate(ExecutionRequest request) async {
    final decision = decide(request);
    if (!decision.admitted) return decision;

    final sessionId = request.sessionId;
    final engine = scheduler;
    if (engine == null) return decision;

    switch (decision.policy) {
      case ExecutionPolicy.userInitiated:
      case ExecutionPolicy.foreground:
        if (sessionId == null) return decision;
        await engine.scheduleForeground(sessionId);
        return decision._forwarded(true);
      case ExecutionPolicy.background:
        await engine.scheduleActiveTransition();
        return decision._forwarded(true);
      case ExecutionPolicy.deferred:
      case ExecutionPolicy.scheduled:
      case ExecutionPolicy.autonomous:
        // Admitted, but there is no mechanism to forward to. Saying so beats
        // inventing one.
        return decision;
    }
  }

  /// The decision alone, with no side effect at all.
  ///
  /// Separated from [orchestrate] so the decision is testable without a
  /// scheduler, and so it is provable that deciding executes nothing.
  OrchestrationDecision decide(ExecutionRequest request) {
    if (request.trigger == ExecutionTrigger.autonomous) {
      return const OrchestrationDecision(
        admitted: false,
        policy: ExecutionPolicy.autonomous,
        priority: ExecutionPriority.idle,
        refusal: OrchestrationRefusal.reserved,
      );
    }

    // Contract validation is DELEGATED to the canonical IS-R61 validator.
    final contract = request.contract;
    if (contract != null) {
      final validation = validator.validate(contract);
      if (!validation.isValid) {
        return OrchestrationDecision(
          admitted: false,
          policy: _policyFor(request),
          priority: ExecutionPriority.idle,
          refusal: OrchestrationRefusal.invalidContract,
          findings: validation.findings,
        );
      }
    }

    final policy = _policyFor(request);
    if (policy == ExecutionPolicy.autonomous) {
      return const OrchestrationDecision(
        admitted: false,
        policy: ExecutionPolicy.autonomous,
        priority: ExecutionPriority.idle,
        refusal: OrchestrationRefusal.reserved,
      );
    }

    // A request that names no session cannot be scheduled. It is ADMITTED —
    // the pre-R62 behaviour for this case was a plain navigator push with no
    // scheduling, and that stays exactly true — but it is marked so a caller
    // can tell it apart from a real schedule.
    final needsSession =
        policy == ExecutionPolicy.userInitiated ||
        policy == ExecutionPolicy.foreground;
    if (needsSession && request.sessionId == null) {
      return OrchestrationDecision(
        admitted: true,
        policy: policy,
        priority: _priorityFor(policy),
        refusal: OrchestrationRefusal.noSchedulableSession,
      );
    }

    return OrchestrationDecision(
      admitted: true,
      policy: policy,
      priority: _priorityFor(policy),
    );
  }

  /// Decide a batch, highest priority first.
  ///
  /// This is what the priority model is FOR (Phase 4): it orders orchestration
  /// and nothing else. The scheduler is never told a priority.
  List<OrchestrationDecision> orchestrateAll(
    Iterable<ExecutionRequest> requests,
  ) {
    final decisions = requests.map(decide).toList();
    // Stable: `sort` is not, so decisions of equal priority would otherwise
    // reorder arbitrarily and the result would not be reproducible.
    final indexed = [
      for (var i = 0; i < decisions.length; i++) (i, decisions[i]),
    ];
    indexed.sort((a, b) {
      final byPriority = a.$2.priority.index.compareTo(b.$2.priority.index);
      return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// Trigger + declared mode -> policy.
  ///
  /// The contract only ever narrows: a person waiting always outranks what an
  /// Experience asked for, because the alternative is a package deciding it
  /// gets the foreground.
  ExecutionPolicy _policyFor(ExecutionRequest request) {
    switch (request.trigger) {
      case ExecutionTrigger.userInitiated:
      case ExecutionTrigger.workspaceSwitch:
        return ExecutionPolicy.userInitiated;
      case ExecutionTrigger.lifecycle:
        return _fromMode(request.contract?.mode) ?? ExecutionPolicy.background;
      case ExecutionTrigger.autonomous:
        return ExecutionPolicy.autonomous;
    }
  }

  /// The IS-R61 declared mode, read as a preference. Reserved modes map to
  /// the reserved policy, which is refused — the validator already refuses
  /// them, so this is the second of two independent refusals.
  ExecutionPolicy? _fromMode(ExecutionMode? mode) {
    switch (mode) {
      case null:
      case ExecutionMode.foreground:
      case ExecutionMode.transient:
        return null;
      case ExecutionMode.background:
      case ExecutionMode.persistent:
        return ExecutionPolicy.background;
      case ExecutionMode.scheduled:
        return ExecutionPolicy.scheduled;
      case ExecutionMode.headless:
      case ExecutionMode.autonomous:
        return ExecutionPolicy.autonomous;
    }
  }

  ExecutionPriority _priorityFor(ExecutionPolicy policy) {
    switch (policy) {
      case ExecutionPolicy.userInitiated:
        return ExecutionPriority.interactive;
      case ExecutionPolicy.foreground:
        return ExecutionPriority.normal;
      case ExecutionPolicy.background:
        return ExecutionPriority.background;
      case ExecutionPolicy.deferred:
      case ExecutionPolicy.scheduled:
      case ExecutionPolicy.autonomous:
        return ExecutionPriority.idle;
    }
  }
}
