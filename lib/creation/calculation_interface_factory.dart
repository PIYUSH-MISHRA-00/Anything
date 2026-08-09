/// Builds a generic calculation pad Experience surface from capabilities.
library;

import '../runtime/calculation_session.dart';
import 'experience_package.dart';

/// Deterministic calculation UI + state + behavior nodes.
class CalculationInterfaceFactory {
  const CalculationInterfaceFactory();

  ExperiencePackage applyToPackage(
    ExperiencePackage package, {
    required String name,
  }) {
    final interface = buildInterface(title: name);
    final state = _mergeState(package.state, buildState());
    final behavior = _mergeBehavior(package.behavior, buildBehavior());
    final caps = [
      ...package.capabilityDeclarations,
      if (!package.capabilityDeclarations.any(
        (c) => c.capabilityId == 'calculation',
      ))
        const CapabilityDeclaration(
          capabilityId: 'calculation',
          isRequired: true,
        ),
    ];

    return ExperiencePackage(
      packageVersion: package.packageVersion,
      manifest: package.manifest,
      interface: interface,
      behavior: behavior,
      state: state,
      data: package.data,
      services: package.services,
      networkDeclarations: package.networkDeclarations,
      capabilityDeclarations: caps,
      permissionDeclarations: package.permissionDeclarations,
      protection: package.protection,
      provenance: package.provenance,
      integrity: package.integrity,
    );
  }

  InterfaceDefinition buildInterface({required String title}) {
    InterfaceNode btn(
      String id,
      String label,
      String action, {
      Map<String, dynamic>? params,
      bool accent = false,
      bool primary = false,
    }) {
      return InterfaceNode(
        type: 'button',
        id: id,
        properties: {
          'label': label,
          'width': 'expand',
          if (accent) 'accent': true,
          if (primary) 'primary': true,
        },
        actionBinding: ActionBinding(
          actionId: action,
          parameters: params ?? const <String, dynamic>{},
        ),
      );
    }

    return InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'calculator',
          title: title,
          appBarTitle: title,
          children: [
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
            InterfaceNode(
              type: 'text',
              id: 'display',
              properties: {
                'content': '0',
                'textAlign': 'right',
                'fontSize': 48,
              },
              stateBinding: 'display',
            ),
            InterfaceNode(
              type: 'text',
              id: 'calc_error',
              properties: {
                'content': '',
                'textAlign': 'right',
                'fontSize': 14,
                'color': 'error',
              },
              stateBinding: 'error',
            ),
            const InterfaceNode(type: 'divider', id: 'calc_div'),
            // IS-P11: calculationPad fills remaining viewport with large keys.
            InterfaceNode(
              type: 'calculationPad',
              id: 'pad',
              children: [
                InterfaceNode(
                  type: 'row',
                  id: 'row_ops_top',
                  properties: const {'expandChildren': true},
                  children: [
                    btn('btn_clear', 'C', CalculationSession.clear),
                    btn('btn_back', '⌫', CalculationSession.backspace),
                    btn(
                      'btn_div',
                      '÷',
                      CalculationSession.operator_,
                      params: {'op': '/'},
                      accent: true,
                    ),
                    btn(
                      'btn_mul',
                      '×',
                      CalculationSession.operator_,
                      params: {'op': '*'},
                      accent: true,
                    ),
                  ],
                ),
                InterfaceNode(
                  type: 'row',
                  id: 'row_7',
                  properties: const {'expandChildren': true},
                  children: [
                    btn(
                      'btn_7',
                      '7',
                      CalculationSession.digit,
                      params: {'value': 7},
                    ),
                    btn(
                      'btn_8',
                      '8',
                      CalculationSession.digit,
                      params: {'value': 8},
                    ),
                    btn(
                      'btn_9',
                      '9',
                      CalculationSession.digit,
                      params: {'value': 9},
                    ),
                    btn(
                      'btn_sub',
                      '−',
                      CalculationSession.operator_,
                      params: {'op': '-'},
                      accent: true,
                    ),
                  ],
                ),
                InterfaceNode(
                  type: 'row',
                  id: 'row_4',
                  properties: const {'expandChildren': true},
                  children: [
                    btn(
                      'btn_4',
                      '4',
                      CalculationSession.digit,
                      params: {'value': 4},
                    ),
                    btn(
                      'btn_5',
                      '5',
                      CalculationSession.digit,
                      params: {'value': 5},
                    ),
                    btn(
                      'btn_6',
                      '6',
                      CalculationSession.digit,
                      params: {'value': 6},
                    ),
                    btn(
                      'btn_add',
                      '+',
                      CalculationSession.operator_,
                      params: {'op': '+'},
                      accent: true,
                    ),
                  ],
                ),
                InterfaceNode(
                  type: 'row',
                  id: 'row_1',
                  properties: const {'expandChildren': true},
                  children: [
                    btn(
                      'btn_1',
                      '1',
                      CalculationSession.digit,
                      params: {'value': 1},
                    ),
                    btn(
                      'btn_2',
                      '2',
                      CalculationSession.digit,
                      params: {'value': 2},
                    ),
                    btn(
                      'btn_3',
                      '3',
                      CalculationSession.digit,
                      params: {'value': 3},
                    ),
                    btn(
                      'btn_eq',
                      '=',
                      CalculationSession.equals,
                      primary: true,
                    ),
                  ],
                ),
                InterfaceNode(
                  type: 'row',
                  id: 'row_0',
                  properties: const {'expandChildren': true},
                  children: [
                    InterfaceNode(
                      type: 'button',
                      id: 'btn_0',
                      properties: {
                        'label': '0',
                        'width': 'expand',
                        'flex': 2,
                      },
                      actionBinding: const ActionBinding(
                        actionId: CalculationSession.digit,
                        parameters: {'value': 0},
                      ),
                    ),
                    btn(
                      'btn_dot',
                      '.',
                      CalculationSession.digit,
                      params: {'value': '.'},
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  StateSchema buildState() {
    return const StateSchema(
      variables: [
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
        StateVariable(
          id: 'error',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
      ],
    );
  }

  BehaviorGraph buildBehavior() {
    return const BehaviorGraph(
      nodes: [
        BehaviorNode(
          id: CalculationSession.digit,
          type: 'event',
          config: {'description': 'Digit pressed'},
        ),
        BehaviorNode(
          id: CalculationSession.operator_,
          type: 'event',
          config: {'description': 'Operator pressed'},
        ),
        BehaviorNode(
          id: CalculationSession.equals,
          type: 'event',
          config: {'description': 'Equals pressed'},
        ),
        BehaviorNode(
          id: CalculationSession.clear,
          type: 'event',
          config: {'description': 'Clear pressed'},
        ),
        BehaviorNode(
          id: CalculationSession.backspace,
          type: 'event',
          config: {'description': 'Backspace pressed'},
        ),
      ],
      edges: [],
    );
  }

  StateSchema _mergeState(StateSchema existing, StateSchema calc) {
    final ids = existing.variables.map((v) => v.id).toSet();
    final merged = [
      ...existing.variables,
      ...calc.variables.where((v) => !ids.contains(v.id)),
    ];
    return StateSchema(variables: merged);
  }

  BehaviorGraph _mergeBehavior(BehaviorGraph existing, BehaviorGraph calc) {
    final ids = existing.nodes.map((n) => n.id).toSet();
    return BehaviorGraph(
      nodes: [
        ...existing.nodes,
        ...calc.nodes.where((n) => !ids.contains(n.id)),
      ],
      edges: existing.edges,
    );
  }
}
