/// Vision V8 RIL — RuntimeIntelligenceEngine end-to-end: Learn ->
/// Recommend -> Review -> Predict -> Plan Automation, deterministic.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/runtime_intelligence/learning_memory.dart';
import 'package:anything/runtime_intelligence/observation_memory.dart';
import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/runtime_intelligence/runtime_intelligence_engine.dart';

ObservationMemory _memoryWithWorkflow() {
  DateTime t(int i) => DateTime(2026, 1, 1).add(Duration(seconds: i));
  final memory = ObservationMemory();
  for (final exp in ['e1', 'e2']) {
    memory.record(ObservationRecord(id: '$exp-0', category: ObservationCategory.navigation, experienceId: exp, screenId: 'task_app', timestamp: t(0)));
    memory.record(ObservationRecord(id: '$exp-1', category: ObservationCategory.navigation, experienceId: exp, screenId: 'calendar', timestamp: t(1)));
    memory.record(ObservationRecord(id: '$exp-2', category: ObservationCategory.navigation, experienceId: exp, screenId: 'reminder', timestamp: t(2)));
  }
  return memory;
}

void main() {
  const engine = RuntimeIntelligenceEngine();

  test('a real observed workflow produces learned patterns, reviewed recommendations, and an automation plan', () {
    final learningMemory = LearningMemory();
    final result = engine.run(_memoryWithWorkflow(), learningMemory, minOccurrences: 2);

    expect(result.learned, isNotEmpty);
    expect(result.recommendations, isNotEmpty);
    expect(result.decisions, hasLength(result.recommendations.length));
    expect(result.acceptedRecommendations, isNotEmpty);
    expect(result.automationPlans, isNotEmpty);
  });

  test('the engine is deterministic: identical observations always produce identical recommendations', () {
    final resultA = engine.run(_memoryWithWorkflow(), LearningMemory(), minOccurrences: 2);
    final resultB = engine.run(_memoryWithWorkflow(), LearningMemory(), minOccurrences: 2);

    expect(
      resultA.recommendations.map((r) => r.id).toSet(),
      resultB.recommendations.map((r) => r.id).toSet(),
    );
  });

  test('empty observations produce an empty, honest result — never a fabricated pattern', () {
    final result = engine.run(ObservationMemory(), LearningMemory());
    expect(result.learned, isEmpty);
    expect(result.recommendations, isEmpty);
    expect(result.automationPlans, isEmpty);
  });
}
