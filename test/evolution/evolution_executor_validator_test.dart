/// Vision V7 AEE — EvolutionExecutor (compiles a proposal into the
/// EXISTING ModificationOperation vocabulary and executes it through the
/// existing ModificationEngine — never a second engine) and
/// EvolutionValidator (reuses ExperiencePackageValidator directly).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/creation/modification/experience_modification_spec.dart'
    show ModificationType;
import 'package:anything/creation/modification/modification_engine.dart';
import 'package:anything/evolution/evolution_candidate.dart';
import 'package:anything/evolution/evolution_executor.dart';
import 'package:anything/evolution/evolution_opportunity.dart';
import 'package:anything/evolution/evolution_types.dart';
import 'package:anything/evolution/evolution_validator.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/software_architect/confidence.dart';

EvolutionCandidate _candidateFor(
  EvolutionOpportunityCategory category, {
  String? sourceFeatureId,
  String affectedNodeId = 'entry',
}) {
  return EvolutionCandidate(
    id: 'candidate:${category.name}',
    opportunity: EvolutionOpportunity(
      id: 'evolution:${category.name}:x',
      category: category,
      description: 'test ${category.name}',
      reason: EvolutionReason(
        summary: 'test',
        evidence: EvolutionEvidence(
          affectedGraph: 'test',
          affectedNodeId: affectedNodeId,
          sourceFeatureId: sourceFeatureId,
        ),
        confidence: Confidence.full,
      ),
    ),
    cost: const EvolutionCost(),
    risk: const EvolutionRisk(),
    benefit: const EvolutionBenefit(
      engineeringValue: Confidence.full,
      userValue: Confidence.full,
      maintenanceValue: Confidence.full,
      performanceValue: Confidence.full,
      securityValue: Confidence.full,
      accessibilityValue: Confidence.full,
      offlineValue: Confidence.full,
      futureValue: Confidence.full,
    ),
  );
}

void main() {
  final executor = EvolutionExecutor();
  const validator = EvolutionValidator();

  group('EvolutionExecutor.compile', () {
    test('an unapproved proposal never compiles, regardless of category', () {
      final proposal = EvolutionProposal(
        candidate: _candidateFor(
          EvolutionOpportunityCategory.missingNavigation,
        ),
        phase: EvolutionPhase.immediate,
        reviewDecision: const EvolutionDecision(
          subjectId: 'x',
          kind: EvolutionDecisionKind.accepted,
          rationale: 'r',
          confidence: Confidence.full,
        ),
        approvedForExecution: false,
      );
      final plan = executor.compile(proposal, 'exp-1', '1.0.0');
      expect(plan, isA<EvolutionNotExecutable>());
    });

    test(
      'missingCapability compiles to a real ExperienceModificationSpec requesting the capability',
      () {
        final candidate = _candidateFor(
          EvolutionOpportunityCategory.missingCapability,
          sourceFeatureId: 'feature:capability:knowledge',
        );
        final proposal = EvolutionProposal(
          candidate: candidate,
          phase: EvolutionPhase.immediate,
          reviewDecision: const EvolutionDecision(
            subjectId: 'x',
            kind: EvolutionDecisionKind.accepted,
            rationale: 'r',
            confidence: Confidence.full,
          ),
          approvedForExecution: true,
        );
        final plan = executor.compile(proposal, 'exp-1', '1.0.0');
        expect(plan, isA<EvolutionExecutable>());
        final spec = (plan as EvolutionExecutable).spec;
        expect(spec.requiredCapabilities, ['knowledge']);
      },
    );

    for (final category in [
      EvolutionOpportunityCategory.missingWorkflow,
      EvolutionOpportunityCategory.missingNavigation,
      EvolutionOpportunityCategory.missingSearch,
      EvolutionOpportunityCategory.missingFiltering,
    ]) {
      test(
        '${category.name} compiles to a real addUiNode ModificationOperation',
        () {
          final proposal = EvolutionProposal(
            candidate: _candidateFor(category),
            phase: EvolutionPhase.immediate,
            reviewDecision: const EvolutionDecision(
              subjectId: 'x',
              kind: EvolutionDecisionKind.accepted,
              rationale: 'r',
              confidence: Confidence.full,
            ),
            approvedForExecution: true,
          );
          final plan = executor.compile(proposal, 'exp-1', '1.0.0');
          expect(plan, isA<EvolutionExecutable>());
          final spec = (plan as EvolutionExecutable).spec;
          expect(spec.operations, hasLength(1));
          expect(spec.operations.first.type, ModificationType.addUiNode);
        },
      );
    }

    for (final category in [
      EvolutionOpportunityCategory.missingAccessibility,
      EvolutionOpportunityCategory.missingPerformance,
      EvolutionOpportunityCategory.missingMaintainability,
      EvolutionOpportunityCategory.missingOffline,
      EvolutionOpportunityCategory.missingSynchronization,
    ]) {
      test(
        '${category.name} is honestly reported as not-yet-executable, never a fabricated no-op',
        () {
          final proposal = EvolutionProposal(
            candidate: _candidateFor(category),
            phase: EvolutionPhase.immediate,
            reviewDecision: const EvolutionDecision(
              subjectId: 'x',
              kind: EvolutionDecisionKind.accepted,
              rationale: 'r',
              confidence: Confidence.full,
            ),
            approvedForExecution: true,
          );
          final plan = executor.compile(proposal, 'exp-1', '1.0.0');
          expect(plan, isA<EvolutionNotExecutable>());
          expect((plan as EvolutionNotExecutable).reason, isNotEmpty);
        },
      );
    }
  });

  group('EvolutionExecutor.execute + EvolutionValidator', () {
    test(
      'executing a compiled UI-addition proposal against a real golden-path package produces a valid, updated package',
      () async {
        final calculator = createCalculatorPackage();
        final candidate = _candidateFor(
          EvolutionOpportunityCategory.missingWorkflow,
          affectedNodeId: 'calculator',
        );
        final proposal = EvolutionProposal(
          candidate: candidate,
          phase: EvolutionPhase.immediate,
          reviewDecision: const EvolutionDecision(
            subjectId: 'x',
            kind: EvolutionDecisionKind.accepted,
            rationale: 'r',
            confidence: Confidence.full,
          ),
          approvedForExecution: true,
        );
        final plan = executor.compile(
          proposal,
          calculator.manifest.experienceId,
          calculator.manifest.version,
        );
        final spec = (plan as EvolutionExecutable).spec;

        final result = await executor.execute(calculator, spec);
        expect(result, isA<ModificationReady>());
        final updated = (result as ModificationReady).updatedPackage;

        final validation = validator.validate(updated);
        expect(validation.isValid, isTrue);
        expect(updated.manifest.version, isNot(calculator.manifest.version));
      },
    );
  });
}
