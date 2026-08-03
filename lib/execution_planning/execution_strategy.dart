/// Execution Strategy — Implementation Milestone R18. Real, typed output
/// of [SolutionExecutionPlanner]: for each of R18's 12 requested
/// "Execution Targets," a classification backed by real signal from
/// `SemanticSolutionArchitecture` (R17) — never a fabricated selection
/// mechanism pretending a generator exists where none does.
///
/// REALITY this milestone builds on: only ONE real [Generator]
/// implementation exists anywhere in this codebase
/// (`RuntimeExperienceGenerator`, R13, id `reference.runtime-experience`).
/// R10/R11/R12 each explicitly, repeatedly declined building Flutter/
/// backend/web/desktop/mobile generators. Of the 12 targets, real,
/// traceable signal exists for exactly 3: Runtime Experience (always,
/// when the architecture has any frontend entity), Backend Service
/// (`BackendEngineeringPlan.deployment.requiresBackend`), and REST API
/// (`BackendEngineeringPlan.api.endpoints` non-empty). The other 9
/// (Flutter Application, GraphQL API, Website, Desktop Application,
/// Mobile Application, CLI Tool, Library, Plugin, Agent) have zero real
/// signal anywhere upstream — classified `notApplicable` with a real,
/// specific reason each, mirroring `SolutionArchitecturePlanner`'s own
/// `standingGaps` honesty pattern (R17), which itself continues
/// `CanonicalImplementationModel`'s (R9) identical precedent.
library;

enum ExecutionTargetKind {
  runtimeExperience,
  flutterApplication,
  backendService,
  restApi,
  graphqlApi,
  website,
  desktopApplication,
  mobileApplication,
  cliTool,
  library,
  plugin,
  agent,
}

/// `notApplicable`: zero real signal this target is even needed.
/// `applicableNoGenerator`: real signal the target is needed, but no
/// [Generator] implementation exists to fulfill it yet — a real,
/// structurally meaningful gap, never silently dropped.
/// `applicableWithGenerator`: real signal AND a real, existing generator.
enum ExecutionTargetClassification { notApplicable, applicableNoGenerator, applicableWithGenerator }

/// One target's real, honest plan entry. Every field traces to real
/// upstream data or is empty/zero when there is none — nothing fabricated.
class ExecutionTargetPlan {
  final ExecutionTargetKind target;
  final ExecutionTargetClassification classification;

  /// Always real and specific — the concrete signal (or absence of one)
  /// this classification was derived from.
  final String reason;

  /// 0 = plan first. Only meaningful among `applicable*` targets;
  /// `notApplicable` targets carry 0 (unordered, never executed).
  final int priority;

  /// Real structural dependencies among the applicable targets (e.g.
  /// Runtime Experience depends on Backend Service when the solution has
  /// backend presence) — never a dependency on a `notApplicable` target.
  final List<ExecutionTargetKind> dependencies;

  /// Final topological position among applicable targets, 0-based.
  final int executionOrder;

  /// Real `GeneratorMetadata.id` value(s) — empty unless
  /// `applicableWithGenerator`, since only then does a real generator
  /// exist to name.
  final List<String> requiredGenerators;

  /// Real, referenced validator names this target's output must pass
  /// through — never a re-implementation of validation logic here.
  final List<String> validationRequirements;

  /// Real, referenced build-time prerequisites (e.g. the real
  /// `UniversalBuildGraph` construction step a generator needs).
  final List<String> buildRequirements;

  /// Real, named deployment prerequisites — e.g. the actual
  /// `SecretReference` names a backend-shaped target would need,
  /// never a fabricated infrastructure claim.
  final List<String> deploymentRequirements;

  const ExecutionTargetPlan({
    required this.target,
    required this.classification,
    required this.reason,
    this.priority = 0,
    this.dependencies = const [],
    this.executionOrder = 0,
    this.requiredGenerators = const [],
    this.validationRequirements = const [],
    this.buildRequirements = const [],
    this.deploymentRequirements = const [],
  });
}

class ExecutionStrategy {
  final List<ExecutionTargetPlan> targets;

  const ExecutionStrategy({this.targets = const []});

  /// The only targets an actual [Generator] run should ever be attempted
  /// for.
  List<ExecutionTargetPlan> get actionableTargets =>
      targets.where((t) => t.classification == ExecutionTargetClassification.applicableWithGenerator).toList()
        ..sort((a, b) => a.executionOrder.compareTo(b.executionOrder));

  List<ExecutionTargetPlan> get applicableTargets => targets
      .where((t) => t.classification != ExecutionTargetClassification.notApplicable)
      .toList()
    ..sort((a, b) => a.executionOrder.compareTo(b.executionOrder));

  ExecutionTargetPlan forTarget(ExecutionTargetKind kind) => targets.firstWhere((t) => t.target == kind);
}
