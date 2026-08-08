/// Vision V8 RIL — PredictionEngine: deterministic, frequency-ranked
/// forecasts, never a domain-specific guess.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/pattern.dart';
import 'package:anything/runtime_intelligence/prediction_engine.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/runtime_intelligence/usage_graph.dart';

void main() {
  const engine = PredictionEngine();

  group('predictNextAction', () {
    test('ranks the more frequent next screen first, deterministically', () {
      DateTime base(int i) => DateTime(2026, 1, 1).add(Duration(seconds: i));
      final records = <ObservationRecord>[];
      for (final exp in ['e1', 'e2', 'e3']) {
        records.add(
          ObservationRecord(
            id: '$exp-0',
            category: ObservationCategory.navigation,
            experienceId: exp,
            screenId: 'home',
            timestamp: base(0),
          ),
        );
        records.add(
          ObservationRecord(
            id: '$exp-1',
            category: ObservationCategory.navigation,
            experienceId: exp,
            screenId: 'detail',
            timestamp: base(1),
          ),
        );
      }
      // One extra session goes home -> settings instead — less frequent.
      records.add(
        ObservationRecord(
          id: 'e4-0',
          category: ObservationCategory.navigation,
          experienceId: 'e4',
          screenId: 'home',
          timestamp: base(0),
        ),
      );
      records.add(
        ObservationRecord(
          id: 'e4-1',
          category: ObservationCategory.navigation,
          experienceId: 'e4',
          screenId: 'settings',
          timestamp: base(1),
        ),
      );

      final graph = UsageGraph.fromRecords(records);
      final predictions = engine.predictNextAction(graph, 'home');

      expect(predictions.first.description, contains('detail'));
      expect(
        predictions.first.confidence.score,
        greaterThanOrEqualTo(predictions.last.confidence.score),
      );
    });

    test('an unvisited screen produces no predictions — never fabricated', () {
      final graph = UsageGraph.fromRecords(const []);
      expect(engine.predictNextAction(graph, 'nonexistent'), isEmpty);
    });
  });

  group('predictAutomationOpportunities', () {
    test(
      'only sequential-workflow patterns above the confidence threshold become predictions',
      () {
        const strongWorkflow = Pattern(
          id: 'p1',
          kind: PatternKind.sequentialWorkflow,
          description: 'a -> b -> c',
          evidence: [],
          confidence: PatternConfidence(score: 0.9, reason: 'strong'),
        );
        const weakWorkflow = Pattern(
          id: 'p2',
          kind: PatternKind.sequentialWorkflow,
          description: 'x -> y -> z',
          evidence: [],
          confidence: PatternConfidence(score: 0.1, reason: 'weak'),
        );
        const notAWorkflow = Pattern(
          id: 'p3',
          kind: PatternKind.frequentCapability,
          description: 'capability used often',
          evidence: [],
          confidence: PatternConfidence(
            score: 0.9,
            reason: 'strong but wrong kind',
          ),
        );

        final predictions = engine.predictAutomationOpportunities([
          strongWorkflow,
          weakWorkflow,
          notAWorkflow,
        ], minConfidence: 0.5);
        expect(predictions, hasLength(1));
        expect(predictions.first.description, contains('a -> b -> c'));
      },
    );
  });
}
