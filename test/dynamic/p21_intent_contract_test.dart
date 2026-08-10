/// P21 — IntentContract rejects purpose / depth mismatches.
library;

import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/creation/creation_request.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/intent_contract.dart';
import 'package:anything/creation/intent_preservation.dart';
import 'package:flutter_test/flutter_test.dart';

ExperiencePackage _emptyPkg() => ExperiencePackage(
  manifest: ExperienceManifest(
    experienceId: 't',
    name: 'T',
    description: 'd',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  interface: const InterfaceDefinition(screens: []),
  behavior: const BehaviorGraph(),
  state: const StateSchema(),
  provenance: const PackageProvenance(
    creationEngineVersion: '1.0.0',
    specVersion: 1,
    planVersion: 1,
  ),
  integrity: PackageIntegrity(contentHash: '', computedAt: DateTime(2026)),
);

ExperiencePackage _timingPkg() {
  InterfaceNode btn(String id, String action) => InterfaceNode(
    type: 'button',
    id: id,
    properties: {'label': id},
    actionBinding: ActionBinding(actionId: action),
  );
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: 'sw',
      name: 'Stopwatch',
      description: 'd',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    interface: InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'main',
          title: 'Stopwatch',
          children: [
            const InterfaceNode(
              type: 'text',
              id: 'display',
              stateBinding: 'display',
            ),
            btn('start', 'timer.start'),
            btn('pause', 'timer.pause'),
            btn('reset', 'timer.reset'),
          ],
        ),
      ],
    ),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
    provenance: const PackageProvenance(
      creationEngineVersion: '1.0.0',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: '', computedAt: DateTime(2026)),
  );
}

ExperiencePackage _basicCalcPkg() {
  InterfaceNode btn(String id, String action) => InterfaceNode(
    type: 'button',
    id: id,
    properties: {'label': id},
    actionBinding: ActionBinding(actionId: action),
  );
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: 'calc',
      name: 'Calculator',
      description: 'd',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    interface: InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'main',
          title: 'Calculator',
          children: [
            const InterfaceNode(
              type: 'text',
              id: 'display',
              stateBinding: 'display',
            ),
            btn('d1', 'calc.digit'),
            btn('op', 'calc.operator'),
            btn('eq', 'calc.equals'),
            btn('clr', 'calc.clear'),
          ],
        ),
      ],
    ),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
    provenance: const PackageProvenance(
      creationEngineVersion: '1.0.0',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: '', computedAt: DateTime(2026)),
  );
}

ExperiencePackage _scientificCalcPkg() {
  final base = _basicCalcPkg();
  final screen = base.interface.screens.first;
  final children = [
    ...screen.children,
    InterfaceNode(
      type: 'button',
      id: 'sin',
      properties: const {'label': 'sin'},
      actionBinding: const ActionBinding(actionId: 'calc.unary'),
    ),
  ];
  return ExperiencePackage(
    manifest: base.manifest,
    interface: InterfaceDefinition(
      screens: [
        InterfaceScreen(id: screen.id, title: screen.title, children: children),
      ],
    ),
    behavior: base.behavior,
    state: base.state,
    provenance: base.provenance,
    integrity: base.integrity,
  );
}

void main() {
  test('CreationRequest is immutable snapshot', () {
    final a = CreationRequest.capture(rawPrompt: '  Create a stopwatch  ');
    expect(a.rawPrompt, '  Create a stopwatch  ');
    expect(a.normalizedPrompt, 'Create a stopwatch');
    expect(a.requestId, isNotEmpty);
  });

  test('stopwatch contract rejects calculator package', () {
    final contract = IntentContract.fromRequest(
      CreationRequest.capture(rawPrompt: 'Create a professional stopwatch'),
    );
    expect(contract.primaryPurpose, IntentPurpose.timing);
    expect(contract.requiresContinuousTiming, isTrue);
    final bad = contract.evaluate(_basicCalcPkg());
    expect(bad.isSatisfied, isFalse);
    final good = contract.evaluate(
      _timingPkg(),
      inferredCapabilities: {AppCapabilityIds.timers},
    );
    expect(good.isSatisfied, isTrue);
  });

  test('scientific contract rejects basic calculator pad', () {
    final contract = IntentContract.fromRequest(
      CreationRequest.capture(
        rawPrompt: 'Create a professional scientific calculator',
      ),
    );
    expect(contract.requiresScientificCalculation, isTrue);
    expect(contract.evaluate(_basicCalcPkg()).isSatisfied, isFalse);
    expect(contract.evaluate(_scientificCalcPkg()).isSatisfied, isTrue);
  });

  test('empty package fails timing contract', () {
    final contract = IntentContract.fromRequest(
      CreationRequest.capture(rawPrompt: 'Create a stopwatch'),
    );
    expect(contract.evaluate(_emptyPkg()).isSatisfied, isFalse);
  });
}
