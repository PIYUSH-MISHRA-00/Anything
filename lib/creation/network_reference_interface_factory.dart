/// Builds a generic network/reference data Experience shell.
///
/// Uses the canonical knowledgeRetrieval service (WebWeaveX via
/// KnowledgeAcquisitionEngine adapter) — never imports WebWeaveX directly.
library;

import 'experience_package.dart';

/// Semantic subject of an Experience, derived generically from the user's
/// own words (intent expression or blueprint description). Construction
/// language ("build me a professional … app") is filtered out; what remains
/// is the topic the Experience is about — e.g. "weather" for a weather
/// dashboard, "news" for a news app, "fermentation" for a fermentation
/// tracker. Never a domain table: the words come from the request itself.
List<String> deriveTopicTerms(String text, {int max = 3}) {
  const constructionWords = {
    // request framing
    'build', 'make', 'create', 'give', 'want', 'need', 'please', 'can',
    'you', 'i', 'me', 'my', 'a', 'an', 'the', 'that', 'this', 'lets', 'let',
    'and', 'or', 'of', 'in', 'on', 'for', 'with', 'to', 'is', 'it', 'be',
    'have', 'has', 'will', 'would', 'should',
    // app-form nouns and qualifiers (what KIND of software, not its subject)
    'app', 'application', 'apps', 'dashboard', 'tracker', 'tool', 'planner',
    'manager', 'organizer', 'viewer', 'browser', 'experience', 'professional',
    'simple', 'basic', 'advanced', 'polished', 'nice', 'modern', 'good',
    // generic interaction verbs the shell already provides
    'search', 'searches', 'refresh', 'show', 'shows', 'display', 'displays',
    'view', 'views', 'list', 'lists', 'get', 'gets', 'find', 'finds',
    'check', 'checks', 'track', 'tracks', 'see', 'lookup', 'look', 'up',
    'locations', 'location', 'city', 'cities', 'place', 'places',
    // freshness words — carried by the freshness semantic, not the topic
    'current', 'live', 'latest', 'real', 'time', 'realtime', 'today', 'now',
    'daily', 'updated',
  };
  final counts = <String, int>{};
  final order = <String>[];
  for (final raw in text.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
    if (raw.length < 3 || constructionWords.contains(raw)) continue;
    counts[raw] = (counts[raw] ?? 0) + 1;
    if (!order.contains(raw)) order.add(raw);
  }
  order.sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return order.take(max).toList();
}

/// Query → refresh → loading/error/result surface for external data apps.
class NetworkReferenceInterfaceFactory {
  const NetworkReferenceInterfaceFactory();

