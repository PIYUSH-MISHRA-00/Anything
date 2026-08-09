/// Builds a calculation pad Experience surface from [CalculationSpec].
library;

import '../runtime/calculation_session.dart';
import 'calculation_spec.dart';
import 'experience_package.dart';

/// Deterministic calculation UI + state + behavior from a structured spec.
class CalculationInterfaceFactory {
  const CalculationInterfaceFactory();

  ExperiencePackage applyToPackage(
    ExperiencePackage package, {
    required String name,
    CalculationSpec? spec,
  }) {
    final resolved =
        spec ??
        const CalculationSpec(
          mode: CalculationMode.basic,
          operations: CalculationSpec.basicOps,
        );
    final interface = buildInterface(title: name, spec: resolved);
    final state = _mergeState(package.state, buildState(spec: resolved));
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
      if (resolved.isScientific &&
          !package.capabilityDeclarations.any(
            (c) => c.capabilityId == 'scientificCalculation',
          ))
        const CapabilityDeclaration(
          capabilityId: 'scientificCalculation',
          isRequired: true,
        ),
    ];
    final manifest = ExperienceManifest(
      experienceId: package.manifest.experienceId,
      name: name,
      description: package.manifest.description,
      version: package.manifest.version,
      createdAt: package.manifest.createdAt,
      updatedAt: package.manifest.updatedAt,
      networkMode: package.manifest.networkMode,
      storageMode: package.manifest.storageMode,
      requiredCapabilities: {
        ...package.manifest.requiredCapabilities,
        'calculation',
        if (resolved.isScientific) 'scientificCalculation',
        'input',
        'resultDisplay',
      }.toList(),
      category: package.manifest.category,
      tags: {
        ...package.manifest.tags,
        'calcMode:${resolved.mode.name}',
      }.toList(),
    );

    return ExperiencePackage(
      packageVersion: package.packageVersion,
      manifest: manifest,
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

  InterfaceDefinition buildInterface({
    required String title,
    CalculationSpec spec = const CalculationSpec(
      mode: CalculationMode.basic,
      operations: CalculationSpec.basicOps,
    ),
  }) {
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

    final padChildren = <InterfaceNode>[
      if (spec.isScientific) ...[
        InterfaceNode(
          type: 'row',
          id: 'row_sci_1',
          properties: const {'expandChildren': true},
          children: [
            btn('btn_sin', 'sin', CalculationSession.unary, params: {'op': 'sin'}),
            btn('btn_cos', 'cos', CalculationSession.unary, params: {'op': 'cos'}),
            btn('btn_tan', 'tan', CalculationSession.unary, params: {'op': 'tan'}),
            btn('btn_sqrt', '√', CalculationSession.unary, params: {'op': 'sqrt'}),
          ],
        ),
        InterfaceNode(
          type: 'row',
          id: 'row_sci_2',
          properties: const {'expandChildren': true},
          children: [
            btn('btn_ln', 'ln', CalculationSession.unary, params: {'op': 'ln'}),
            btn('btn_log', 'log', CalculationSession.unary, params: {'op': 'log'}),
            btn('btn_pow', 'xʸ', CalculationSession.operator_, params: {'op': '^'}, accent: true),
            btn('btn_fact', 'n!', CalculationSession.unary, params: {'op': 'factorial'}),
          ],
        ),
        InterfaceNode(
          type: 'row',
          id: 'row_sci_3',
          properties: const {'expandChildren': true},
          children: [
            btn('btn_pi', 'π', CalculationSession.constant, params: {'name': 'pi'}),
            btn('btn_e', 'e', CalculationSession.constant, params: {'name': 'e'}),
            btn(
              'btn_lparen',
              '(',
              CalculationSession.paren,
              params: {'value': '('},
            ),
            btn(
              'btn_rparen',
              ')',
              CalculationSession.paren,
              params: {'value': ')'},
            ),
          ],
        ),
        InterfaceNode(
          type: 'row',
          id: 'row_sci_4',
          properties: const {'expandChildren': true},
          children: [
            btn('btn_abs', '|x|', CalculationSession.unary, params: {'op': 'abs'}),
            btn('btn_neg', '±', CalculationSession.unary, params: {'op': 'neg'}),
            btn(
              'btn_mod',
              'mod',
              CalculationSession.operator_,
              params: {'op': 'mod'},
              accent: true,
            ),
            btn(
              'btn_pct',
              '%',
              CalculationSession.unary,
              params: {'op': 'percent'},
            ),
          ],
        ),
      ],
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
          btn('btn_7', '7', CalculationSession.digit, params: {'value': 7}),
          btn('btn_8', '8', CalculationSession.digit, params: {'value': 8}),
          btn('btn_9', '9', CalculationSession.digit, params: {'value': 9}),
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
          btn('btn_4', '4', CalculationSession.digit, params: {'value': 4}),
          btn('btn_5', '5', CalculationSession.digit, params: {'value': 5}),
          btn('btn_6', '6', CalculationSession.digit, params: {'value': 6}),
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
          btn('btn_1', '1', CalculationSession.digit, params: {'value': 1}),
          btn('btn_2', '2', CalculationSession.digit, params: {'value': 2}),
          btn('btn_3', '3', CalculationSession.digit, params: {'value': 3}),
          btn('btn_eq', '=', CalculationSession.equals, primary: true),
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
            properties: {'label': '0', 'width': 'expand', 'flex': 2},
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
          if (spec.operations.contains('percent'))
            btn(
              'btn_pct',
              '%',
              CalculationSession.unary,
              params: {'op': 'percent'},
            ),
        ],
      ),
    ];

