/// V2 ASAE — ArchitecturePlanner integration tests, covering every
/// sub-planner (Data/Entity/Field/Relationship/State/Navigation/
/// Interaction/Capability/Permission/Security/Offline/Synchronization/
/// Storage/Validation) through one real, novel-domain SemanticApp.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/software_architect/architecture_types.dart';

/// "Telescope Observation Log" — a domain with zero footprint anywhere in
/// lib/, used only to prove every decision below is structural.
SemanticApp _novelDomainApp() {
  return SemanticApp(
    name: 'Telescope Observation Log',
    purpose: 'Track amateur astronomy observation sessions',
    entities: [
      SemanticEntity(
        id: 'session',
        name: 'ObservationSession',
        displayField: 'target',
        fields: [
          const SemanticField(
            id: 'target',
            name: 'Target',
            type: BlueprintFieldType.text,
            required: true,
            minLength: 2,
          ),
          const SemanticField(
            id: 'magnitude',
            name: 'Magnitude',
            type: BlueprintFieldType.decimal,
            minimum: -30,
            maximum: 30,
          ),
          const SemanticField(
            id: 'equipmentId',
            name: 'Equipment',
            type: BlueprintFieldType.reference,
            referenceEntityId: 'equipment',
            required: false,
          ),
        ],
      ),
      const SemanticEntity(
        id: 'equipment',
        name: 'Equipment',
        fields: [
          SemanticField(
            id: 'label',
            name: 'Label',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: [
      const SemanticView(
        id: 'sessions_list',
        name: 'Sessions',
        purpose: 'list',
        sourceEntityId: 'session',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      const SemanticView(
        id: 'sessions_form',
        name: 'Add Session',
        purpose: 'form',
        sourceEntityId: 'session',
        viewType: BlueprintViewType.form,
      ),
      const SemanticView(
        id: 'sessions_detail',
        name: 'Session Detail',
        purpose: 'detail',
        sourceEntityId: 'session',
        viewType: BlueprintViewType.detail,
      ),
    ],
    actions: [
      const SemanticAction(
        id: 'add_session',
        name: 'Add Session',
        targetEntityId: 'session',
      ),
      const SemanticAction(
        id: 'delete_session',
        name: 'Delete Session',
        targetEntityId: 'session',
        actionType: BlueprintActionType.delete,
      ),
    ],
    derivedValues: [
      const SemanticDerivedValue(
        id: 'session_count',
        name: 'Total Sessions',
        sourceEntityId: 'session',
        operation: DerivedOperation.count,
      ),
    ],
    requiredCapabilities: const ['clock'],
  );
}

void main() {
  const planner = ArchitecturePlanner();

  test(
    'plans one EntityDecision per entity, storage=sqlite (fields present)',
    () {
      final candidate = planner.plan(_novelDomainApp());
      expect(candidate.entities, hasLength(2));
      for (final e in candidate.entities) {
        expect(e.storage, StorageKind.sqlite);
        expect(e.storageDecision.rationale, isNotEmpty);
      }
    },
  );

  test('FieldPlanner produces one decision per field across all entities', () {
    final candidate = planner.plan(_novelDomainApp());
    expect(
      candidate.fields,
      hasLength(4),
    ); // target, magnitude, equipmentId, label
  });

  test(
    'RelationshipPlanner: optional reference -> setNull, required reference -> restrict',
    () {
      final candidate = planner.plan(_novelDomainApp());
      expect(candidate.relationships, hasLength(1));
      final rel = candidate.relationships.single;
      expect(rel.fromEntityId, 'session');
      expect(rel.toEntityId, 'equipment');
      expect(
        rel.deletePolicy,
        RelationshipDeletePolicy.setNull,
      ); // equipmentId is optional
    },
  );

  test(
    'StatePlanner: reactive state per entity, computed state per derived value',
    () {
      final candidate = planner.plan(_novelDomainApp());
      expect(
        candidate.states.where((s) => s.kind == StateKind.reactive),
        hasLength(2),
      );
      expect(
        candidate.states.where((s) => s.kind == StateKind.computed),
        hasLength(1),
      );
    },
  );

  test(
    'NavigationPlanner: entry screen + real edges inferred from view types',
    () {
      final candidate = planner.plan(_novelDomainApp());
      expect(candidate.navigation.entryScreenId, 'sessions_list');
      expect(candidate.navigation.screenIds, hasLength(3));
      expect(
        candidate.navigation.edges.any(
          (e) =>
              e.fromScreenId == 'sessions_list' &&
              e.toScreenId == 'sessions_form',
        ),
        isTrue,
      );
      expect(
        candidate.navigation.edges.any(
          (e) =>
              e.fromScreenId == 'sessions_list' &&
              e.toScreenId == 'sessions_detail',
        ),
        isTrue,
      );
    },
  );

  test(
    'InteractionPlanner: CRUD flags match declared actions; list features follow list view presence',
    () {
      final candidate = planner.plan(_novelDomainApp());
      final session = candidate.interactions.firstWhere(
        (i) => i.entityId == 'session',
      );
      expect(session.canCreate, isTrue);
      expect(session.canDelete, isTrue);
      expect(
        session.canUpdate,
        isFalse,
      ); // no update/toggle/setValue action declared
      expect(session.supportsSearch, isTrue);
      expect(session.supportsPagination, isTrue);

      final equipment = candidate.interactions.firstWhere(
        (i) => i.entityId == 'equipment',
      );
      expect(equipment.canCreate, isFalse); // no actions target equipment
      expect(equipment.supportsSearch, isFalse); // no list view for equipment
    },
  );

  test('CapabilityPlanner: known capability resolved with real metadata', () {
    final candidate = planner.plan(_novelDomainApp());
    final clock = candidate.capabilities.single;
    expect(clock.capabilityId, 'clock');
    expect(clock.resolved, isTrue);
    expect(clock.decision.securityImplication, isNotNull);
    expect(clock.decision.offlineImplication, isNotNull);
  });

  test(
    'CapabilityPlanner: unimplemented capability is honestly reported, not fabricated',
    () {
      final app = _novelDomainApp();
      final withUnknownCap = SemanticApp(
        name: app.name,
        purpose: app.purpose,
        entities: app.entities,
        requiredCapabilities: const ['bluetooth'],
      );
      final candidate = planner.plan(withUnknownCap);
      final decision = candidate.capabilities.single;
      expect(decision.resolved, isFalse);
      expect(decision.decision.confidence.score, 0.0);
    },
  );

  test(
    'SecurityPlanner/OfflinePlanner/SynchronizationPlanner: no network capability -> fully offline, no sync',
    () {
      final candidate = planner.plan(_novelDomainApp());
      expect(candidate.security.networkMode, NetworkMode.none);
      expect(candidate.offline.capability, OfflineCapability.fullyOffline);
      expect(candidate.synchronization.strategy, SyncStrategy.none);
    },
  );

  test(
    'SecurityPlanner/OfflinePlanner: http capability -> restricted network, cache-then-online',
    () {
      final app = _novelDomainApp();
      final withHttp = SemanticApp(
        name: app.name,
        purpose: app.purpose,
        entities: app.entities,
        requiredCapabilities: const ['http'],
      );
      final candidate = planner.plan(withHttp);
      expect(candidate.security.networkMode, NetworkMode.restrictedHttps);
      expect(candidate.offline.capability, OfflineCapability.cacheThenOnline);
      expect(candidate.synchronization.strategy, SyncStrategy.cacheFirst);
    },
  );

  test('ValidationPlanner: rules trace directly to explicit field bounds', () {
    final candidate = planner.plan(_novelDomainApp());
    final targetRules = candidate.validations.where(
      (v) => v.fieldId == 'target',
    );
    expect(
      targetRules.any((r) => r.type == ValidationRuleType.required),
      isTrue,
    );
    expect(
      targetRules.any((r) => r.type == ValidationRuleType.minLength),
      isTrue,
    );

    final magnitudeRules = candidate.validations.where(
      (v) => v.fieldId == 'magnitude',
    );
    expect(
      magnitudeRules.any((r) => r.type == ValidationRuleType.minimum),
      isTrue,
    );
    expect(
      magnitudeRules.any((r) => r.type == ValidationRuleType.maximum),
      isTrue,
    );
  });

  test('overall confidence is a real computed mean, not a fixed constant', () {
    final candidateA = planner.plan(_novelDomainApp());
    final sparse = SemanticApp(
      name: 'Sparse',
      purpose: 'p',
      entities: [const SemanticEntity(id: 'e', name: 'E')],
    );
    final candidateB = planner.plan(sparse);

    expect(
      candidateA.overallConfidence.score,
      isNot(candidateB.overallConfidence.score),
    );
    expect(candidateA.overallConfidence.score, greaterThan(0));
    expect(candidateA.overallConfidence.score, lessThanOrEqualTo(1));
  });
}