  ExperiencePackage applyToPackage(
    ExperiencePackage package, {
    required String name,
    String purpose = '',
    String topic = '',
    String freshness = '',
  }) {
    final interface = buildInterface(title: name, purpose: purpose);
    final state = _mergeState(package.state, buildState());
    final behavior = _mergeBehavior(
      package.behavior,
      buildBehavior(topic: topic, freshness: freshness),
    );
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
    String queryLabel = 'City or location',
    String queryHint = 'Enter a city, then press Search',
    String screenId = 'reference_main',
  }) {
    return InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: screenId,
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
                InterfaceNode(
                  type: 'input',
                  id: 'query_input',
                  properties: {
                    'label': queryLabel,
                    'hint': queryHint,
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
            const InterfaceNode(
              type: 'remoteImage',
              id: 'result_image',
              properties: {'semanticLabel': 'Result image'},
              stateBinding: 'resultImage',
            ),
            InterfaceNode(
              type: 'text',
              id: 'result_body',
              properties: {
                'content': 'Enter a city or location above, then press Search.',
              },
              stateBinding: 'resultText',
            ),
            const InterfaceNode(
              type: 'text',
              id: 'source_label',
              properties: {'content': '', 'color': 'secondary'},
              stateBinding: 'sourceLabel',
            ),
          ],
        ),
      ],
    );
  }

  StateSchema buildState({
    String emptyHint = 'Enter a city or location above, then press Search.',
  }) {
    return StateSchema(
      variables: [
        const StateVariable(
          id: 'query',
          type: 'string',
          defaultValue: '',
          persistence: 'persistent',
        ),
        const StateVariable(
          id: 'loading',
          type: 'boolean',
          defaultValue: false,
          persistence: 'session',
        ),
        const StateVariable(
          id: 'loadingLabel',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        const StateVariable(
          id: 'error',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        const StateVariable(
          id: 'resultTitle',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        StateVariable(
          id: 'resultText',
          type: 'string',
          defaultValue: emptyHint,
          persistence: 'session',
        ),
        StateVariable(
          id: 'lastKnownResult',
          type: 'string',
          defaultValue: '',
          persistence: 'persistent',
        ),
        StateVariable(
          id: 'resultImage',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        StateVariable(
          id: 'sourceLabel',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
      ],
    );
  }

  /// [topic] is the Experience's semantic subject (requirement
  /// preservation — see [deriveTopicTerms]); [freshness] is 'current' when
  /// the Experience's data requirement is for live/current external data,
  /// or '' for reference material. Both are semantics carried from the
  /// creation intent, never a domain switch.
  BehaviorGraph buildBehavior({String topic = '', String freshness = ''}) {
    return BehaviorGraph(
      nodes: [
        const BehaviorNode(
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
            'imageStateId': 'resultImage',
            'provenanceStateId': 'sourceLabel',
            // IS-P25 requirement preservation: the acquisition layer
            // composes queries as "<search term> <topic> [current]" and
            // judges evidence against these same semantics.
            'topic': topic,
            'freshness': freshness,
          },
        ),
      ],
      edges: const [
        BehaviorEdge(from: 'refreshData', to: 'refreshData_invoke'),
      ],
    );
  }

  /// The Discover browse tab's screen id (idempotency guard).
  static const discoverScreenId = 'discover';

  /// Compose a WebWeaveX "Discover" browse tab onto a records app so the user
  /// can find real-world data from the web (real restaurants/trains/books/…),
  /// not only hand-enter records. Additive: the app's own list/form tabs are
  /// untouched. Skips apps with no entities (calculator/timer) and apps that
  /// already ARE a browse surface (weather/news reference shells).
  ///
  /// ponytail: the Discover screen shows ONE summarized web result (title +
  /// image + text + source) — the existing reference UI. A scrollable list of
  /// results is the upgrade path if single-result browse proves too thin.
  ExperiencePackage composeDiscoverTab(
    ExperiencePackage package, {
    required String subject,
  }) {
    final entities = package.data?.entities ?? const [];
    if (entities.isEmpty) return package;
    final screens = package.interface.screens;
    if (screens.any(
      (s) => s.id == discoverScreenId || s.id == 'reference_main',
    )) {
      return package;
    }
    // Only a real records app (one with a rendered list surface) gets Discover.
    // A package with entities but no entityList screen isn't a browsable app.
    bool hasList(InterfaceNode n) =>
        n.type == 'entityList' || n.children.any(hasList);
    if (!screens.any((s) => s.children.any(hasList))) return package;

    final subj = subject.trim().isEmpty ? 'results' : subject.trim();
    final discover = buildInterface(
      title: 'Discover',
      purpose: 'Find real $subj from the web',
      queryLabel: 'Search $subj',
      queryHint: 'e.g. best $subj near me',
      screenId: discoverScreenId,
    ).screens.first;

    // A bottom nav with the app's existing tabs (or its list screens) + Discover.
    final existing =
        package.interface.navigation?.items ?? _listNavItems(screens);
    final interface = InterfaceDefinition(
      screens: [...screens, discover],
      navigation: NavigationDefinition(
        type: 'bottomNavigation',
        items: [
          ...existing,
          const NavigationItem(
            label: 'Discover',
            icon: 'search',
            screenId: discoverScreenId,
          ),
        ],
      ),
    );

    final services = [
      ...package.services,
      if (!package.services.any((s) => s.type == 'knowledgeRetrieval'))
        const ServiceDefinition(id: 'knowledge', type: 'knowledgeRetrieval'),
    ];
    final caps = [
      ...package.capabilityDeclarations,
      if (!package.capabilityDeclarations.any((c) => c.capabilityId == 'knowledge'))
        const CapabilityDeclaration(capabilityId: 'knowledge', isRequired: true),
      if (!package.capabilityDeclarations.any(
        (c) => c.capabilityId == 'networkData',
      ))
        const CapabilityDeclaration(
          capabilityId: 'networkData',
          isRequired: true,
        ),
    ];
    final network = package.networkDeclarations.isEmpty
        ? [
            const NetworkDeclaration(
              purpose: 'Discover real-world data',
              requiresCredential: false,
            ),
          ]
        : package.networkDeclarations;

    // The manifest is left untouched: a records app is offline-first and the
    // Discover tab is an OPTIONAL online extra. Forcing networkMode.required or
    // extra required-capabilities would make the whole app refuse to open
    // offline. The knowledge service + capability declarations below are all
    // the Discover tab needs to fetch when the user actually uses it.
    return ExperiencePackage(
      packageVersion: package.packageVersion,
      manifest: package.manifest,
      interface: interface,
      behavior: _mergeBehavior(package.behavior, buildBehavior(topic: subj)),
      state: _mergeState(
        package.state,
        buildState(emptyHint: 'Search above to find $subj from the web.'),
      ),
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

  /// Nav items for the app's list screens (any screen containing an
  /// entityList), used when the app had no bottom nav yet (single-list app).
  List<NavigationItem> _listNavItems(List<InterfaceScreen> screens) {
    bool walk(InterfaceNode n) =>
        n.type == 'entityList' || n.children.any(walk);
    final lists = screens.where((s) => s.children.any(walk)).toList();
    final chosen = lists.isNotEmpty
        ? lists
        : (screens.isEmpty ? <InterfaceScreen>[] : [screens.first]);
    return [
      for (final s in chosen)
        NavigationItem(label: s.title, icon: 'list', screenId: s.id),
    ];
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
