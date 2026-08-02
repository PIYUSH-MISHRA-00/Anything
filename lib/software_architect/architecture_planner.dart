/// Architecture Planner — the top-level orchestrator. Given a SemanticApp
/// (the reasoner's real, already-certified output) it runs every
/// sub-planner and assembles one ArchitectureCandidate, with confidence
/// computed from what was actually planned.
library;

import 'package:uuid/uuid.dart';

import '../synthesis/application_reasoner.dart';
import 'architecture_candidate.dart';
import 'capability_security_planner.dart';
import 'confidence.dart';
import 'confidence_analyzer.dart';
import 'data_planner.dart';
import 'state_navigation_interaction_planner.dart';
import 'validation_planner.dart';

class ArchitecturePlanner {
  final EntityPlanner _entityPlanner;
  final FieldPlanner _fieldPlanner;
  final RelationshipPlanner _relationshipPlanner;
  final StatePlanner _statePlanner;
  final NavigationPlanner _navigationPlanner;
  final InteractionPlanner _interactionPlanner;
  final CapabilityPlanner _capabilityPlanner;
  final PermissionPlanner _permissionPlanner;
  final SecurityPlanner _securityPlanner;
  final OfflinePlanner _offlinePlanner;
  final SynchronizationPlanner _synchronizationPlanner;
  final ValidationPlanner _validationPlanner;
  final ConfidenceAnalyzer _confidenceAnalyzer;

  const ArchitecturePlanner({
    EntityPlanner entityPlanner = const EntityPlanner(),
    FieldPlanner fieldPlanner = const FieldPlanner(),
    RelationshipPlanner relationshipPlanner = const RelationshipPlanner(),
    StatePlanner statePlanner = const StatePlanner(),
    NavigationPlanner navigationPlanner = const NavigationPlanner(),
    InteractionPlanner interactionPlanner = const InteractionPlanner(),
    CapabilityPlanner capabilityPlanner = const CapabilityPlanner(),
    PermissionPlanner permissionPlanner = const PermissionPlanner(),
    SecurityPlanner securityPlanner = const SecurityPlanner(),
    OfflinePlanner offlinePlanner = const OfflinePlanner(),
    SynchronizationPlanner synchronizationPlanner =
        const SynchronizationPlanner(),
    ValidationPlanner validationPlanner = const ValidationPlanner(),
    ConfidenceAnalyzer confidenceAnalyzer = const ConfidenceAnalyzer(),
  }) : _entityPlanner = entityPlanner,
       _fieldPlanner = fieldPlanner,
       _relationshipPlanner = relationshipPlanner,
       _statePlanner = statePlanner,
       _navigationPlanner = navigationPlanner,
       _interactionPlanner = interactionPlanner,
       _capabilityPlanner = capabilityPlanner,
       _permissionPlanner = permissionPlanner,
       _securityPlanner = securityPlanner,
       _offlinePlanner = offlinePlanner,
       _synchronizationPlanner = synchronizationPlanner,
       _validationPlanner = validationPlanner,
       _confidenceAnalyzer = confidenceAnalyzer;

  ArchitectureCandidate plan(SemanticApp app) {
    final entities = _entityPlanner.plan(app.entities);
    final fields = _fieldPlanner.plan(app.entities);
    final relationships = _relationshipPlanner.plan(app.entities);
    final states = _statePlanner.plan(app);
    final navigation = _navigationPlanner.plan(app);
    final interactions = _interactionPlanner.plan(app);
    final capabilities = _capabilityPlanner.plan(app.requiredCapabilities);
    final permissions = _permissionPlanner.plan(capabilities);
    final security = _securityPlanner.plan(capabilities);
    final offline = _offlinePlanner.plan(capabilities);
    final synchronization = _synchronizationPlanner.plan(offline);
    final validations = _validationPlanner.plan(app.entities);

    final candidate = ArchitectureCandidate(
      id: const Uuid().v4(),
      appName: app.name,
      entities: entities,
      fields: fields,
      relationships: relationships,
      states: states,
      navigation: navigation,
      interactions: interactions,
      capabilities: capabilities,
      permissions: permissions,
      security: security,
      offline: offline,
      synchronization: synchronization,
      validations: validations,
      overallConfidence: const Confidence(
        score: 0.0,
        reason: 'not yet analyzed',
      ),
    );

    return candidate.copyWith(
      overallConfidence: _confidenceAnalyzer.analyze(candidate),
    );
  }
}
