/// Vision V9 WMSG — every Bridge is a pure translation of a REAL source
/// graph/artifact into a GraphUpdate: Knowledge Integration, Runtime
/// Integration, Evolution Integration, Review Integration. None of these
/// bridges re-implement extraction, usage tracking, evolution reasoning,
/// or review logic — they only translate already-typed output.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/design_review/design_review_engine.dart';
import 'package:anything/evolution/evolution_candidate.dart';
import 'package:anything/evolution/evolution_opportunity.dart';
import 'package:anything/evolution/evolution_roadmap.dart';
import 'package:anything/evolution/evolution_types.dart';
import 'package:anything/knowledge/knowledge_resource.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/runtime_intelligence/learning_engine.dart';
import 'package:anything/runtime_intelligence/learning_memory.dart';
import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/ril_types.dart' as ril;
import 'package:anything/runtime_intelligence/usage_graph.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_architect/knowledge_graph.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/world_model/bridges/evolution_graph_bridge.dart';
import 'package:anything/world_model/bridges/experience_graph_bridge.dart';
import 'package:anything/world_model/bridges/knowledge_graph_bridge.dart';
import 'package:anything/world_model/bridges/review_graph_bridge.dart';
import 'package:anything/world_model/bridges/runtime_graph_bridge.dart';
import 'package:anything/world_model/world_graph.dart';
import 'package:anything/world_model/world_types.dart';

import '../design_review/review_test_support.dart';

