/// SolutionExecutionPlanner — Implementation Milestone R18. Real,
/// deterministic derivation from the SAME already-computed
/// `SemanticSolutionArchitecture` (R17) — zero new AI call, zero new
/// upstream dependency. Mirrors `SolutionArchitecturePlanner`/
/// `CanonicalImplementationPlanner`'s own derivation-function shape.
///
/// Deliberately does NOT invoke `BuildGraphBuilder`/`GenerationPipeline`/
/// any `Generator` itself — this planner only decides WHAT should be
/// executed and WHETHER a real generator exists for it; actually running
/// a generator against `CanonicalImplementationModel`'s `UniversalBuildGraph`
/// remains a separate, real, existing, unmodified pipeline (R10-R13) a
/// caller invokes using this plan's `requiredGenerators`/`actionableTargets`
/// — never duplicated or reimplemented here.
library;

import '../solution_architecture/solution_architecture.dart';
import 'execution_strategy.dart';

class SolutionExecutionPlanner {
  const SolutionExecutionPlanner();

  /// The real `GeneratorMetadata.id` of the one, existing generator this
  /// codebase has (`RuntimeExperienceGenerator`, R13) — named as a plain
  /// string constant here (not an import of the generator itself) so
  /// `lib/execution_planning/` stays a pure planning layer with zero
  /// dependency on `lib/generator_framework/`, matching R18's own
  /// "Generator Framework: Remain unchanged" instruction — this planner
  /// only NAMES the generator a caller should use, it never imports or
  /// invokes it.
  static const String runtimeExperienceGeneratorId =
      'reference.runtime-experience';

  /// The real `GeneratorMetadata.id` of `BackendServiceGenerator`
  /// (Implementation Specification IS-R26, Anything's second real
  /// generator) — named as a plain string constant here for the SAME
  /// reason as [runtimeExperienceGeneratorId]: `lib/execution_planning/`
  /// stays a pure planning layer with zero dependency on
  /// `lib/generator_framework/`.
  static const String backendServiceGeneratorId = 'reference.backend-service';

  /// The real `GeneratorMetadata.id` of `RestApiGenerator` (Implementation
  /// Specification IS-R27, Anything's third real generator) — same naming
  /// convention as the two constants above.
  static const String restApiGeneratorId = 'reference.rest-api';

  /// The 9 R18 targets with zero real signal anywhere in
  /// `SemanticSolutionArchitecture` today — a static, honest fact about
  /// this codebase's current architecture models, not a per-request
  /// computation (mirrors `SolutionArchitecturePlanner.standingGaps`, R17).
  static const Map<ExecutionTargetKind, String> _standingNotApplicable = {
    ExecutionTargetKind.flutterApplication:
        'The Anything host app is itself the one Flutter application every Experience already runs inside; there is no per-solution '
        '"build a standalone Flutter app" target or generator, and none is modeled anywhere upstream.',
    ExecutionTargetKind.graphqlApi:
        'ApiSpecificationModel only models REST-shaped HttpMethod endpoints; no GraphQL concept exists anywhere upstream.',
    ExecutionTargetKind.website:
        'No web-target concept exists anywhere in ArchitectureCandidate or BackendEngineeringPlan to derive from.',
    ExecutionTargetKind.desktopApplication:
        'No platform-selection signal exists anywhere upstream for distinct desktop-OS packaging (the production creation path hardcodes "android" independently of architecture planning).',
    ExecutionTargetKind.mobileApplication:
        'No platform-selection signal exists anywhere upstream for distinct mobile-OS/store packaging (the production creation path hardcodes "android" independently of architecture planning).',
    ExecutionTargetKind.cliTool:
        'No CLI/terminal-interface concept exists anywhere upstream.',
    ExecutionTargetKind.library:
        'No standalone-package/library-distribution concept exists anywhere upstream.',
    ExecutionTargetKind.plugin:
        'No plugin/extension-point concept exists anywhere upstream.',
    ExecutionTargetKind.agent:
        'No autonomous-agent-target concept exists anywhere upstream.',
  };

