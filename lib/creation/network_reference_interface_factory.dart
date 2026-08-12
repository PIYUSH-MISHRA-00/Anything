/// Builds a generic network/reference data Experience shell.
///
/// Uses the canonical knowledgeRetrieval service (WebWeaveX via
/// KnowledgeAcquisitionEngine adapter) — never imports WebWeaveX directly.
library;

import 'experience_package.dart';

/// Query → refresh → loading/error/result surface for external data apps.
class NetworkReferenceInterfaceFactory {
  const NetworkReferenceInterfaceFactory();

  ExperiencePackage applyToPackage(
    ExperiencePackage package, {
    required String name,
    String purpose = '',
  }) {
    final interface = buildInterface(title: name, purpose: purpose);
    final state = _mergeState(package.state, buildState());
    final behavior = _mergeBehavior(package.behavior, buildBehavior());
    final services = [
      ...package.services,
      if (!package.services.any((s) => s.type == 'knowledgeRetrieval'))
        const ServiceDefinition(id: 'knowledge', type: 'knowledgeRetrieval'),
    ];
    final network = package.networkDeclarations.isEmpty
        ? [
            NetworkDeclaration(
              purpose: purpose.isEmpty ? 'External reference data' : purpose,
              requiresCredential: false,
            ),
          ]
        : package.networkDeclarations;
    final caps = [
      ...package.capabilityDeclarations,
      if (!package.capabilityDeclarations.any(
        (c) => c.capabilityId == 'knowledge',
      ))
        const CapabilityDeclaration(
          capabilityId: 'knowledge',
          isRequired: true,
        ),
      if (!package.capabilityDeclarations.any(
        (c) => c.capabilityId == 'networkData',
      ))
        const CapabilityDeclaration(
          capabilityId: 'networkData',
          isRequired: true,
        ),
    ];

    final manifest = ExperienceManifest(
      experienceId: package.manifest.experienceId,
      name: package.manifest.name,
      description: package.manifest.description,
      version: package.manifest.version,
      createdAt: package.manifest.createdAt,
      updatedAt: package.manifest.updatedAt,
      networkMode: NetworkMode.required,
      storageMode: package.manifest.storageMode,
      requiredCapabilities: {
        ...package.manifest.requiredCapabilities,
        'knowledge',
        'networkData',
      }.toList(),
      category: package.manifest.category,
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
      networkDeclarations: network,
      capabilityDeclarations: caps,
      permissionDeclarations: package.permissionDeclarations,
      protection: package.protection,
      provenance: package.provenance,
      integrity: package.integrity,
    );
  }

  InterfaceDefinition buildInterface({
    required String title,
    String purpose = '',
  }) {
    return InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'reference_main',
          title: title,
          appBarTitle: title,
          children: [
            if (purpose.isNotEmpty)
              InterfaceNode(
                type: 'text',
                id: 'purpose',
                properties: {'content': purpose, 'color': 'secondary'},
              ),
            InterfaceNode(
              type: 'row',
              id: 'query_row',
              // Do not expandChildren: that stretches Search to full height
              // in a scroll Column and hides result/error text (IS-P11).
              properties: {'spacing': 8},
              children: [
                const InterfaceNode(
                  type: 'input',
                  id: 'query_input',
                  properties: {
                    'label': 'City or location',
                    'hint': 'Enter a city, then press Search',
                    'width': 'expand',
                    'flex': 3,
                  },
                  stateBinding: 'query',
                ),
                InterfaceNode(
                  type: 'button',
                  id: 'search_button',
                  properties: {
                    'label': 'Search',
                    'primary': true,
                    'icon': 'search',
                  },
                  actionBinding: const ActionBinding(actionId: 'refreshData'),
                ),
              ],
            ),
            InterfaceNode(
              type: 'button',
              id: 'refresh_button',
              properties: {'label': 'Refresh', 'compact': true},
              actionBinding: const ActionBinding(actionId: 'refreshData'),
            ),
            InterfaceNode(
              type: 'text',
              id: 'loading_text',
              properties: {'content': '', 'color': 'secondary'},
              stateBinding: 'loadingLabel',
            ),
            InterfaceNode(
              type: 'text',
              id: 'error_text',
              properties: {'content': '', 'color': 'error'},
              stateBinding: 'error',
            ),
            InterfaceNode(
              type: 'text',
              id: 'result_title',
              properties: {'content': '', 'fontSize': 28},
              stateBinding: 'resultTitle',
            ),
            InterfaceNode(
              type: 'text',
              id: 'result_body',
              properties: {
                'content': 'Enter a city or location above, then press Search.',
              },
              stateBinding: 'resultText',
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
          id: 'query',
          type: 'string',
          defaultValue: '',
          persistence: 'persistent',
        ),
        StateVariable(
          id: 'loading',
          type: 'boolean',
          defaultValue: false,
          persistence: 'session',
        ),
        StateVariable(
          id: 'loadingLabel',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        StateVariable(
          id: 'error',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        StateVariable(
          id: 'resultTitle',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        StateVariable(
          id: 'resultText',
          type: 'string',
          defaultValue: 'Enter a city or location above, then press Search.',
          persistence: 'session',
        ),
        StateVariable(
          id: 'lastKnownResult',
          type: 'string',
          defaultValue: '',
          persistence: 'persistent',
        ),
      ],
    );
  }

  BehaviorGraph buildBehavior() {
    return const BehaviorGraph(
      nodes: [
        BehaviorNode(
          id: 'refreshData',
          type: 'event',
          config: {'description': 'Search or refresh external data'},
        ),
        BehaviorNode(
          id: 'refreshData_invoke',
          type: 'serviceInvocation',
          config: {
            'serviceId': 'knowledge',
            'operation': 'retrieve',
            'queryStateId': 'query',
            'resultStateId': 'resultText',
            'titleStateId': 'resultTitle',
            'loadingStateId': 'loading',
            'loadingLabelStateId': 'loadingLabel',
            'errorStateId': 'error',
            'cacheStateId': 'lastKnownResult',
            // Freshness drives query enhancement: when 'current', the
            // knowledge adapter appends 'current latest real-time' to the
            // search query so DuckDuckGo returns recent results instead of
            // encyclopedia articles. Generic — no domain-specific routing.
            'freshness': 'current',
            // IS-P13: reject Wikipedia/generic knowledge as primary result.
            // The adapter sets sourceType to 'currentData' when freshness is
            // 'current'; this expectedSourceType ensures the behavior
            // interpreter rejects encyclopedia fallbacks.
            'expectedSourceType': 'currentData',
          },
        ),
      ],
      edges: [BehaviorEdge(from: 'refreshData', to: 'refreshData_invoke')],
    );
  }

  StateSchema _mergeState(StateSchema existing, StateSchema extra) {
    final ids = existing.variables.map((v) => v.id).toSet();
    return StateSchema(
      variables: [
        ...existing.variables,
        ...extra.variables.where((v) => !ids.contains(v.id)),
      ],
    );
  }

  BehaviorGraph _mergeBehavior(BehaviorGraph existing, BehaviorGraph extra) {
    final ids = existing.nodes.map((n) => n.id).toSet();
    final edgeKeys = existing.edges.map((e) => '${e.from}->${e.to}').toSet();
    return BehaviorGraph(
      nodes: [
        ...existing.nodes,
        ...extra.nodes.where((n) => !ids.contains(n.id)),
      ],
      edges: [
        ...existing.edges,
        ...extra.edges.where((e) => !edgeKeys.contains('${e.from}->${e.to}')),
      ],
    );
  }
}
