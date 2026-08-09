/// Structured weather Experience surface — weatherData capability.
library;

import 'experience_package.dart';

/// Deterministic weather UI wired to the `weather` platform capability.
class WeatherInterfaceFactory {
  const WeatherInterfaceFactory();

  ExperiencePackage applyToPackage(
    ExperiencePackage package, {
    required String name,
  }) {
    final interface = buildInterface(title: name);
    final state = _mergeState(package.state, buildState());
    final behavior = _mergeBehavior(package.behavior, buildBehavior());
    final services = [
      ...package.services.where((s) => s.type != 'knowledgeRetrieval'),
      if (!package.services.any((s) => s.type == 'weatherData'))
        const ServiceDefinition(id: 'weather', type: 'weatherData'),
    ];
    final caps = [
      ...package.capabilityDeclarations.where(
        (c) => c.capabilityId != 'knowledge',
      ),
      if (!package.capabilityDeclarations.any((c) => c.capabilityId == 'weather'))
        const CapabilityDeclaration(capabilityId: 'weather', isRequired: true),
    ];
    final manifest = ExperienceManifest(
      experienceId: package.manifest.experienceId,
      name: name,
      description: package.manifest.description,
      version: package.manifest.version,
      createdAt: package.manifest.createdAt,
      updatedAt: package.manifest.updatedAt,
      networkMode: NetworkMode.required,
      storageMode: package.manifest.storageMode,
      requiredCapabilities: {
        ...package.manifest.requiredCapabilities.where(
          (c) => c != 'knowledge' && c != 'webData',
        ),
        'weatherData',
        'input',
        'refresh',
        'loadingState',
        'errorState',
        'resultDisplay',
      }.toList(),
      category: 'reference',
      tags: package.manifest.tags,
    );

    return ExperiencePackage(
      packageVersion: package.packageVersion,
      manifest: manifest,
      interface: interface,
      behavior: behavior,
      state: state,
      data: package.data,
      services: services,
      networkDeclarations: package.networkDeclarations,
      capabilityDeclarations: caps,
      permissionDeclarations: package.permissionDeclarations,
      protection: package.protection,
      provenance: package.provenance,
      integrity: package.integrity,
    );
  }

  InterfaceDefinition buildInterface({required String title}) {
    return InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'weather_main',
          title: title,
          appBarTitle: title,
          children: [
            InterfaceNode(
              type: 'text',
              id: 'hint',
              properties: {
                'content': 'Enter a city, then Search for live weather.',
                'color': 'secondary',
              },
            ),
            InterfaceNode(
              type: 'row',
              id: 'query_row',
              properties: const {'spacing': 8},
              children: [
                const InterfaceNode(
                  type: 'input',
                  id: 'query_input',
                  // width:expand → Expanded in Row so Search keeps intrinsic size
                  // (unbounded TextField otherwise collapses the button to 0×0).
                  properties: {
                    'hint': 'City (e.g. Lucknow)',
                    'label': 'Location',
                    'width': 'expand',
                  },
                  stateBinding: 'query',
                ),
                InterfaceNode(
                  type: 'button',
                  id: 'search',
                  properties: const {
                    'label': 'Search',
                    'primary': true,
                    'flex': 0,
                  },
                  actionBinding: const ActionBinding(actionId: 'refreshData'),
                ),
              ],
            ),
            InterfaceNode(
              type: 'button',
              id: 'refresh',
              properties: const {'label': 'Refresh'},
              actionBinding: const ActionBinding(actionId: 'refreshData'),
            ),
            InterfaceNode(
              type: 'text',
              id: 'loading',
              properties: {'content': '', 'color': 'secondary'},
              stateBinding: 'loadingLabel',
            ),
            InterfaceNode(
              type: 'text',
              id: 'error',
              properties: {'content': '', 'color': 'error'},
              stateBinding: 'error',
            ),
            InterfaceNode(
              type: 'text',
              id: 'result_title',
              properties: {'content': '', 'fontSize': 20},
              stateBinding: 'resultTitle',
            ),
            InterfaceNode(
              type: 'text',
              id: 'result',
              properties: {
                'content':
                    'Search a city for temperature, humidity, wind, and conditions.',
              },
              stateBinding: 'resultText',
            ),
            InterfaceNode(
              type: 'text',
              id: 'provenance',
              properties: {'content': '', 'color': 'secondary', 'fontSize': 12},
              stateBinding: 'provenanceLabel',
            ),
          ],
        ),
      ],
    );
  }

  StateSchema buildState() => const StateSchema(
    variables: [
      StateVariable(id: 'query', type: 'string', defaultValue: ''),
      StateVariable(id: 'loading', type: 'boolean', defaultValue: false),
      StateVariable(id: 'loadingLabel', type: 'string', defaultValue: ''),
      StateVariable(id: 'error', type: 'string', defaultValue: ''),
      StateVariable(id: 'resultTitle', type: 'string', defaultValue: ''),
      StateVariable(
        id: 'resultText',
        type: 'string',
        defaultValue:
            'Search a city for temperature, humidity, wind, and conditions.',
      ),
      StateVariable(id: 'lastKnownResult', type: 'string', defaultValue: '', persistence: 'persistent'),
      StateVariable(id: 'provenanceLabel', type: 'string', defaultValue: ''),
      StateVariable(id: 'sourceType', type: 'string', defaultValue: ''),
    ],
  );

  BehaviorGraph buildBehavior() => const BehaviorGraph(
    nodes: [
      BehaviorNode(
        id: 'refreshData',
        type: 'event',
        config: {'description': 'Fetch structured weather'},
      ),
      BehaviorNode(
        id: 'refreshData_invoke',
        type: 'serviceInvocation',
        config: {
          'serviceId': 'weather',
          'operation': 'getCurrentWeather',
          'queryStateId': 'query',
          'resultStateId': 'resultText',
          'titleStateId': 'resultTitle',
          'loadingStateId': 'loading',
          'loadingLabelStateId': 'loadingLabel',
          'errorStateId': 'error',
          'cacheStateId': 'lastKnownResult',
          'provenanceStateId': 'provenanceLabel',
          'sourceTypeStateId': 'sourceType',
          'expectedSourceType': 'structuredWeather',
        },
      ),
    ],
    edges: [BehaviorEdge(from: 'refreshData', to: 'refreshData_invoke')],
  );

  StateSchema _mergeState(StateSchema a, StateSchema b) {
    final ids = a.variables.map((v) => v.id).toSet();
    return StateSchema(
      variables: [
        ...a.variables,
        ...b.variables.where((v) => !ids.contains(v.id)),
      ],
    );
  }

  BehaviorGraph _mergeBehavior(BehaviorGraph a, BehaviorGraph b) {
    final ids = a.nodes.map((n) => n.id).toSet();
    return BehaviorGraph(
      nodes: [...a.nodes, ...b.nodes.where((n) => !ids.contains(n.id))],
      edges: [...a.edges, ...b.edges],
    );
  }
}