  ExecutionStrategy plan(SemanticSolutionArchitecture architecture) {
    final requiresBackend = architecture.backend.deployment.requiresBackend;
    final hasApi = architecture.backend.api.endpoints.isNotEmpty;
    final hasFrontend = architecture.frontend.entities.isNotEmpty;
    final secretNames = architecture.backend.deployment.secretReferences
        .map((s) => s.name)
        .toList();

    final targets = <ExecutionTargetPlan>[
      _backendService(requiresBackend, secretNames),
      _restApi(hasApi, requiresBackend),
      _runtimeExperience(
        hasFrontend,
        requiresBackend,
        hasApi && requiresBackend,
      ),
      for (final entry in _standingNotApplicable.entries)
        ExecutionTargetPlan(
          target: entry.key,
          classification: ExecutionTargetClassification.notApplicable,
          reason: entry.value,
        ),
    ];

    return ExecutionStrategy(targets: _assignExecutionOrder(targets));
  }

  /// Implementation Specification IS-R26: `BackendServiceGenerator` now
  /// exists, so `requiresBackend` correctly reaches `applicableWithGenerator`
  /// — the exact "R18 deliberately never invokes a generator, R26 finally
  /// gives Backend Service one" transition this planner's own R18 doc
  /// comment named as the real, deferred gap.
  ExecutionTargetPlan _backendService(
    bool requiresBackend,
    List<String> secretNames,
  ) => requiresBackend
      ? ExecutionTargetPlan(
          target: ExecutionTargetKind.backendService,
          classification: ExecutionTargetClassification.applicableWithGenerator,
          reason:
              'BackendEngineeringPlan.deployment.requiresBackend is true — a real, existing Generator '
              '(BackendServiceGenerator, Implementation Specification IS-R26) produces real, typed backend '
              'specification artifacts.',
          priority: 0,
          requiredGenerators: const [backendServiceGeneratorId],
          validationRequirements: const [
            'Real JSON round-trip of every emitted Artifact (Backend Service artifacts are not an ExperiencePackage, so ExperiencePackageValidator does not apply)',
          ],
          buildRequirements: const [
            'BackendEngineeringPlan (already computed, Implementation Milestone R8)',
          ],
          deploymentRequirements: secretNames,
        )
      : const ExecutionTargetPlan(
          target: ExecutionTargetKind.backendService,
          classification: ExecutionTargetClassification.notApplicable,
          reason:
              'BackendEngineeringPlan.deployment.requiresBackend is false — this solution needs no backend.',
        );

