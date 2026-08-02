/// Data Engineering — indexes, queries, aggregation, and migration
/// decisions layered on top of V2's DataPlanner/ValidationPlanner output.
///
/// Every decision is grounded in the real, current storage design
/// (ExperienceDatabase's generic JSON-blob table — see
/// docs/audit/V2_SECURITY_AUDIT.md §4) rather than an imagined one.
library;

import '../feature_discovery/feature_types.dart';
import '../software_architect/confidence.dart';
import 'engineering_context.dart';
import 'engineering_types.dart';

class IndexDecision {
  final String entityId;
  final String fieldId;
  final EngineeringDecision decision;
  const IndexDecision({required this.entityId, required this.fieldId, required this.decision});
}

class AggregationDecision {
  final String derivedValueId;
  final EngineeringDecision decision;
  const AggregationDecision({required this.derivedValueId, required this.decision});
}

class DataEngineeringResult {
  final List<IndexDecision> indexes;
  final List<AggregationDecision> aggregations;
  final EngineeringDecision migrationDecision;

  const DataEngineeringResult({
    this.indexes = const [],
    this.aggregations = const [],
    required this.migrationDecision,
  });
}

class DataEngineering {
  const DataEngineering();

  DataEngineeringResult plan(EngineeringContext context) {
    final featureGraph = context.featureGraph;
    bool corroboratedByFeatureDiscovery(String entityId) {
      if (featureGraph == null) return false;
      final persistenceId = 'feature:persistence:$entityId';
      return featureGraph.edgesTo(persistenceId).any((e) {
        return featureGraph.nodeById(e.fromFeatureId)?.category == FeatureCategory.indexing;
      });
    }

    final indexes = <IndexDecision>[];
    for (final entity in context.app.entities) {
      // Recommend an index on the display field and on every reference
      // field — the two access patterns generated list/detail views
      // actually perform (lookup-by-display-value, join-by-reference).
      final candidates = <String>{
        if (entity.displayField.isNotEmpty) entity.displayField,
        ...entity.fields.where((f) => f.referenceEntityId != null).map((f) => f.id),
      };
      final corroborated = corroboratedByFeatureDiscovery(entity.id);
      for (final fieldId in candidates) {
        indexes.add(
          IndexDecision(
            entityId: entity.id,
            fieldId: fieldId,
            decision: EngineeringDecision(
              id: 'index:${entity.id}.$fieldId',
              category: EngineeringDecisionCategory.data,
              subjectId: '${entity.id}.$fieldId',
              decision: 'Recommend an index on $fieldId',
              rationale:
                  'This field is used as a display/reference lookup key. '
                  'Note: the current production storage '
                  '(ExperienceDatabase) is a single generic JSON-blob '
                  'table with no per-field SQL indexes — this is a '
                  'recorded optimization opportunity, not something '
                  'enforced today.'
                  '${corroborated ? ' Confirmed by Feature Discovery\'s Index feature for this entity\'s list view.' : ''}',
              confidence: Confidence(
                score: corroborated ? 0.85 : 0.7,
                reason: corroborated
                    ? 'Real access-pattern signal, corroborated by an independently discovered Index feature.'
                    : 'Real access-pattern signal, but no index actually exists yet.',
                risk: RiskLevel.low,
              ),
            ),
          ),
        );
      }
    }

    final aggregations = context.app.derivedValues.map((dv) {
      return AggregationDecision(
        derivedValueId: dv.id,
        decision: EngineeringDecision(
          id: 'aggregation:${dv.id}',
          category: EngineeringDecisionCategory.data,
          subjectId: dv.id,
          decision: '${dv.name} computed via ${dv.operation.name} over ${dv.sourceEntityId}',
          rationale:
              'Recomputed on demand from the current data set — matches '
              'BehaviorInterpreter\'s existing aggregate calculation node '
              'types, not a new mechanism.',
          confidence: Confidence.full,
        ),
      );
    }).toList();

    final migrationDecision = EngineeringDecision(
      id: 'migration:policy',
      category: EngineeringDecisionCategory.migration,
      subjectId: 'schema',
      decision: 'No SQL migration required for field/entity additions',
      rationale:
          'ExperienceDatabase stores every record as an opaque JSON blob '
          'in one generic table; adding a field or entity to the '
          'DataSchema needs no DDL migration — old records simply lack '
          'the new field until next written (see '
          'docs/audit/V2_SECURITY_AUDIT.md §14). The separate, unused '
          'MigrationExecutor/SchemaStorageMapper module remains available '
          '(and M2-hardened) for a future, structurally different storage '
          'design, but is not on the live path today.',
      confidence: Confidence.full,
    );

    return DataEngineeringResult(
      indexes: indexes,
      aggregations: aggregations,
      migrationDecision: migrationDecision,
    );
  }
}
