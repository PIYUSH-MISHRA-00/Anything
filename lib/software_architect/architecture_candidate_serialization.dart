/// ArchitectureCandidate (de)serialization — Implementation Milestone R5.
/// Same convention as `requirement_graph_serialization.dart`: hand-written
/// `toJson()`/`fromJson()`, full fidelity — every field round-trips.
library;

import 'architecture_candidate.dart';
import 'architecture_types.dart';
import 'confidence.dart';

Map<String, dynamic> _confidenceToJson(Confidence c) => {
  'score': c.score,
  'reason': c.reason,
  'missingKnowledge': c.missingKnowledge,
  'risk': c.risk.name,
  'alternatives': c.alternatives,
};

Confidence _confidenceFromJson(Map<String, dynamic> json) => Confidence(
  score: (json['score'] as num).toDouble(),
  reason: json['reason'] as String,
  missingKnowledge: (json['missingKnowledge'] as List).cast<String>(),
  risk: RiskLevel.values.byName(json['risk'] as String),
  alternatives: (json['alternatives'] as List).cast<String>(),
);

Map<String, dynamic> _decisionToJson(ArchitectureDecision d) => {
  'id': d.id,
  'category': d.category.name,
  'subjectId': d.subjectId,
  'decision': d.decision,
  'rationale': d.rationale,
  'confidence': _confidenceToJson(d.confidence),
  'alternatives': d.alternatives,
  'securityImplication': d.securityImplication,
  'offlineImplication': d.offlineImplication,
};

ArchitectureDecision _decisionFromJson(Map<String, dynamic> json) =>
    ArchitectureDecision(
      id: json['id'] as String,
      category: ArchitectureDecisionCategory.values.byName(
        json['category'] as String,
      ),
      subjectId: json['subjectId'] as String,
      decision: json['decision'] as String,
      rationale: json['rationale'] as String,
      confidence: _confidenceFromJson(
        json['confidence'] as Map<String, dynamic>,
      ),
      alternatives: (json['alternatives'] as List).cast<String>(),
      securityImplication: json['securityImplication'] as String?,
      offlineImplication: json['offlineImplication'] as String?,
    );

extension ArchitectureCandidateJson on ArchitectureCandidate {
  Map<String, dynamic> toJson() => {
    'id': id,
    'appName': appName,
    'iteration': iteration,
    'entities': entities
        .map(
          (e) => {
            'entityId': e.entityId,
            'name': e.name,
            'fieldCount': e.fieldCount,
            'storage': e.storage.name,
            'storageDecision': _decisionToJson(e.storageDecision),
          },
        )
        .toList(),
    'fields': fields
        .map(
          (f) => {
            'entityId': f.entityId,
            'fieldId': f.fieldId,
            'name': f.name,
            'validationDecision': _decisionToJson(f.validationDecision),
          },
        )
        .toList(),
    'relationships': relationships
        .map(
          (r) => {
            'fromEntityId': r.fromEntityId,
            'toEntityId': r.toEntityId,
            'fieldId': r.fieldId,
            'deletePolicy': r.deletePolicy.name,
            'decision': _decisionToJson(r.decision),
          },
        )
        .toList(),
    'states': states
        .map(
          (s) => {
            'stateId': s.stateId,
            'kind': s.kind.name,
            'decision': _decisionToJson(s.decision),
          },
        )
        .toList(),
    'navigation': {
      'entryScreenId': navigation.entryScreenId,
      'screenIds': navigation.screenIds,
      'edges': navigation.edges
          .map(
            (e) => {
              'fromScreenId': e.fromScreenId,
              'toScreenId': e.toScreenId,
              'trigger': e.trigger,
              'isModal': e.isModal,
            },
          )
          .toList(),
      'decision': _decisionToJson(navigation.decision),
    },
    'interactions': interactions
        .map(
          (i) => {
            'entityId': i.entityId,
            'canCreate': i.canCreate,
            'canRead': i.canRead,
            'canUpdate': i.canUpdate,
            'canDelete': i.canDelete,
            'supportsSearch': i.supportsSearch,
            'supportsFilter': i.supportsFilter,
            'supportsSort': i.supportsSort,
            'supportsPagination': i.supportsPagination,
            'decision': _decisionToJson(i.decision),
          },
        )
        .toList(),
    'capabilities': capabilities
        .map(
          (c) => {
            'capabilityId': c.capabilityId,
            'resolved': c.resolved,
            'decision': _decisionToJson(c.decision),
          },
        )
        .toList(),
    'permissions': permissions
        .map(
          (p) => {
            'permission': p.permission,
            'requiredByCapabilityId': p.requiredByCapabilityId,
            'decision': _decisionToJson(p.decision),
          },
        )
        .toList(),
    'security': {
      'networkMode': security.networkMode.name,
      'requiresCredentialVault': security.requiresCredentialVault,
      'decision': _decisionToJson(security.decision),
    },
    'offline': {
      'capability': offline.capability.name,
      'decision': _decisionToJson(offline.decision),
    },
    'synchronization': {
      'strategy': synchronization.strategy.name,
      'decision': _decisionToJson(synchronization.decision),
    },
    'validations': validations
        .map(
          (v) => {
            'entityId': v.entityId,
            'fieldId': v.fieldId,
            'type': v.type.name,
            'description': v.description,
          },
        )
        .toList(),
    'overallConfidence': _confidenceToJson(overallConfidence),
  };

