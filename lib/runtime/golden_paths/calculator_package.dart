/// Calculator ExperiencePackage fixture for golden path testing.
///
/// This is the first canonical Experience Package.
/// It must work through the generic Runtime without Calculator-specific code.
library;

import 'package:uuid/uuid.dart';

import '../../creation/experience_package.dart';

/// Creates a Calculator ExperiencePackage.
ExperiencePackage createCalculatorPackage() {
  final id = 'exp-calculator-${const Uuid().v4()}';
  final now = DateTime.now();

  final manifest = ExperienceManifest(
    experienceId: id,
    name: 'Calculator',
    description: 'A simple calculator for basic arithmetic',
    version: '1.0.0',
    createdAt: now,
    updatedAt: now,
    networkMode: NetworkMode.none,
    storageMode: StorageMode.none,
  );

  final interface = InterfaceDefinition(
    screens: [
      InterfaceScreen(
        id: 'calculator',
        title: 'Calculator',
        appBarTitle: 'Calculator',
        children: [
          // Display
          InterfaceNode(
            type: 'text',
            id: 'display',
            properties: {'content': '0', 'textAlign': 'right', 'fontSize': 48},
            stateBinding: 'display',
          ),
          // Expression display
          InterfaceNode(
            type: 'text',
            id: 'expression',
            properties: {
              'content': '',
              'textAlign': 'right',
              'fontSize': 18,
              'color': 'secondary',
            },
            stateBinding: 'expression',
          ),
          const InterfaceNode(type: 'divider', id: 'div1'),
          // Row 1: 7 8 9 ÷
          InterfaceNode(
            type: 'row',
            id: 'row1',
            children: [
              InterfaceNode(
                type: 'button',
                id: 'btn_7',
                properties: {'label': '7', 'width': 'expand'},
                actionBinding: const ActionBinding(
                  actionId: 'numberPressed',
                  parameters: {'value': 7},
                ),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_8',
                properties: {'label': '8', 'width': 'expand'},
                actionBinding: const ActionBinding(
                  actionId: 'numberPressed',
                  parameters: {'value': 8},
                ),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_9',
                properties: {'label': '9', 'width': 'expand'},
                actionBinding: const ActionBinding(
                  actionId: 'numberPressed',
                  parameters: {'value': 9},
                ),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_div',
                properties: {'label': '÷', 'width': 'expand', 'accent': true},
                actionBinding: const ActionBinding(
                  actionId: 'operationPressed',
                  parameters: {'op': '/'},
                ),
              ),
            ],
          ),
          // Row 2: 4 5 6 ×
          InterfaceNode(
            type: 'row',
            id: 'row2',
            children: [
              InterfaceNode(
                type: 'button',
                id: 'btn_4',
                properties: {'label': '4', 'width': 'expand'},
                actionBinding: const ActionBinding(
                  actionId: 'numberPressed',
                  parameters: {'value': 4},
                ),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_5',
                properties: {'label': '5', 'width': 'expand'},
                actionBinding: const ActionBinding(
                  actionId: 'numberPressed',
                  parameters: {'value': 5},
                ),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_6',
                properties: {'label': '6', 'width': 'expand'},
                actionBinding: const ActionBinding(
                  actionId: 'numberPressed',
                  parameters: {'value': 6},
                ),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_mul',
                properties: {'label': '×', 'width': 'expand', 'accent': true},
                actionBinding: const ActionBinding(
                  actionId: 'operationPressed',
                  parameters: {'op': '*'},
                ),
              ),
            ],
          ),
          // Row 3: 1 2 3 −
          InterfaceNode(
            type: 'row',
            id: 'row3',
            children: [
              InterfaceNode(
                type: 'button',
                id: 'btn_1',
                properties: {'label': '1', 'width': 'expand'},
                actionBinding: const ActionBinding(
                  actionId: 'numberPressed',
                  parameters: {'value': 1},
                ),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_2',
                properties: {'label': '2', 'width': 'expand'},
                actionBinding: const ActionBinding(
                  actionId: 'numberPressed',
                  parameters: {'value': 2},
                ),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_3',
                properties: {'label': '3', 'width': 'expand'},
                actionBinding: const ActionBinding(
                  actionId: 'numberPressed',
                  parameters: {'value': 3},
                ),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_sub',
                properties: {'label': '−', 'width': 'expand', 'accent': true},
                actionBinding: const ActionBinding(
                  actionId: 'operationPressed',
                  parameters: {'op': '-'},
                ),
              ),
            ],
          ),
          // Row 4: C 0 = +
          InterfaceNode(
            type: 'row',
            id: 'row4',
            children: [
              InterfaceNode(
                type: 'button',
                id: 'btn_clear',
                properties: {'label': 'C', 'width': 'expand', 'danger': true},
                actionBinding: const ActionBinding(actionId: 'clearPressed'),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_0',
                properties: {'label': '0', 'width': 'expand'},
                actionBinding: const ActionBinding(
                  actionId: 'numberPressed',
                  parameters: {'value': 0},
                ),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_eq',
                properties: {'label': '=', 'width': 'expand', 'primary': true},
                actionBinding: const ActionBinding(actionId: 'equalsPressed'),
              ),
              InterfaceNode(
                type: 'button',
                id: 'btn_add',
                properties: {'label': '+', 'width': 'expand', 'accent': true},
                actionBinding: const ActionBinding(
                  actionId: 'operationPressed',
                  parameters: {'op': '+'},
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  final behavior = BehaviorGraph(
    nodes: [
      const BehaviorNode(
        id: 'numberPressed',
        type: 'event',
        config: {'description': 'Numeric button pressed'},
      ),
      const BehaviorNode(
        id: 'operationPressed',
        type: 'event',
        config: {'description': 'Operation button pressed'},
      ),
      const BehaviorNode(
        id: 'equalsPressed',
        type: 'event',
        config: {'description': 'Equals button pressed'},
      ),
      const BehaviorNode(
        id: 'clearPressed',
        type: 'event',
        config: {'description': 'Clear button pressed'},
      ),
      const BehaviorNode(
        id: 'updateDisplay',
        type: 'stateWrite',
        config: {'stateId': 'display'},
      ),
      const BehaviorNode(
        id: 'calculate',
        type: 'calculation',
        config: {'operation': 'calculate'},
      ),
      const BehaviorNode(
        id: 'clearState',
        type: 'stateWrite',
        config: {'stateId': 'display', 'value': '0'},
      ),
    ],
    edges: const [],
  );

  final state = StateSchema(
    variables: const [
      StateVariable(
        id: 'display',
        type: 'string',
        defaultValue: '0',
        persistence: 'session',
      ),
      StateVariable(
        id: 'expression',
        type: 'string',
        defaultValue: '',
        persistence: 'session',
      ),
      StateVariable(
        id: 'currentValue',
        type: 'decimal',
        defaultValue: 0.0,
        persistence: 'session',
      ),
      StateVariable(
        id: 'storedValue',
        type: 'decimal',
        defaultValue: 0.0,
        persistence: 'session',
      ),
      StateVariable(
        id: 'currentOperation',
        type: 'string',
        defaultValue: '',
        persistence: 'session',
      ),
      StateVariable(
        id: 'newInput',
        type: 'boolean',
        defaultValue: true,
        persistence: 'session',
      ),
    ],
  );

  final provenance = PackageProvenance(
    creationEngineVersion: '1.0.0',
    specVersion: 1,
    planVersion: 1,
  );

  final package = ExperiencePackage(
    manifest: manifest,
    interface: interface,
    behavior: behavior,
    state: state,
    provenance: provenance,
    integrity: PackageIntegrity(contentHash: '', computedAt: now),
  );

  // Compute integrity
  final hash = ExperiencePackage.computeIntegrityHash(package);
  return ExperiencePackage(
    packageVersion: package.packageVersion,
    manifest: package.manifest,
    interface: package.interface,
    behavior: package.behavior,
    state: package.state,
    provenance: package.provenance,
    integrity: PackageIntegrity(contentHash: hash, computedAt: DateTime.now()),
  );
}
