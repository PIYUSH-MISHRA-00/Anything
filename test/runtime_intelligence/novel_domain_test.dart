/// Vision V8 RIL — novel domain proof: a domain with zero footprint
/// anywhere in lib/runtime_intelligence/ flows through the full
/// Observation -> Learning -> Recommendation -> Automation pipeline
/// purely structurally — nothing here recognizes "beekeeping" as a
/// concept; only screen-id sequences and counts matter.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/runtime_intelligence/automation_executor.dart';
import 'package:anything/runtime_intelligence/background_coordinator.dart';
import 'package:anything/runtime_intelligence/learning_memory.dart';
import 'package:anything/runtime_intelligence/observation_memory.dart';
import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/runtime_intelligence/runtime_intelligence_engine.dart';

void main() {
  test(
    'a never-before-seen "beekeeping apiary rotation" domain still produces real, structural '
    'learning/recommendations/automation — proving zero domain-specific logic exists',
    () {
      DateTime t(int i) => DateTime(2026, 1, 1).add(Duration(seconds: i));
      final memory = ObservationMemory();
      for (final hiveKeeper in ['keeper-1', 'keeper-2', 'keeper-3']) {
        memory.record(
          ObservationRecord(
            id: '$hiveKeeper-0',
            category: ObservationCategory.navigation,
            experienceId: hiveKeeper,
            screenId: 'hive_inspection_log',
            timestamp: t(0),
          ),
        );
        memory.record(
          ObservationRecord(
            id: '$hiveKeeper-1',
            category: ObservationCategory.navigation,
            experienceId: hiveKeeper,
            screenId: 'apiary_rotation_schedule',
            timestamp: t(1),
          ),
        );
        memory.record(
          ObservationRecord(
            id: '$hiveKeeper-2',
            category: ObservationCategory.navigation,
            experienceId: hiveKeeper,
            screenId: 'honey_yield_summary',
            timestamp: t(2),
          ),
        );
      }

      const engine = RuntimeIntelligenceEngine();
      final learningMemory = LearningMemory();
      final result = engine.run(memory, learningMemory, minOccurrences: 2);

      expect(result.learned, isNotEmpty);
      expect(result.recommendations, isNotEmpty);
      expect(result.automationPlans, isNotEmpty);

      final registry = CapabilityRegistry();
      for (final id in ['clock', 'notifications']) {
        registry.register(
          CapabilityDescriptor(
            id: id,
            version: '1.0.0',
            name: id,
            description: id,
            category: CapabilityCategory.storage,
            inputContract: 'x',
            outputContract: 'y',
          ),
        );
      }
      const executor = AutomationExecutor();
      final reports = result.automationPlans
          .map((p) => executor.validate(p, registry))
          .toList();
      expect(reports.every((r) => r.allEligible), isTrue);

      const coordinator = BackgroundCoordinator();
      final jobs = coordinator.queue(result.automationPlans);
      expect(jobs, isNotEmpty);

      // The proof: every description names the real, observed screen ids
      // for THIS domain — never a template phrase unrelated to what was
      // actually observed.
      for (final plan in result.automationPlans) {
        final mentionsRealScreen =
            plan.description.contains('hive_inspection_log') ||
            plan.description.contains('apiary_rotation_schedule') ||
            plan.description.contains('honey_yield_summary');
        expect(mentionsRealScreen, isTrue);
      }
    },
  );
}
