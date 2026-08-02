/// Vision V10 RC — Evolution/World identity unification: when a real
/// AppBlueprint is supplied, an EvolutionRoadmap proposal's affected
/// entity resolves to the EXACT SAME EntityIdentity ExperienceGraphBridge
/// computes for that real entity — one entity, one identity, no
/// duplicate graph nodes. Resolves V9's own documented limitation.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/creation/experience_package.dart';
import 'package:anything/evolution/evolution_candidate.dart';
import 'package:anything/evolution/evolution_opportunity.dart';
import 'package:anything/evolution/evolution_roadmap.dart';
import 'package:anything/evolution/evolution_types.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/world_model/bridges/evolution_graph_bridge.dart';
import 'package:anything/world_model/bridges/experience_graph_bridge.dart';
import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  test('an evolution proposal affecting a real, known entity unifies with ExperienceGraphBridge\'s identity for it', () {
    final blueprint = AppBlueprint(
      id: 'app-1',
      name: 'Test App',
      description: 'test',
      entities: const [
        BlueprintEntity(
          id: 'entry',
          name: 'Entry',
          fields: [BlueprintField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)],
        ),
      ],
    );

    final roadmap = EvolutionRoadmap(
      fingerprint: 'fp',
      generatedAt: DateTime.now(),
      milestones: [
        EvolutionMilestone(
          phase: EvolutionPhase.immediate,
          proposals: [
            EvolutionProposal(
              candidate: EvolutionCandidate(
                id: 'candidate:x',
                opportunity: EvolutionOpportunity(
                  id: 'evolution:missingWorkflow:entry',
                  category: EvolutionOpportunityCategory.missingWorkflow,
                  description: 'Add a shortcut',
                  reason: const EvolutionReason(
                    summary: 's',
                    evidence: EvolutionEvidence(affectedGraph: 'g', affectedNodeId: 'entry'),
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
              ),
              phase: EvolutionPhase.immediate,
              reviewDecision: const EvolutionDecision(subjectId: 'x', kind: EvolutionDecisionKind.accepted, rationale: 'r', confidence: Confidence.full),
            ),
          ],
        ),
        const EvolutionMilestone(phase: EvolutionPhase.current),
        const EvolutionMilestone(phase: EvolutionPhase.next),
        const EvolutionMilestone(phase: EvolutionPhase.later),
        const EvolutionMilestone(phase: EvolutionPhase.future),
        const EvolutionMilestone(phase: EvolutionPhase.experimental),
      ],
    );

    final evolutionUpdate = const EvolutionGraphBridge().bridge(roadmap, blueprint: blueprint);
    final evolutionEntityNode = evolutionUpdate.addedNodes.firstWhere((n) => n.kind == WorldNodeKind.entity);

    // The same entity, built via ExperienceGraphBridge from a real
    // ExperiencePackage whose DataSchema entity has the identical
    // name+field-type shape.
    final calculator = createCalculatorPackage();
    final withEntryEntity = ExperiencePackage(
      packageVersion: calculator.packageVersion,
      manifest: calculator.manifest,
      interface: calculator.interface,
      behavior: calculator.behavior,
      state: calculator.state,
      data: const DataSchema(
        entities: [
          DataEntitySchema(id: 'entry', name: 'Entry', fields: [DataFieldSchema(id: 'title', name: 'Title', type: 'string', required: true)]),
        ],
        schemaVersion: 1,
      ),
      services: calculator.services,
      networkDeclarations: calculator.networkDeclarations,
      capabilityDeclarations: calculator.capabilityDeclarations,
      permissionDeclarations: calculator.permissionDeclarations,
      provenance: calculator.provenance,
      integrity: calculator.integrity,
    );
    final metadata = ExperienceMetadataRecord(
      id: withEntryEntity.manifest.experienceId,
      name: withEntryEntity.manifest.name,
      description: withEntryEntity.manifest.description,
      category: 'utility',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final experienceUpdate = const ExperienceGraphBridge().bridge(metadata, withEntryEntity);
    final experienceEntityNode = experienceUpdate.addedNodes.firstWhere((n) => n.kind == WorldNodeKind.entity);

    expect(evolutionEntityNode.identity, experienceEntityNode.identity);
  });

  test('an evolution proposal affecting an unknown id (not a real blueprint entity) never fabricates a match', () {
    final blueprint = AppBlueprint(id: 'app-1', name: 'Test App', description: 'test', entities: const []);
    final roadmap = EvolutionRoadmap(
      fingerprint: 'fp',
      generatedAt: DateTime.now(),
      milestones: [
        EvolutionMilestone(
          phase: EvolutionPhase.immediate,
          proposals: [
            EvolutionProposal(
              candidate: EvolutionCandidate(
                id: 'candidate:y',
                opportunity: EvolutionOpportunity(
                  id: 'evolution:missingOffline:sync',
                  category: EvolutionOpportunityCategory.missingOffline,
                  description: 'Add offline support',
                  reason: const EvolutionReason(
                    summary: 's',
                    evidence: EvolutionEvidence(affectedGraph: 'g', affectedNodeId: 'synchronization:strategy'),
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
              ),
              phase: EvolutionPhase.immediate,
              reviewDecision: const EvolutionDecision(subjectId: 'y', kind: EvolutionDecisionKind.accepted, rationale: 'r', confidence: Confidence.full),
            ),
          ],
        ),
        const EvolutionMilestone(phase: EvolutionPhase.current),
        const EvolutionMilestone(phase: EvolutionPhase.next),
        const EvolutionMilestone(phase: EvolutionPhase.later),
        const EvolutionMilestone(phase: EvolutionPhase.future),
        const EvolutionMilestone(phase: EvolutionPhase.experimental),
      ],
    );

    final update = const EvolutionGraphBridge().bridge(roadmap, blueprint: blueprint);
    final entityNode = update.addedNodes.firstWhere((n) => n.kind == WorldNodeKind.entity);
    // Falls back to the raw-id anchor — never a fabricated structural match.
    expect(entityNode.identity, EntityIdentity.stable(WorldNodeKind.entity, 'synchronization:strategy'));
  });
}