    return InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'calculator',
          title: title,
          appBarTitle: title,
          children: [
            InterfaceNode(
              type: 'text',
              id: 'mode_label',
              properties: {
                'content': 'Mode: ${spec.mode.name}',
                'fontSize': 12,
                'color': 'secondary',
              },
              stateBinding: 'calcMode',
            ),
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
            InterfaceNode(
              type: 'calculationPad',
              id: 'pad',
              children: padChildren,
            ),
          ],
        ),
      ],
    );
  }

  StateSchema buildState({
    CalculationSpec spec = const CalculationSpec(
      mode: CalculationMode.basic,
      operations: CalculationSpec.basicOps,
    ),
  }) {
    return StateSchema(
      variables: [
        const StateVariable(
          id: 'display',
          type: 'string',
          defaultValue: '0',
          persistence: 'session',
        ),
        const StateVariable(
          id: 'expression',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        const StateVariable(
          id: 'storedValue',
          type: 'decimal',
          defaultValue: 0.0,
          persistence: 'session',
        ),
        const StateVariable(
          id: 'currentOperation',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        const StateVariable(
          id: 'newInput',
          type: 'boolean',
          defaultValue: true,
          persistence: 'session',
        ),
        const StateVariable(
          id: 'error',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        StateVariable(
          id: 'calcMode',
          type: 'string',
          defaultValue: 'Mode: ${spec.mode.name}',
          persistence: 'session',
        ),
        StateVariable(
          id: 'angleMode',
          type: 'string',
          defaultValue: spec.angleMode,
          persistence: 'session',
        ),
        const StateVariable(
          id: 'expressionBuffer',
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
        BehaviorNode(
          id: CalculationSession.unary,
          type: 'event',
          config: {'description': 'Unary function'},
        ),
        BehaviorNode(
          id: CalculationSession.constant,
          type: 'event',
          config: {'description': 'Mathematical constant'},
        ),
        BehaviorNode(
          id: CalculationSession.paren,
          type: 'event',
          config: {'description': 'Parenthesis'},
        ),
        BehaviorNode(
          id: CalculationSession.evaluateExpression,
          type: 'event',
          config: {'description': 'Evaluate full expression'},
        ),
      ],
      edges: [],
    );
  }

  StateSchema _mergeState(StateSchema existing, StateSchema calc) {
    final ids = existing.variables.map((v) => v.id).toSet();
    return StateSchema(
      variables: [
        ...existing.variables,
        ...calc.variables.where((v) => !ids.contains(v.id)),
      ],
    );
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
