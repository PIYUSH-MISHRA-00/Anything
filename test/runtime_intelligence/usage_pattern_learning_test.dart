/// Vision V8 RIL — UsageGraph aggregation, PatternDetector (all 4 kinds
/// + false positives), and LearningEngine/LearningMemory.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/runtime_intelligence/learning_engine.dart';
import 'package:anything/runtime_intelligence/learning_memory.dart';
import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/pattern_detector.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/runtime_intelligence/usage_graph.dart';

List<ObservationRecord> _navSequence(String experienceId, List<String> screens, {DateTime? start}) {
  final base = start ?? DateTime(2026, 1, 1);
  return [
    for (var i = 0; i < screens.length; i++)
      ObservationRecord(
        id: 'r-$experienceId-$i',
        category: ObservationCategory.navigation,
        experienceId: experienceId,
        screenId: screens[i],
        timestamp: base.add(Duration(seconds: i)),
      ),
  ];
}

void main() {
  group('UsageGraph.fromRecords', () {
    test('aggregates usage counts and co-occurrence across multiple sessions, never crossing experiences', () {
      final records = [
        ..._navSequence('exp-a', ['home', 'detail', 'home']),
        ..._navSequence('exp-b', ['home', 'settings']),
      ];
      final graph = UsageGraph.fromRecords(records);

      expect(graph.nodeById('home')?.usageCount, 3);
      expect(graph.nodeById('detail')?.usageCount, 1);
      // "home -> detail" appears once in exp-a; "home -> settings" once in exp-b.
      // Never "detail -> settings" (that would mean cross-experience bleed).
      expect(graph.edges.any((e) => e.fromId == 'detail' && e.toId == 'settings'), isFalse);
    });
  });

  group('PatternDetector', () {
    const detector = PatternDetector();

    test('a frequent screen pair is detected once above threshold, not below', () {
      final belowThreshold = UsageGraph.fromRecords(_navSequence('exp', ['home', 'detail']));
      expect(detector.detect(belowThreshold, minOccurrences: 2), isEmpty);

      final atThreshold = UsageGraph.fromRecords([
        ..._navSequence('exp-1', ['home', 'detail']),
        ..._navSequence('exp-2', ['home', 'detail']),
      ]);
      final patterns = detector.detect(atThreshold, minOccurrences: 2);
      expect(patterns.any((p) => p.kind == PatternKind.frequentFeaturePair), isTrue);
    });

    test('a frequent capability is detected from real UsageGraph capability nodes', () {
      final records = [
        for (var i = 0; i < 3; i++)
          ObservationRecord(
            id: 'cap-$i',
            category: ObservationCategory.capabilityUsage,
            capabilityId: 'knowledge',
            timestamp: DateTime(2026, 1, 1),
          ),
      ];
      final graph = UsageGraph.fromRecords(records);
      final patterns = detector.detect(graph, minOccurrences: 2);
      expect(patterns.any((p) => p.kind == PatternKind.frequentCapability && p.description.contains('knowledge')), isTrue);
    });

    test('a navigation loop requires both directions above threshold', () {
      final oneDirectionOnly = UsageGraph.fromRecords([
        ..._navSequence('exp-1', ['a', 'b']),
        ..._navSequence('exp-2', ['a', 'b']),
      ]);
      expect(detector.detect(oneDirectionOnly, minOccurrences: 2).any((p) => p.kind == PatternKind.navigationLoop), isFalse);

      final bothDirections = UsageGraph.fromRecords([
        ..._navSequence('exp-1', ['a', 'b']),
        ..._navSequence('exp-2', ['a', 'b']),
        ..._navSequence('exp-3', ['b', 'a']),
        ..._navSequence('exp-4', ['b', 'a']),
      ]);
      expect(detector.detect(bothDirections, minOccurrences: 2).any((p) => p.kind == PatternKind.navigationLoop), isTrue);
    });

    test('a 3-screen sequential workflow is detected from two chained frequent edges — '
        'the "creates task app -> calendar -> reminder" shape, structurally, no domain names involved', () {
      final records = [
        ..._navSequence('exp-1', ['task_list', 'calendar', 'reminder']),
        ..._navSequence('exp-2', ['task_list', 'calendar', 'reminder']),
      ];
      final graph = UsageGraph.fromRecords(records);
      final patterns = detector.detect(graph, minOccurrences: 2);
      final workflow = patterns.where((p) => p.kind == PatternKind.sequentialWorkflow).toList();
      expect(workflow, isNotEmpty);
      expect(workflow.first.description, contains('task_list'));
      expect(workflow.first.description, contains('calendar'));
      expect(workflow.first.description, contains('reminder'));
    });
  });

  group('LearningEngine + LearningMemory', () {
    test('learning is deterministic: the same UsageGraph always yields the same patterns', () {
      const engine = LearningEngine();
      final graph = UsageGraph.fromRecords([
        ..._navSequence('exp-1', ['home', 'detail']),
        ..._navSequence('exp-2', ['home', 'detail']),
      ]);

      final memoryA = LearningMemory();
      final memoryB = LearningMemory();
      final recordsA = engine.learn(graph, memoryA, minOccurrences: 2);
      final recordsB = engine.learn(graph, memoryB, minOccurrences: 2);

      expect(recordsA.map((r) => r.pattern.id).toSet(), recordsB.map((r) => r.pattern.id).toSet());
    });

    test('every learning pass is versioned, never overwriting a prior version', () {
      const engine = LearningEngine();
      final memory = LearningMemory();
      final graph = UsageGraph.fromRecords([
        ..._navSequence('exp-1', ['home', 'detail']),
        ..._navSequence('exp-2', ['home', 'detail']),
      ]);

      engine.learn(graph, memory, minOccurrences: 2);
      final firstVersion = memory.currentVersion;
      engine.learn(graph, memory, minOccurrences: 2);
      final secondVersion = memory.currentVersion;

      expect(secondVersion, greaterThan(firstVersion));
      expect(memory.records.length, greaterThan(0));
    });
  });
}
