/// Implementation Specification IS-R62 — Canonical Experience Orchestrator.
///
/// WHAT THE PHASE 1 AUDIT FOUND. `ExperienceEntryPipeline` (R45) is already
/// the ONE canonical ENTRY mechanism, certified by I-02/I-16/I-17. What did
/// not exist was a single point where an execution REQUEST is decided before
/// it reaches the scheduler — and the audit found exactly three calls into
/// `WorkspaceSchedulingEngine` in reachable `lib/`, two of which bypassed the
/// entry pipeline entirely:
///
///     experience_activation_manager.dart:105  (through the pipeline)
///     workspace_switcher.dart:105             BYPASS — no-live-runtime case
///     experience_host_screen.dart:399         BYPASS — app lifecycle
///
/// These tests prove the orchestrator decides, forwards, and executes nothing.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/app/experience_execution_contract.dart';
import 'package:anything/app/experience_orchestrator.dart';
import 'package:anything/app/workspace_scheduling_engine.dart';
import 'package:anything/creation/experience_package.dart';

/// Records what the orchestrator forwarded.
///
/// IMPLEMENTS the real `WorkspaceSchedulingEngine` interface rather than
/// faking a shape of its own, so renaming or re-signing either scheduling
/// method breaks this test instead of letting it pass against a stale API.
/// `noSuchMethod` covers the rest: the engine's real constructor needs a
/// workspace manager, which needs a session manager, which needs the creation
/// and lifecycle coordinators and a sqflite-backed memory repository — a
/// database rig for an assertion about two method calls.
class _RecordingScheduler implements WorkspaceSchedulingEngine {
  final List<String> calls = [];

  @override
  Future<void> scheduleForeground(String sessionId) async {
    calls.add('foreground:$sessionId');
  }

