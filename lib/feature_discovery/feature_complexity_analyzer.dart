/// Feature Complexity Analyzer — assigns a typed FeatureComplexity to each
/// FeatureCandidate via an honest, static, per-category table. No
/// arbitrary numbers — every cost dimension is a bounded ComplexityLevel.
library;

import 'feature_types.dart';

class FeatureComplexityAnalyzer {
  const FeatureComplexityAnalyzer();

  static const FeatureComplexity _low = FeatureComplexity();

  static const FeatureComplexity _persistence = FeatureComplexity(
    implementation: ComplexityLevel.low,
    engineering: ComplexityLevel.low,
    storageCost: ComplexityLevel.low,
  );

  static const FeatureComplexity _relational = FeatureComplexity(
    implementation: ComplexityLevel.medium,
    engineering: ComplexityLevel.medium,
  );

  // Real, honest finding (matches DataEngineering, V3): no per-field SQL
  // index exists on the live path today — building one is a schema change,
  // not a config flag.
  static const FeatureComplexity _index = FeatureComplexity(
    implementation: ComplexityLevel.medium,
    engineering: ComplexityLevel.high,
    maintenanceCost: ComplexityLevel.medium,
  );

  static const FeatureComplexity _search = FeatureComplexity(
    implementation: ComplexityLevel.medium,
    engineering: ComplexityLevel.medium,
    memoryCost: ComplexityLevel.low,
  );

  static const FeatureComplexity _capabilityKnown = FeatureComplexity(
    implementation: ComplexityLevel.low,
    engineering: ComplexityLevel.low,
  );

  static const FeatureComplexity _capabilityExperimental = FeatureComplexity(
    implementation: ComplexityLevel.high,
    engineering: ComplexityLevel.high,
    maintenanceCost: ComplexityLevel.high,
    modificationCost: ComplexityLevel.medium,
  );

  static const FeatureComplexity _permission = FeatureComplexity(
    implementation: ComplexityLevel.medium,
    engineering: ComplexityLevel.medium,
  );

  static const FeatureComplexity _offline = FeatureComplexity(
    implementation: ComplexityLevel.high,
    engineering: ComplexityLevel.high,
    runtime: ComplexityLevel.medium,
    batteryCost: ComplexityLevel.low,
    networkCost: ComplexityLevel.low,
    maintenanceCost: ComplexityLevel.medium,
  );

  static const FeatureComplexity _reporting = FeatureComplexity(
    implementation: ComplexityLevel.medium,
    engineering: ComplexityLevel.medium,
    runtime: ComplexityLevel.low,
  );

  static const FeatureComplexity _protection = FeatureComplexity(
    implementation: ComplexityLevel.low,
    engineering: ComplexityLevel.low,
    runtime: ComplexityLevel.low,
  );

  static const FeatureComplexity _credentialStorage = FeatureComplexity(
    implementation: ComplexityLevel.high,
    engineering: ComplexityLevel.high,
    maintenanceCost: ComplexityLevel.high,
    modificationCost: ComplexityLevel.medium,
  );

  static const Set<String> _knownImplementedCapabilities = {
    'clock',
    'notifications',
    'http',
    'ai',
    'knowledge',
    'file',
  };

  FeatureComplexity analyze(FeatureCandidate candidate) {
    switch (candidate.category) {
      case FeatureCategory.data:
      case FeatureCategory.navigation:
      case FeatureCategory.validation:
      case FeatureCategory.state:
        return _low;
      case FeatureCategory.persistence:
        return _persistence;
      case FeatureCategory.relational:
        return _relational;
      case FeatureCategory.indexing:
        return _index;
      case FeatureCategory.search:
        return _search;
      case FeatureCategory.capability:
        final capId = candidate.id.replaceFirst('feature:capability:', '');
        return _knownImplementedCapabilities.contains(capId)
            ? _capabilityKnown
            : _capabilityExperimental;
      case FeatureCategory.permission:
        return _permission;
      case FeatureCategory.offline:
        return _offline;
      case FeatureCategory.reporting:
        return _reporting;
      case FeatureCategory.security:
        return candidate.id == 'feature:security:protection'
            ? _protection
            : _credentialStorage;
    }
  }
}