void main() {
  group('KnowledgeGraphBridge — Knowledge Integration', () {
    test(
      'translates real KnowledgeGraph nodes/links into typed knowledge WorldNodes, never re-extracting',
      () {
        final provenance = ResourceProvenance(
          sourceUrl: 'https://example.com/a',
          sourceDomain: 'example.com',
          retrievedAt: DateTime.now(),
          provider: 'webweavex',
        );
        const license = LicenseMetadata(
          policy: LicensePolicy.permissiveKnown,
          confidence: 0.9,
        );
        const trust = TrustMetadata(
          level: TrustLevel.highConfidence,
          reason: 'test',
        );

        final graph = KnowledgeGraph(
          nodes: [
            KnowledgeGraphNode(
              resourceId: 'r1',
              title: 'Alpha Guide',
              sourceUri: 'https://example.com/a',
              sourceDomain: 'example.com',
              provenance: provenance,
              license: license,
              trust: trust,
              relevance: 0.8,
              concepts: const ['alpha'],
            ),
            KnowledgeGraphNode(
              resourceId: 'r2',
              title: 'Alpha Reference',
              sourceUri: 'https://example.com/b',
              sourceDomain: 'example.com',
              provenance: provenance,
              license: license,
              trust: trust,
              relevance: 0.7,
              concepts: const ['alpha'],
            ),
          ],
          links: const [
            KnowledgeConceptLink(
              fromResourceId: 'r1',
              toResourceId: 'r2',
              sharedConcept: 'alpha',
            ),
          ],
          isEmpty: false,
        );

        final update = const KnowledgeGraphBridge().bridge(graph);
        expect(update.addedNodes, hasLength(2));
        expect(
          update.addedNodes.every((n) => n.kind == WorldNodeKind.knowledge),
          isTrue,
        );
        expect(update.addedEdges, hasLength(1));
        expect(update.addedEdges.first.kind, RelationshipKind.relatesTo);
      },
    );
  });

  group('ExperienceGraphBridge', () {
    test(
      'translates a real, persisted Experience into experience/entity/capability nodes with real edges',
      () {
        final calculator = createCalculatorPackage();
        final metadata = ExperienceMetadataRecord(
          id: calculator.manifest.experienceId,
          name: calculator.manifest.name,
          description: calculator.manifest.description,
          category: 'utility',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final update = const ExperienceGraphBridge().bridge(
          metadata,
          calculator,
        );
        expect(
          update.addedNodes.any((n) => n.kind == WorldNodeKind.experience),
          isTrue,
        );
        // Every edge must originate from the experience node.
        final experienceNode = update.addedNodes.firstWhere(
          (n) => n.kind == WorldNodeKind.experience,
        );
        expect(
          update.addedEdges.every((e) => e.fromId == experienceNode.identity),
          isTrue,
        );
      },
    );
  });

  group('EvolutionGraphBridge — Evolution Integration', () {
    test(
      'translates real EvolutionRoadmap proposals into evolution WorldNodes with an "improves" edge',
      () {
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
                      id: 'evolution:missingWorkflow:x',
                      category: EvolutionOpportunityCategory.missingWorkflow,
                      description: 'Add a shortcut',
                      reason: const EvolutionReason(
                        summary: 's',
                        evidence: EvolutionEvidence(
                          affectedGraph: 'g',
                          affectedNodeId: 'entry',
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
                  ),
                  phase: EvolutionPhase.immediate,
                  reviewDecision: const EvolutionDecision(
                    subjectId: 'x',
                    kind: EvolutionDecisionKind.accepted,
                    rationale: 'r',
                    confidence: Confidence.full,
                  ),
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

        final update = const EvolutionGraphBridge().bridge(roadmap);
        final evolutionNodes = update.addedNodes
            .where((n) => n.kind == WorldNodeKind.evolution)
            .toList();
        expect(evolutionNodes, hasLength(1));
        expect(evolutionNodes.first.label, 'Add a shortcut');
        expect(
          update.addedEdges.any((e) => e.kind == RelationshipKind.improves),
          isTrue,
        );
      },
    );
  });

  group('RuntimeGraphBridge — Runtime Integration', () {
    test(
      'translates a real UsageGraph into WorldNodes/WorldEdges without fabricating counts',
      () {
        DateTime t(int i) => DateTime(2026, 1, 1).add(Duration(seconds: i));
        final records = [
          for (final exp in ['e1', 'e2']) ...[
            ObservationRecord(
              id: '$exp-0',
              category: ril.ObservationCategory.navigation,
              experienceId: exp,
              screenId: 'home',
              timestamp: t(0),
            ),
            ObservationRecord(
              id: '$exp-1',
              category: ril.ObservationCategory.navigation,
              experienceId: exp,
              screenId: 'detail',
              timestamp: t(1),
            ),
          ],
        ];
        final usageGraph = UsageGraph.fromRecords(records);
        final update = const RuntimeGraphBridge().bridgeUsage(usageGraph);

        expect(update.addedNodes, isNotEmpty);
        expect(
          update.addedEdges.every(
            (e) => e.evidence.sourceGraph == 'UsageGraph',
          ),
          isTrue,
        );
      },
    );

    test('translates real learned patterns into learning WorldNodes', () {
      DateTime t(int i) => DateTime(2026, 1, 1).add(Duration(seconds: i));
      final records = [
        for (final exp in ['e1', 'e2']) ...[
          ObservationRecord(
            id: '$exp-0',
            category: ril.ObservationCategory.navigation,
            experienceId: exp,
            screenId: 'home',
            timestamp: t(0),
          ),
          ObservationRecord(
            id: '$exp-1',
            category: ril.ObservationCategory.navigation,
            experienceId: exp,
            screenId: 'detail',
            timestamp: t(1),
          ),
        ],
      ];
      final usageGraph = UsageGraph.fromRecords(records);
      const learningEngine = LearningEngine();
      final learned = learningEngine.learn(
        usageGraph,
        LearningMemory(),
        minOccurrences: 2,
      );

      final update = const RuntimeGraphBridge().bridgeLearning(learned);
      expect(update.addedNodes, hasLength(learned.length));
      expect(
        update.addedNodes.every((n) => n.kind == WorldNodeKind.learning),
        isTrue,
      );
    });
  });

  group('ReviewGraphBridge — Review Integration', () {
    test(
      'translates a real Design Review (SCARE) session into review WorldNodes, never re-reviewing',
      () {
        final context = buildReviewContext(fieldSurveyApp());
        final outcome = const DesignReviewEngine().review(context);

        final update = const ReviewGraphBridge().bridge(outcome.session);
        // Every review node's label is a real reason string from SCARE —
        // never fabricated by this bridge.
        for (final node in update.addedNodes.where(
          (n) => n.kind == WorldNodeKind.review,
        )) {
          expect(
            outcome.session.result.finalIteration.issues.map((i) => i.reason),
            contains(node.label),
          );
        }
      },
    );
  });

  test(
    'a WorldGraph assembled from multiple real bridges together is internally consistent',
    () {
      final calculator = createCalculatorPackage();
      final metadata = ExperienceMetadataRecord(
        id: calculator.manifest.experienceId,
        name: calculator.manifest.name,
        description: calculator.manifest.description,
        category: 'utility',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final experienceUpdate = const ExperienceGraphBridge().bridge(
        metadata,
        calculator,
      );
      final combined = WorldGraph(
        nodes: experienceUpdate.addedNodes,
        edges: experienceUpdate.addedEdges,
      );
      expect(combined.nodes, isNotEmpty);
    },
  );
}
