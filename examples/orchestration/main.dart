// ignore_for_file: avoid_print
// Examples print to stdout on purpose: their whole output IS the lesson.
// Scoped to this file so the repository-wide lint keeps protecting app code.

/// How an execution request becomes a decision — and what refuses it.
///
///     flutter test examples/orchestration/main.dart
///
/// The orchestrator is a COORDINATOR. It accepts a request, validates the
/// execution contract when one is present, resolves a policy and a priority,
/// and forwards an admitted request to the one scheduler.
///
/// It never opens a package, constructs a runtime, pushes a route, computes
/// trust or enforces a capability. Certified by I-92. Nothing in `lib/` reaches
/// the scheduler except through it — certified by I-91.
library;

import 'package:anything/app/experience_execution_contract.dart';
import 'package:anything/app/experience_orchestrator.dart';
import 'package:anything/creation/experience_package.dart';

ExperienceManifest manifest({String entryPoint = 'home'}) {
  final now = DateTime.utc(2026, 1, 1);
  return ExperienceManifest(
    experienceId: 'water-tracker',
    name: 'Water Tracker',
    description: 'Logs daily water intake',
    category: 'health',
    entryPoint: entryPoint,
    version: '1.0.0',
    createdAt: now,
    updatedAt: now,
  );
}

void show(String label, OrchestrationDecision d) {
  final refusal = d.refusal == null ? '' : '  refusal=${d.refusal!.name}';
  print(
    '  ${label.padRight(46)} '
    'admitted=${d.admitted.toString().padRight(5)} '
    'policy=${d.policy.name.padRight(14)} '
    'priority=${d.priority.name.padRight(11)}$refusal',
  );
  for (final f in d.findings) {
    print('      └─ ${f.fault.name}: ${f.detail}');
  }
}

void main() {
  // No scheduler is supplied, so nothing can be forwarded. `decide()` is pure
  // by construction — separated from `orchestrate()` precisely so that
  // deciding provably executes nothing.
  const orchestrator = ExperienceOrchestrator();

  print('── Trigger decides the policy ──');
  show(
    'a person tapped it',
    orchestrator.decide(
      const ExecutionRequest(
        trigger: ExecutionTrigger.userInitiated,
        sessionId: 's-1',
      ),
    ),
  );
  show(
    'the workspace switcher selected it',
    orchestrator.decide(
      const ExecutionRequest(
        trigger: ExecutionTrigger.workspaceSwitch,
        sessionId: 's-1',
      ),
    ),
  );
  show(
    'the app moved to the background',
    orchestrator.decide(
      const ExecutionRequest(trigger: ExecutionTrigger.lifecycle),
    ),
  );

  print('');
  print('── What is refused ──');
  show(
    'RESERVED autonomous trigger',
    orchestrator.decide(
      const ExecutionRequest(trigger: ExecutionTrigger.autonomous),
    ),
  );
  show(
    'a contract that is invalid as written',
    orchestrator.decide(
      ExecutionRequest(
        trigger: ExecutionTrigger.userInitiated,
        sessionId: 's-1',
        contract: ExperienceExecutionContract(
          manifest: manifest(entryPoint: ''),
        ),
      ),
    ),
  );

  // Admitted, but there is nothing the scheduler could act on. Refusing would
  // change real behaviour (this path was a plain navigator push before), and
  // pretending it scheduled would be a lie. So: admitted AND marked.
  print('');
  print('── Admitted, but nothing to schedule ──');
  show(
    'no session id',
    orchestrator.decide(
      const ExecutionRequest(trigger: ExecutionTrigger.userInitiated),
    ),
  );

  // THE LOAD-BEARING DIRECTION. A contract NARROWS what a trigger allows; it
  // never widens it. A person waiting always outranks what an Experience asked
  // for — the alternative is a package deciding it gets the foreground, and a
  // package is untrusted input.
  print('');
  print('── A contract narrows; it never widens ──');
  for (final mode in [
    ExecutionMode.foreground,
    ExecutionMode.background,
    ExecutionMode.persistent,
    ExecutionMode.scheduled,
  ]) {
    final userTapped = orchestrator.decide(
      ExecutionRequest(
        trigger: ExecutionTrigger.userInitiated,
        sessionId: 's-1',
        contract: ExperienceExecutionContract(manifest: manifest(), mode: mode),
      ),
    );
    final wentToBackground = orchestrator.decide(
      ExecutionRequest(
        trigger: ExecutionTrigger.lifecycle,
        sessionId: 's-1',
        contract: ExperienceExecutionContract(manifest: manifest(), mode: mode),
      ),
    );
    print(
      '  contract declares ${mode.name.padRight(11)} → '
      'user tap: ${userTapped.policy.name.padRight(14)} '
      'lifecycle: ${wentToBackground.policy.name}',
    );
  }
  print('  ↑ the user-initiated column never changes, whatever is declared');

  // Priority orders orchestration and NOTHING else. It is deliberately never
  // passed to the scheduler — adding a priority parameter there would be
  // redesigning the one component that owns scheduling.
  print('');
  print('── Priority orders a batch, highest first ──');
  final batch = orchestrator.orchestrateAll(const [
    ExecutionRequest(trigger: ExecutionTrigger.lifecycle),
    ExecutionRequest(trigger: ExecutionTrigger.autonomous),
    ExecutionRequest(trigger: ExecutionTrigger.userInitiated, sessionId: 's-1'),
  ]);
  for (final d in batch) {
    print('  ${d.priority.name.padRight(12)} ${d.policy.name}');
  }

  print('');
  print('("No tests ran" below is expected — this is an example, not a test.)');
}