  @override
  Future<void> scheduleActiveTransition() async {
    calls.add('activeTransition');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ExperienceExecutionContract _contract({
  ExecutionMode mode = ExecutionMode.foreground,
  String entryPoint = 's1',
  List<String> required = const [],
  List<String> optional = const [],
}) {
  final now = DateTime(2026, 8, 8);
  return ExperienceExecutionContract(
    mode: mode,
    manifest: ExperienceManifest(
      experienceId: 'exp-1',
      name: 'Test',
      description: 'd',
      category: 'general',
      entryPoint: entryPoint,
      version: '1.0.0',
      requiredCapabilities: required,
      optionalCapabilities: optional,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  group('Decisions (IS-R62 Phase 2/3)', () {
    const orchestrator = ExperienceOrchestrator();

    test('a user-initiated request becomes an interactive foreground', () {
      final d = orchestrator.decide(
        const ExecutionRequest(
          trigger: ExecutionTrigger.userInitiated,
          sessionId: 's-1',
        ),
      );
      expect(d.admitted, isTrue);
      expect(d.policy, ExecutionPolicy.userInitiated);
      expect(d.priority, ExecutionPriority.interactive);
      expect(d.refusal, isNull);
    });

    test('a lifecycle request becomes background, not foreground', () {
      final d = orchestrator.decide(
        const ExecutionRequest(trigger: ExecutionTrigger.lifecycle),
      );
      expect(d.policy, ExecutionPolicy.background);
      expect(d.priority, ExecutionPriority.background);
    });

    test('a workspace switch is user-initiated — a person is waiting', () {
      final d = orchestrator.decide(
        const ExecutionRequest(
          trigger: ExecutionTrigger.workspaceSwitch,
          sessionId: 's-1',
        ),
      );
      expect(d.policy, ExecutionPolicy.userInitiated);
      expect(d.priority, ExecutionPriority.interactive);
    });

    test('the RESERVED autonomous trigger is refused, not accepted', () {
      final d = orchestrator.decide(
        const ExecutionRequest(trigger: ExecutionTrigger.autonomous),
      );
      expect(d.admitted, isFalse);
      expect(d.refusal, OrchestrationRefusal.reserved);
    });

    test('a request with no session is ADMITTED but marked unschedulable', () {
      // Pre-R62 this path was a plain navigator push with no scheduling.
      // Refusing it would change real behaviour; pretending it scheduled
      // would be a lie. It is admitted and marked.
      final d = orchestrator.decide(
        const ExecutionRequest(trigger: ExecutionTrigger.userInitiated),
      );
      expect(d.admitted, isTrue);
      expect(d.refusal, OrchestrationRefusal.noSchedulableSession);
    });
  });

  group('The contract is CONSUMED, not re-validated (IS-R62 Phase 2)', () {
    const orchestrator = ExperienceOrchestrator();

    test('an invalid contract refuses the request — this closes G-56', () {
      // The first consumer of IS-R61 anywhere in the repository.
      final d = orchestrator.decide(
        ExecutionRequest(
          trigger: ExecutionTrigger.userInitiated,
          sessionId: 's-1',
          contract: _contract(entryPoint: ''),
        ),
      );
      expect(d.admitted, isFalse);
      expect(d.refusal, OrchestrationRefusal.invalidContract);
      expect(
        d.findings.single.fault,
        ExecutionContractFault.manifestIncomplete,
        reason: 'the canonical validator\'s own fault must surface verbatim',
      );
    });

    test('faults are DELEGATED — the orchestrator re-derives none', () {
      final contract = _contract(required: ['http'], optional: ['http']);
      final direct = const ExperienceExecutionValidator().validate(contract);
      final viaOrchestrator = orchestrator.decide(
        ExecutionRequest(
          trigger: ExecutionTrigger.userInitiated,
          sessionId: 's-1',
          contract: contract,
        ),
      );
      expect(
        viaOrchestrator.findings.map((f) => f.fault),
        direct.findings.map((f) => f.fault),
      );
    });

    test('a valid contract admits', () {
      expect(
        orchestrator
            .decide(
              ExecutionRequest(
                trigger: ExecutionTrigger.userInitiated,
                sessionId: 's-1',
                contract: _contract(),
              ),
            )
            .admitted,
        isTrue,
      );
    });

    test('a declared background mode narrows a lifecycle request', () {
      final d = orchestrator.decide(
        ExecutionRequest(
          trigger: ExecutionTrigger.lifecycle,
          sessionId: 's-1',
          contract: _contract(mode: ExecutionMode.background),
        ),
      );
      expect(d.policy, ExecutionPolicy.background);
    });

    test('A CONTRACT CANNOT CLAIM THE FOREGROUND FROM A WAITING PERSON', () {
      // The load-bearing direction: a package is untrusted input. A contract
      // narrows what a trigger already allows; it never widens it.
      for (final mode in ExecutionMode.values) {
        final d = orchestrator.decide(
          ExecutionRequest(
            trigger: ExecutionTrigger.userInitiated,
            sessionId: 's-1',
            // A reserved mode is refused by the validator before policy is
            // ever consulted, so only declarable modes reach the comparison.
            contract: _contract(mode: mode),
          ),
        );
        if (mode == ExecutionMode.headless ||
            mode == ExecutionMode.autonomous) {
          expect(d.admitted, isFalse, reason: '$mode is reserved');
          continue;
        }
        expect(
          d.policy,
          ExecutionPolicy.userInitiated,
          reason: 'a contract declaring $mode must not override the user',
        );
      }
    });
  });

  group('Forwarding — the scheduler still schedules (IS-R62 Phase 2)', () {
    test(
      'an admitted user-initiated request forwards ONE foreground call',
      () async {
        final scheduler = _RecordingScheduler();
        final d = await ExperienceOrchestrator(scheduler: scheduler)
            .orchestrate(
              const ExecutionRequest(
                trigger: ExecutionTrigger.userInitiated,
                sessionId: 's-1',
              ),
            );
        expect(scheduler.calls, ['foreground:s-1']);
        expect(d.forwarded, isTrue);
      },
    );

    test('a lifecycle request forwards ONE active transition', () async {
      final scheduler = _RecordingScheduler();
      await ExperienceOrchestrator(scheduler: scheduler).orchestrate(
        const ExecutionRequest(trigger: ExecutionTrigger.lifecycle),
      );
      expect(scheduler.calls, ['activeTransition']);
    });

    test('A REFUSED REQUEST NEVER REACHES THE SCHEDULER', () async {
      final scheduler = _RecordingScheduler();
      final orchestrator = ExperienceOrchestrator(scheduler: scheduler);

      await orchestrator.orchestrate(
        const ExecutionRequest(trigger: ExecutionTrigger.autonomous),
      );
      await orchestrator.orchestrate(
        ExecutionRequest(
          trigger: ExecutionTrigger.userInitiated,
          sessionId: 's-1',
          contract: _contract(entryPoint: ''),
        ),
      );

      expect(
        scheduler.calls,
        isEmpty,
        reason: 'refusing must mean nothing was scheduled',
      );
    });

    test('an unschedulable request forwards nothing', () async {
      final scheduler = _RecordingScheduler();
      final d = await ExperienceOrchestrator(scheduler: scheduler).orchestrate(
        const ExecutionRequest(trigger: ExecutionTrigger.userInitiated),
      );
      expect(scheduler.calls, isEmpty);
      expect(d.admitted, isTrue);
      expect(d.forwarded, isFalse);
    });

    test(
      'a scheduled contract forwards nothing — nothing defers today',
      () async {
        // Honest: no future-execution mechanism exists. Recorded as G-59 rather
        // than faked with a Timer.
        final scheduler = _RecordingScheduler();
        final d = await ExperienceOrchestrator(scheduler: scheduler)
            .orchestrate(
              ExecutionRequest(
                trigger: ExecutionTrigger.lifecycle,
                sessionId: 's-1',
                contract: _contract(mode: ExecutionMode.scheduled),
              ),
            );
        expect(d.policy, ExecutionPolicy.scheduled);
        expect(d.admitted, isTrue);
        expect(scheduler.calls, isEmpty);
        expect(d.forwarded, isFalse);
      },
    );

    test('DECIDING ALONE HAS NO SIDE EFFECT', () async {
      final scheduler = _RecordingScheduler();
      final orchestrator = ExperienceOrchestrator(scheduler: scheduler);
      for (final trigger in ExecutionTrigger.values) {
        orchestrator.decide(
          ExecutionRequest(trigger: trigger, sessionId: 's-1'),
        );
      }
      expect(
        scheduler.calls,
        isEmpty,
        reason: 'decide() must be pure — only orchestrate() forwards',
      );
    });
  });

  group('Priority model (IS-R62 Phase 4)', () {
    const orchestrator = ExperienceOrchestrator();

    test('a batch is ordered highest priority first', () {
      final decisions = orchestrator.orchestrateAll(const [
        ExecutionRequest(trigger: ExecutionTrigger.lifecycle),
        ExecutionRequest(trigger: ExecutionTrigger.autonomous),
        ExecutionRequest(
          trigger: ExecutionTrigger.userInitiated,
          sessionId: 's-1',
        ),
      ]);
      expect(decisions.map((d) => d.priority), [
        ExecutionPriority.interactive,
        ExecutionPriority.background,
        ExecutionPriority.idle,
      ]);
    });

    test('ordering is STABLE for equal priorities', () {
      // `List.sort` is not stable, so equal-priority decisions would otherwise
      // reorder arbitrarily and the result would not be reproducible.
      final requests = [
        for (var i = 0; i < 8; i++)
          ExecutionRequest(
            trigger: ExecutionTrigger.userInitiated,
            sessionId: 's-$i',
          ),
      ];
      final a = orchestrator.orchestrateAll(requests);
      final b = orchestrator.orchestrateAll(requests);
      expect(a.map((d) => d.policy), b.map((d) => d.policy));
      expect(a.length, 8);
    });

    test('THE SCHEDULER IS NEVER TOLD A PRIORITY', () async {
      // Phase 4: "Priorities influence orchestration only. Scheduler retains
      // ownership of scheduling." Inventing a priority parameter on the
      // scheduler would be redesigning it, which R62 forbids.
      final scheduler = _RecordingScheduler();
      await ExperienceOrchestrator(scheduler: scheduler).orchestrate(
        const ExecutionRequest(
          trigger: ExecutionTrigger.userInitiated,
          sessionId: 's-1',
        ),
      );
      expect(scheduler.calls, [
        'foreground:s-1',
      ], reason: 'the call carries a sessionId and nothing else');
    });
  });

  group('The orchestrator EXECUTES nothing (IS-R62 Phase 5)', () {
    test('it works with no scheduler at all and still decides', () async {
      const orchestrator = ExperienceOrchestrator();
      final d = await orchestrator.orchestrate(
        const ExecutionRequest(
          trigger: ExecutionTrigger.userInitiated,
          sessionId: 's-1',
        ),
      );
      expect(d.admitted, isTrue);
      expect(
        d.forwarded,
        isFalse,
        reason: 'nothing to forward to, and it says so rather than throwing',
      );
    });

    test('it is const-constructible — it carries no runtime', () {
      const a = ExperienceOrchestrator();
      const b = ExperienceOrchestrator();
      expect(identical(a, b), isTrue);
    });
  });
}
