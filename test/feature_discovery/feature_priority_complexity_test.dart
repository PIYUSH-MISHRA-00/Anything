/// Vision V4 FDI — FeaturePriorityAnalyzer (all 5 priority levels reachable
/// from real structural signals) and FeatureComplexityAnalyzer (typed
/// ComplexityLevel per cost dimension, never an arbitrary number).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/feature_complexity_analyzer.dart';
import 'package:anything/feature_discovery/feature_priority_analyzer.dart';
import 'package:anything/feature_discovery/feature_types.dart';
import 'package:anything/software_architect/requirement_graph.dart';

const _priorityAnalyzer = FeaturePriorityAnalyzer();
const _complexityAnalyzer = FeatureComplexityAnalyzer();

RequirementGraph _requirementsWithCapability(
  String capId,
  RequirementSource source,
) {
  return RequirementGraph(
    nodes: [
      RequirementNode(
        id: 'capability:$capId',
        type: RequirementNodeType.capability,
        label: capId,
        source: source,
      ),
    ],
  );
}

void main() {
  group('FeaturePriorityAnalyzer', () {
    test(
      'data/persistence/navigation/validation/state are always mandatory',
      () {
        for (final category in [
          FeatureCategory.data,
          FeatureCategory.persistence,
          FeatureCategory.navigation,
          FeatureCategory.validation,
          FeatureCategory.state,
        ]) {
          final candidate = FeatureCandidate(
            id: 'feature:x',
            name: 'X',
            category: category,
            rationale: 'r',
          );
          final result = _priorityAnalyzer.analyze(
            candidate,
            requirements: const RequirementGraph(),
          );
          expect(
            result.priority,
            FeaturePriority.mandatory,
            reason: category.name,
          );
        }
      },
    );

    test(
      'explicit known capability is mandatory; inferred known capability is recommended',
      () {
        final explicitCandidate = const FeatureCandidate(
          id: 'feature:capability:clock',
          name: 'Capability — clock',
          category: FeatureCategory.capability,
          rationale: 'r',
        );
        final explicitResult = _priorityAnalyzer.analyze(
          explicitCandidate,
          requirements: _requirementsWithCapability(
            'clock',
            RequirementSource.explicit,
          ),
        );
        expect(explicitResult.priority, FeaturePriority.mandatory);

        final inferredResult = _priorityAnalyzer.analyze(
          explicitCandidate,
          requirements: _requirementsWithCapability(
            'clock',
            RequirementSource.inferred,
          ),
        );
        expect(inferredResult.priority, FeaturePriority.recommended);
      },
    );

    test(
      'a capability with no implementation is experimental with zero confidence',
      () {
        final candidate = const FeatureCandidate(
          id: 'feature:capability:bluetooth',
          name: 'Capability — bluetooth',
          category: FeatureCategory.capability,
          rationale: 'r',
        );
        final result = _priorityAnalyzer.analyze(
          candidate,
          requirements: _requirementsWithCapability(
            'bluetooth',
            RequirementSource.explicit,
          ),
        );
        expect(result.priority, FeaturePriority.experimental);
        expect(result.decision.confidence.score, 0.0);
      },
    );

    test(
      'Kaalka protection is optional; credential storage is future (dormant today)',
      () {
        final protection = const FeatureCandidate(
          id: 'feature:security:protection',
          name: 'Data protection',
          category: FeatureCategory.security,
          rationale: 'r',
        );
        final credential = const FeatureCandidate(
          id: 'feature:security:credential_storage',
          name: 'Credential storage',
          category: FeatureCategory.security,
          rationale: 'r',
        );
        expect(
          _priorityAnalyzer
              .analyze(protection, requirements: const RequirementGraph())
              .priority,
          FeaturePriority.optional,
        );
        expect(
          _priorityAnalyzer
              .analyze(credential, requirements: const RequirementGraph())
              .priority,
          FeaturePriority.future,
        );
      },
    );

    test(
      'offline strategy is mandatory only when the rationale states "fully offline"',
      () {
        final fullyOffline = const FeatureCandidate(
          id: 'feature:offline',
          name: 'Offline strategy',
          category: FeatureCategory.offline,
          rationale:
              'No network dependency declared — app must work fully offline.',
        );
        final cacheThenOnline = const FeatureCandidate(
          id: 'feature:offline',
          name: 'Offline strategy',
          category: FeatureCategory.offline,
          rationale: 'Network is used for a declared purpose.',
        );
        expect(
          _priorityAnalyzer
              .analyze(fullyOffline, requirements: const RequirementGraph())
              .priority,
          FeaturePriority.mandatory,
        );
        expect(
          _priorityAnalyzer
              .analyze(cacheThenOnline, requirements: const RequirementGraph())
              .priority,
          FeaturePriority.recommended,
        );
      },
    );
  });

  group('FeatureComplexityAnalyzer', () {
    test('every dimension is a typed ComplexityLevel, never a raw number', () {
      final candidate = const FeatureCandidate(
        id: 'feature:offline',
        name: 'Offline strategy',
        category: FeatureCategory.offline,
        rationale: 'r',
      );
      final complexity = _complexityAnalyzer.analyze(candidate);
      expect(complexity.implementation, isA<ComplexityLevel>());
      expect(complexity.engineering, isA<ComplexityLevel>());
      expect(complexity.runtime, isA<ComplexityLevel>());
      expect(complexity.memoryCost, isA<ComplexityLevel>());
      expect(complexity.storageCost, isA<ComplexityLevel>());
      expect(complexity.batteryCost, isA<ComplexityLevel>());
      expect(complexity.networkCost, isA<ComplexityLevel>());
      expect(complexity.maintenanceCost, isA<ComplexityLevel>());
      expect(complexity.modificationCost, isA<ComplexityLevel>());
    });

    test(
      'offline is high implementation/engineering complexity; persistence is low',
      () {
        final offline = const FeatureCandidate(
          id: 'feature:offline',
          name: 'x',
          category: FeatureCategory.offline,
          rationale: 'r',
        );
        final persistence = const FeatureCandidate(
          id: 'feature:persistence:e',
          name: 'x',
          category: FeatureCategory.persistence,
          rationale: 'r',
        );
        expect(
          _complexityAnalyzer.analyze(offline).implementation,
          ComplexityLevel.high,
        );
        expect(
          _complexityAnalyzer.analyze(persistence).implementation,
          ComplexityLevel.low,
        );
      },
    );

    test(
      'an unimplemented capability costs more to build than an implemented one',
      () {
        final known = const FeatureCandidate(
          id: 'feature:capability:clock',
          name: 'x',
          category: FeatureCategory.capability,
          rationale: 'r',
        );
        final unknown = const FeatureCandidate(
          id: 'feature:capability:bluetooth',
          name: 'x',
          category: FeatureCategory.capability,
          rationale: 'r',
        );
        expect(
          _complexityAnalyzer.analyze(known).implementation,
          ComplexityLevel.low,
        );
        expect(
          _complexityAnalyzer.analyze(unknown).implementation,
          ComplexityLevel.high,
        );
      },
    );
  });
}
