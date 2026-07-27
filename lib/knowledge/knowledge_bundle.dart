/// Knowledge Bundle — grouped resources for one or more knowledge requirements.
library;

import 'knowledge_resource.dart';

/// Status of a knowledge bundle.
enum BundleStatus { ready, partial, offlineCached, failed }

/// A bundle of knowledge resources satisfying requirements.
class KnowledgeBundle {
  final String id;
  final BundleStatus status;
  final List<KnowledgeResource> resources;
  final List<String> requirementsSatisfied;
  final List<String> unresolvedRequirements;
  final List<String> warnings;
  final DateTime generatedAt;
  final String? cacheStatus;

  const KnowledgeBundle({
    required this.id,
    required this.status,
    required this.resources,
    this.requirementsSatisfied = const [],
    this.unresolvedRequirements = const [],
    this.warnings = const [],
    required this.generatedAt,
    this.cacheStatus,
  });

  bool get isEmpty => resources.isEmpty;
  int get resourceCount => resources.length;

  /// Merge another bundle into this one, deduplicating by resource ID.
  ///
  /// Resources from [other] are appended. Requirements satisfied and
  /// unresolved are combined. Warnings are combined. Status is derived
  /// from the merged state.
  KnowledgeBundle mergedWith(KnowledgeBundle other) {
    final seenIds = <String>{};
    final mergedResources = <KnowledgeResource>[];
    for (final r in resources) {
      if (seenIds.add(r.id)) mergedResources.add(r);
    }
    for (final r in other.resources) {
      if (seenIds.add(r.id)) mergedResources.add(r);
    }
    final mergedSatisfied = {
      ...requirementsSatisfied,
      ...other.requirementsSatisfied,
    }.toList();
    final mergedUnresolved = {
      ...unresolvedRequirements,
      ...other.unresolvedRequirements,
    }.toList();
    final mergedWarnings = [...warnings, ...other.warnings];
    final status = mergedUnresolved.isEmpty
        ? BundleStatus.ready
        : (mergedResources.isEmpty
            ? BundleStatus.failed
            : BundleStatus.partial);
    return KnowledgeBundle(
      id: id,
      status: status,
      resources: mergedResources,
      requirementsSatisfied: mergedSatisfied,
      unresolvedRequirements: mergedUnresolved,
      warnings: mergedWarnings,
      generatedAt: generatedAt.isAfter(other.generatedAt)
          ? generatedAt
          : other.generatedAt,
    );
  }

  /// Get resources sorted by ranking.
  List<KnowledgeResource> get rankedResources {
    final sorted = List<KnowledgeResource>.from(resources);
    sorted.sort(
      (a, b) => b.ranking.overallScore.compareTo(a.ranking.overallScore),
    );
    return sorted;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.name,
    'resources': resources.map((r) => r.toJson()).toList(),
    'requirementsSatisfied': requirementsSatisfied,
    'unresolvedRequirements': unresolvedRequirements,
    'warnings': warnings,
    'generatedAt': generatedAt.toIso8601String(),
    'cacheStatus': cacheStatus,
  };

  factory KnowledgeBundle.fromJson(Map<String, dynamic> json) {
    return KnowledgeBundle(
      id: json['id'] as String,
      status: BundleStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BundleStatus.failed,
      ),
      resources:
          (json['resources'] as List?)
              ?.map(
                (r) => KnowledgeResource.fromJson(r as Map<String, dynamic>),
              )
              .toList() ??
          [],
      requirementsSatisfied: List<String>.from(
        json['requirementsSatisfied'] ?? [],
      ),
      unresolvedRequirements: List<String>.from(
        json['unresolvedRequirements'] ?? [],
      ),
      warnings: List<String>.from(json['warnings'] ?? []),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      cacheStatus: json['cacheStatus'] as String?,
    );
  }
}