  /// REALITY (confirmed while testing this milestone): `ApiSpecificationModel`
  /// is derived from `InteractionDecision`'s CRUD flags unconditionally
  /// (R8) — a fully-offline app can still carry a non-empty `endpoints`
  /// list even though nothing would ever deploy or call them. The real
  /// execution-relevant signal is therefore BOTH real endpoints AND a
  /// real backend need (`requiresBackend`) — endpoints alone are not
  /// enough to honestly call this target applicable.
  /// Implementation Specification IS-R27: `RestApiGenerator` now exists,
  /// so `hasApi && requiresBackend` correctly reaches `applicableWithGenerator`
  /// — the exact "R18 deliberately never invokes a generator, R27 finally
  /// gives REST API one" transition this method's own R18 doc comment
  /// named as the real, deferred gap (mirrors R26's identical transition
  /// for `_backendService`).
  ExecutionTargetPlan _restApi(bool hasApi, bool requiresBackend) =>
      hasApi && requiresBackend
      ? ExecutionTargetPlan(
          target: ExecutionTargetKind.restApi,
          classification: ExecutionTargetClassification.applicableWithGenerator,
          reason:
              'BackendEngineeringPlan.api.endpoints is non-empty AND deployment.requiresBackend is true — a real, existing '
              'Generator (RestApiGenerator, Implementation Specification IS-R27) produces real, typed REST API specification '
              'artifacts.',
          priority: 1,
          dependencies: const [ExecutionTargetKind.backendService],
          requiredGenerators: const [restApiGeneratorId],
          validationRequirements: const [
            'Real JSON round-trip of every emitted Artifact (REST API artifacts are not an ExperiencePackage, so ExperiencePackageValidator does not apply)',
          ],
          buildRequirements: const [
            'ApiSpecificationModel (already computed, Implementation Milestone R8)',
          ],
        )
      : ExecutionTargetPlan(
          target: ExecutionTargetKind.restApi,
          classification: ExecutionTargetClassification.notApplicable,
          reason: !hasApi
              ? 'BackendEngineeringPlan.api.endpoints is empty — this solution exposes no REST endpoints.'
              : 'BackendEngineeringPlan.api.endpoints is non-empty, but deployment.requiresBackend is false — the computed '
                    'endpoint spec has nothing to deploy behind (ApiSpecificationModel is derived unconditionally from CRUD '
                    'interactions, independent of whether a backend is actually needed).',
        );

  ExecutionTargetPlan _runtimeExperience(
    bool hasFrontend,
    bool requiresBackend,
    bool restApiApplicable,
  ) => hasFrontend
      ? ExecutionTargetPlan(
          target: ExecutionTargetKind.runtimeExperience,
          classification: ExecutionTargetClassification.applicableWithGenerator,
          reason:
              'ArchitectureCandidate.entities is non-empty — a real, existing Generator (RuntimeExperienceGenerator, R13) '
              'produces a real ExperiencePackage the existing Runtime renders.',
          priority: 2,
          // Never a dependency on a target that ends up notApplicable.
          dependencies: [
            if (requiresBackend) ExecutionTargetKind.backendService,
            if (restApiApplicable) ExecutionTargetKind.restApi,
          ],
          requiredGenerators: const [runtimeExperienceGeneratorId],
          validationRequirements: const [
            'ExperiencePackageValidator (lib/creation/package_validator.dart, existing, unmodified)',
          ],
          buildRequirements: const [
            'CanonicalImplementationModel -> UniversalBuildGraph (BuildGraphBuilder, R11, existing, unmodified)',
          ],
        )
      : const ExecutionTargetPlan(
          target: ExecutionTargetKind.runtimeExperience,
          classification: ExecutionTargetClassification.notApplicable,
          reason:
              'ArchitectureCandidate.entities is empty — nothing for a Runtime Experience to render.',
        );

  /// Real topological order: `notApplicable` targets get order 0
  /// (unordered — never executed); applicable targets are ordered by
  /// their own dependency edges, backendService -> restApi ->
  /// runtimeExperience when a full chain applies, or a shorter chain when
  /// upstream targets are not applicable.
  List<ExecutionTargetPlan> _assignExecutionOrder(
    List<ExecutionTargetPlan> targets,
  ) {
    final applicable =
        targets
            .where(
              (t) =>
                  t.classification !=
                  ExecutionTargetClassification.notApplicable,
            )
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));
    final orderIndex = {
      for (var i = 0; i < applicable.length; i++) applicable[i].target: i,
    };

    return [
      for (final t in targets)
        if (orderIndex.containsKey(t.target))
          ExecutionTargetPlan(
            target: t.target,
            classification: t.classification,
            reason: t.reason,
            priority: t.priority,
            dependencies: t.dependencies,
            executionOrder: orderIndex[t.target]!,
            requiredGenerators: t.requiredGenerators,
            validationRequirements: t.validationRequirements,
            buildRequirements: t.buildRequirements,
            deploymentRequirements: t.deploymentRequirements,
          )
        else
          t,
    ];
  }
}
