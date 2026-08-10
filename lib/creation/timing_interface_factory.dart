/// Builds a generic timing Experience surface from the `timers` capability.
library;

import '../runtime/timing_session.dart';
import 'experience_package.dart';

/// Deterministic timing UI + state + behavior nodes.
class TimingInterfaceFactory {
  const TimingInterfaceFactory();

  ExperiencePackage applyToPackage(
    ExperiencePackage package, {
    required String name,
  }) {
    final interface = buildInterface(title: name);
    // Overlay wins for timing variables so model leftovers cannot poison types.
    final state = _mergeStatePreferOverlay(package.state, buildState());
    final behavior = _mergeBehavior(package.behavior, buildBehavior());
    final caps = [
      ...package.capabilityDeclarations,
      if (!package.capabilityDeclarations.any(
        (c) => c.capabilityId == 'timers',
      ))
        const CapabilityDeclaration(capabilityId: 'timers', isRequired: true),
    ];

    final required = {
      ...package.manifest.requiredCapabilities,
      'timers',
    }.toList();
    final manifest = ExperienceManifest(
      experienceId: package.manifest.experienceId,
      name: name,
      description: package.manifest.description,
      version: package.manifest.version,
      createdAt: package.manifest.createdAt,
      updatedAt: package.manifest.updatedAt,
      networkMode: NetworkMode.none,
      storageMode: package.manifest.storageMode,
      requiredCapabilities: required,
      category: package.manifest.category.isEmpty
          ? 'utility'
          : package.manifest.category,
      tags: package.manifest.tags,
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

  InterfaceDefinition buildInterface({required String title}) {
    InterfaceNode btn(
      String id,
      String label,
      String action, {
      bool primary = false,
      bool accent = false,
    }) {
      return InterfaceNode(
        type: 'button',
        id: id,
        properties: {
          'label': label,
          // Safe inside timingPad's bounded 56px rows (not a scroll view).
          'width': 'expand',
          if (primary) 'primary': true,
          if (accent) 'accent': true,
        },
        actionBinding: ActionBinding(actionId: action),
      );
    }

    return InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'timing_main',
          title: title,
          appBarTitle: title,
          children: [
            InterfaceNode(
              type: 'timingPad',
              id: 'timing_pad',
              children: [
                InterfaceNode(
                  type: 'text',
                  id: 'status',
                  properties: {
                    'content': 'Ready',
                    'color': 'secondary',
                    'textAlign': 'center',
                  },
                  stateBinding: 'statusLabel',
                ),
                InterfaceNode(
                  type: 'text',
                  id: 'display',
                  properties: {
                    'content': '00:00.00',
                    'fontSize': 56,
                    'textAlign': 'center',
                  },
                  stateBinding: 'display',
                ),
                InterfaceNode(
                  type: 'row',
                  id: 'controls',
                  properties: const {'spacing': 8, 'expandChildren': true},
                  children: [
                    btn('start', 'Start', TimingSession.start, primary: true),
                    btn('pause', 'Pause', TimingSession.pause),
                    btn('resume', 'Resume', TimingSession.resume, accent: true),
                  ],
                ),
                InterfaceNode(
                  type: 'row',
                  id: 'controls2',
                  properties: const {'spacing': 8, 'expandChildren': true},
                  children: [
                    btn('lap', 'Lap', TimingSession.lap),
                    btn('reset', 'Reset', TimingSession.reset),
                  ],
                ),
                InterfaceNode(
                  type: 'text',
                  id: 'laps_heading',
                  properties: {'content': 'Laps', 'color': 'secondary'},
                ),
                InterfaceNode(
                  type: 'text',
                  id: 'laps',
                  properties: {'content': '', 'color': 'secondary'},
                  stateBinding: 'lapsText',
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
          defaultValue: '00:00.00',
          persistence: 'session',
        ),
        StateVariable(
          id: 'statusLabel',
          type: 'string',
          defaultValue: 'Ready',
          persistence: 'session',
        ),
        StateVariable(
          id: 'running',
          type: 'boolean',
          defaultValue: false,
          persistence: 'session',
        ),
        StateVariable(
          id: 'startedAtMs',
          type: 'integer',
          defaultValue: 0,
          persistence: 'session',
        ),
        StateVariable(
          id: 'accumulatedMs',
          type: 'integer',
          defaultValue: 0,
          persistence: 'session',
        ),
        StateVariable(
          id: 'lapsText',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        StateVariable(
          id: 'laps',
          type: 'list',
          defaultValue: <String>[],
          persistence: 'session',
        ),
      ],
    );
  }

  BehaviorGraph buildBehavior() {
    BehaviorNode ev(String id) =>
        BehaviorNode(id: id, type: 'event', config: const {});
    return BehaviorGraph(
      nodes: [
        ev(TimingSession.start),
        ev(TimingSession.pause),
        ev(TimingSession.resume),
        ev(TimingSession.reset),
        ev(TimingSession.lap),
        ev(TimingSession.tick),
      ],
      edges: const [],
    );
  }

  StateSchema _mergeStatePreferOverlay(StateSchema base, StateSchema overlay) {
    final overlayIds = overlay.variables.map((v) => v.id).toSet();
    return StateSchema(
      variables: [
        ...base.variables.where((v) => !overlayIds.contains(v.id)),
        ...overlay.variables,
      ],
    );
  }

  BehaviorGraph _mergeBehavior(BehaviorGraph base, BehaviorGraph overlay) {
    final ids = base.nodes.map((n) => n.id).toSet();
    return BehaviorGraph(
      nodes: [
        ...base.nodes,
        ...overlay.nodes.where((n) => !ids.contains(n.id)),
      ],
      edges: [...base.edges, ...overlay.edges],
    );
  }
}
