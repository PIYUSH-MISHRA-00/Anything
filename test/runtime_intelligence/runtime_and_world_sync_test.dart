/// Vision V10 RC — RuntimeIntelligenceCoordinator.runAndSyncToWorldModel:
/// Experience Runtime -> Observation -> Learning -> World Graph as ONE
/// call, without a caller having to manually sequence three separate
/// steps in the right order.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/runtime_intelligence/runtime_intelligence_coordinator.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  test(
    'runAndSyncToWorldModel syncs a real UsageGraph and learned patterns into the World Graph in one call',
    () {
      final coordinator = RuntimeIntelligenceCoordinator();
      DateTime t(int i) => DateTime(2026, 1, 1).add(Duration(seconds: i));
      for (final exp in ['e1', 'e2']) {
        coordinator.observationMemory.record(
          ObservationRecord(
            id: '$exp-0',
            category: ObservationCategory.navigation,
            experienceId: exp,
            screenId: 'a',
            timestamp: t(0),
          ),
        );
        coordinator.observationMemory.record(
          ObservationRecord(
            id: '$exp-1',
            category: ObservationCategory.navigation,
            experienceId: exp,
            screenId: 'b',
            timestamp: t(1),
          ),
        );
      }

      final registry = CapabilityRegistry();
      registry.register(
        const CapabilityDescriptor(
          id: 'clock',
          version: '1.0.0',
          name: 'clock',
          description: 'clock',
          category: CapabilityCategory.storage,
          inputContract: 'x',
          outputContract: 'y',
        ),
      );

      final worldModel = WorldModelCoordinator();
      expect(worldModel.model.graph.nodes, isEmpty);

      coordinator.runAndSyncToWorldModel(
        worldModel,
        capabilityRegistry: registry,
        minOccurrences: 2,
      );

      expect(worldModel.model.graph.nodes, isNotEmpty);
      expect(
        worldModel.model.graph.nodesOfKind(WorldNodeKind.workflow),
        isNotEmpty,
      );
    },
  );
}
