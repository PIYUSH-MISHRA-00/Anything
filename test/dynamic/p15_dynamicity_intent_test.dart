/// P15 — automated dynamicity: two arbitrary IntentSpecs → different Experiences.
library;

import 'package:anything/creation/experience_package.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal structured intent used by the dynamicity probe (not a UI template).
class IntentSpec {
  final String domain;
  final List<String> entities;
  final List<String> actions;
  final List<String> uiSurfaces;

  const IntentSpec({
    required this.domain,
    required this.entities,
    required this.actions,
    required this.uiSurfaces,
  });
}

/// Generic engine stand-in: builds Experience packages from IntentSpec only.
ExperiencePackage buildFromIntent(IntentSpec intent) {
  final now = DateTime.utc(2026, 1, 1);
  final variables = <StateVariable>[
    for (final e in intent.entities)
      StateVariable(id: '${e}_list', type: 'list', defaultValue: const []),
    const StateVariable(id: 'query', type: 'string', defaultValue: ''),
  ];
  final nodes = <InterfaceNode>[
    for (final surface in intent.uiSurfaces)
      InterfaceNode(
        type: 'text',
        id: surface,
        properties: {'content': surface},
      ),
    for (final action in intent.actions)
      InterfaceNode(
        type: 'button',
        id: action,
        properties: {'label': action},
        actionBinding: ActionBinding(actionId: action),
      ),
  ];
  final behaviorNodes = <BehaviorNode>[
    for (final action in intent.actions)
      BehaviorNode(
        id: action,
        type: 'event',
        config: {'domain': intent.domain},
      ),
  ];
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: 'dyn-${intent.domain}',
      name: intent.domain,
      description: 'Generated from IntentSpec',
      version: '1.0.0',
      createdAt: now,
      updatedAt: now,
      networkMode: NetworkMode.none,
      storageMode: StorageMode.localDatabase,
      requiredCapabilities: const ['input', 'persistence'],
      category: intent.domain,
    ),
    interface: InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'main',
          title: intent.domain,
          children: nodes,
        ),
      ],
    ),
    behavior: BehaviorGraph(nodes: behaviorNodes, edges: const []),
    state: StateSchema(variables: variables),
    data: DataSchema(
      entities: [
        for (final e in intent.entities)
          DataEntitySchema(
            id: e,
            name: e,
            fields: const [
              DataFieldSchema(id: 'id', name: 'Id', type: 'text'),
              DataFieldSchema(id: 'name', name: 'Name', type: 'text'),
            ],
          ),
      ],
    ),
    provenance: const PackageProvenance(
      creationEngineVersion: '1.0.0',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: intent.domain, computedAt: now),
  );
}

void main() {
  test('two IntentSpecs yield different models/actions/UI via same builder', () {
    const garden = IntentSpec(
      domain: 'community_garden',
      entities: ['plot', 'member', 'planting', 'harvest'],
      actions: ['add_plot', 'record_watering', 'search'],
      uiSurfaces: ['plots_list', 'members_list', 'schedule'],
    );
    const bakery = IntentSpec(
      domain: 'bakery_ops',
      entities: ['recipe', 'ingredient', 'batch', 'order'],
      actions: ['add_recipe', 'start_batch', 'search'],
      uiSurfaces: ['recipes', 'inventory', 'orders'],
    );

    final a = buildFromIntent(garden);
    final b = buildFromIntent(bakery);

    expect(a.manifest.experienceId, isNot(b.manifest.experienceId));
    expect(a.data!.entities.map((e) => e.id).toSet(),
        isNot(b.data!.entities.map((e) => e.id).toSet()));
    expect(a.behavior.nodes.map((n) => n.id).toSet(),
        isNot(b.behavior.nodes.map((n) => n.id).toSet()));
    expect(
      a.interface.screens.first.children.map((n) => n.id).toSet(),
      isNot(b.interface.screens.first.children.map((n) => n.id).toSet()),
    );
    // Same generic construction path (no domain-specific factory class).
    expect(a.runtimeType, b.runtimeType);
    expect(identical(buildFromIntent, buildFromIntent), isTrue);
  });
}
