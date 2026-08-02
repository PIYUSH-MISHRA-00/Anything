/// Vision V4 FDI — Capability Discovery: every required capability becomes
/// a real, typed Capability feature, priced honestly against what this
/// codebase actually implements — never hardcoded to a specific app.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/feature_discovery/feature_types.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart' show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/synthesis/application_reasoner.dart';

const _requirementExtractor = RequirementExtractor();
const _engine = FeatureDiscoveryEngine();

IntentUnderstanding _understanding() {
  return IntentUnderstanding(
    intentId: 'test-${DateTime.now().microsecondsSinceEpoch}',
    objective: 'test',
    category: IntentCategory.create,
    existingExperience: const ExistingExperienceResolution(status: ExistingExperienceStatus.notChecked),
    desiredOutcome: '',
    confidence: 0.9,
    networkNeed: NetworkNeed.none,
    creationNeed: CreationNeed.definitelyNeeded,
    modificationNeed: ModificationNeed.notNeeded,
  );
}

FeatureGraph _planFor(List<String> capabilities) {
  final app = SemanticApp(
    name: 'Capability Probe',
    purpose: 'p',
    entities: [const SemanticEntity(id: 'e', name: 'E')],
    requiredCapabilities: capabilities,
  );
  final requirements = _requirementExtractor.extract(app: app, understanding: _understanding());
  return _engine.plan(FeatureDiscoveryContext(app: app, requirements: requirements));
}

void main() {
  test('every implemented capability (Clock/Notifications/HTTP/AI/Knowledge/File) is discovered, not experimental', () {
    final graph = _planFor(const ['clock', 'notifications', 'http', 'ai', 'knowledge', 'file']);
    final capabilityFeatures = graph.nodesOfCategory(FeatureCategory.capability);
    expect(capabilityFeatures, hasLength(6));
    for (final feature in capabilityFeatures) {
      expect(feature.priority, isNot(FeaturePriority.experimental), reason: feature.name);
    }
  });

  test('capabilities with no implementation (Camera/Microphone/Location/Bluetooth/Sensors) are experimental', () {
    for (final capId in ['camera', 'microphone', 'location', 'bluetooth', 'sensors']) {
      final graph = _planFor([capId]);
      final feature = graph.nodesOfCategory(FeatureCategory.capability).single;
      expect(feature.priority, FeaturePriority.experimental, reason: capId);
    }
  });

  test('permission-requiring capabilities discover a Permission Strategy feature', () {
    final graph = _planFor(const ['camera']);
    expect(graph.nodeById('feature:permission:strategy'), isNotNull);
  });

  test('a capability that does not require a permission does not trigger the strategy feature', () {
    final graph = _planFor(const ['clock']);
    expect(graph.nodeById('feature:permission:strategy'), isNull);
  });

  test('discovery is generic — no requiredCapabilities produces zero capability features', () {
    final graph = _planFor(const []);
    expect(graph.nodesOfCategory(FeatureCategory.capability), isEmpty);
  });
}