  static ArchitectureCandidate fromJson(Map<String, dynamic> json) {
    final nav = json['navigation'] as Map<String, dynamic>;
    final sec = json['security'] as Map<String, dynamic>;
    final off = json['offline'] as Map<String, dynamic>;
    final sync = json['synchronization'] as Map<String, dynamic>;

    return ArchitectureCandidate(
      id: json['id'] as String,
      appName: json['appName'] as String,
      iteration: json['iteration'] as int? ?? 0,
      entities: (json['entities'] as List)
          .map(
            (e) => EntityDecision(
              entityId: e['entityId'] as String,
              name: e['name'] as String,
              fieldCount: e['fieldCount'] as int,
              storage: StorageKind.values.byName(e['storage'] as String),
              storageDecision: _decisionFromJson(
                e['storageDecision'] as Map<String, dynamic>,
              ),
            ),
          )
          .toList(),
      fields: (json['fields'] as List)
          .map(
            (f) => FieldDecision(
              entityId: f['entityId'] as String,
              fieldId: f['fieldId'] as String,
              name: f['name'] as String,
              validationDecision: _decisionFromJson(
                f['validationDecision'] as Map<String, dynamic>,
              ),
            ),
          )
          .toList(),
      relationships: (json['relationships'] as List)
          .map(
            (r) => RelationshipDecision(
              fromEntityId: r['fromEntityId'] as String,
              toEntityId: r['toEntityId'] as String,
              fieldId: r['fieldId'] as String,
              deletePolicy: RelationshipDeletePolicy.values.byName(
                r['deletePolicy'] as String,
              ),
              decision: _decisionFromJson(
                r['decision'] as Map<String, dynamic>,
              ),
            ),
          )
          .toList(),
      states: (json['states'] as List)
          .map(
            (s) => StateDecision(
              stateId: s['stateId'] as String,
              kind: StateKind.values.byName(s['kind'] as String),
              decision: _decisionFromJson(
                s['decision'] as Map<String, dynamic>,
              ),
            ),
          )
          .toList(),
      navigation: NavigationGraph(
        entryScreenId: nav['entryScreenId'] as String,
        screenIds: (nav['screenIds'] as List).cast<String>(),
        edges: (nav['edges'] as List)
            .map(
              (e) => NavigationEdge(
                fromScreenId: e['fromScreenId'] as String,
                toScreenId: e['toScreenId'] as String,
                trigger: e['trigger'] as String,
                isModal: e['isModal'] as bool? ?? false,
              ),
            )
            .toList(),
        decision: _decisionFromJson(nav['decision'] as Map<String, dynamic>),
      ),
      interactions: (json['interactions'] as List)
          .map(
            (i) => InteractionDecision(
              entityId: i['entityId'] as String,
              canCreate: i['canCreate'] as bool,
              canRead: i['canRead'] as bool,
              canUpdate: i['canUpdate'] as bool,
              canDelete: i['canDelete'] as bool,
              supportsSearch: i['supportsSearch'] as bool,
              supportsFilter: i['supportsFilter'] as bool,
              supportsSort: i['supportsSort'] as bool,
              supportsPagination: i['supportsPagination'] as bool,
              decision: _decisionFromJson(
                i['decision'] as Map<String, dynamic>,
              ),
            ),
          )
          .toList(),
      capabilities: (json['capabilities'] as List)
          .map(
            (c) => CapabilityDecision(
              capabilityId: c['capabilityId'] as String,
              resolved: c['resolved'] as bool,
              decision: _decisionFromJson(
                c['decision'] as Map<String, dynamic>,
              ),
            ),
          )
          .toList(),
      permissions: (json['permissions'] as List)
          .map(
            (p) => PermissionDecision(
              permission: p['permission'] as String,
              requiredByCapabilityId: p['requiredByCapabilityId'] as String,
              decision: _decisionFromJson(
                p['decision'] as Map<String, dynamic>,
              ),
            ),
          )
          .toList(),
      security: SecurityDecision(
        networkMode: NetworkMode.values.byName(sec['networkMode'] as String),
        requiresCredentialVault: sec['requiresCredentialVault'] as bool,
        decision: _decisionFromJson(sec['decision'] as Map<String, dynamic>),
      ),
      offline: OfflineDecision(
        capability: OfflineCapability.values.byName(
          off['capability'] as String,
        ),
        decision: _decisionFromJson(off['decision'] as Map<String, dynamic>),
      ),
      synchronization: SynchronizationDecision(
        strategy: SyncStrategy.values.byName(sync['strategy'] as String),
        decision: _decisionFromJson(sync['decision'] as Map<String, dynamic>),
      ),
      validations: (json['validations'] as List)
          .map(
            (v) => ValidationRule(
              entityId: v['entityId'] as String,
              fieldId: v['fieldId'] as String,
              type: ValidationRuleType.values.byName(v['type'] as String),
              description: v['description'] as String,
            ),
          )
          .toList(),
      overallConfidence: _confidenceFromJson(
        json['overallConfidence'] as Map<String, dynamic>,
      ),
    );
  }
}
