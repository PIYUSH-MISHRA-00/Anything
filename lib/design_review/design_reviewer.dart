/// Design Reviewer — runs every named sub-reviewer once over a
/// ReviewContext and assembles one ReviewIteration. Mirrors
/// ArchitecturePlanner/EngineeringPlanner's established pattern of
/// orchestrating many small, single-concern sub-modules.
library;

import 'review_context.dart';
import 'review_result.dart';
import 'review_types.dart';
import 'reviewers/accessibility_reviewer.dart';
import 'reviewers/architecture_reviewer.dart';
import 'reviewers/capability_reviewer.dart';
import 'reviewers/consistency_reviewer.dart';
import 'reviewers/dependency_reviewer.dart';
import 'reviewers/engineering_reviewer.dart';
import 'reviewers/migration_modification_reviewer.dart';
import 'reviewers/offline_reviewer.dart';
import 'reviewers/performance_reviewer.dart';
import 'reviewers/runtime_reviewer.dart';
import 'reviewers/security_reviewer.dart';
import 'reviewers/specification_reviewer.dart';

class DesignReviewer {
  final ArchitectureReviewer _architecture;
  final DependencyReviewer _dependency;
  final EngineeringReviewer _engineering;
  final SpecificationReviewer _specification;
  final CapabilityReviewer _capability;
  final SecurityReviewer _security;
  final IntegrityReviewer _integrity;
  final AccessibilityReviewer _accessibility;
  final PerformanceReviewer _performance;
  final MaintainabilityReviewer _maintainability;
  final OfflineReviewer _offline;
  final RuntimeReviewer _runtime;
  final MigrationReviewer _migration;
  final ModificationReviewer _modification;
  final ConsistencyReviewer _consistency;

  const DesignReviewer({
    ArchitectureReviewer architecture = const ArchitectureReviewer(),
    DependencyReviewer dependency = const DependencyReviewer(),
    EngineeringReviewer engineering = const EngineeringReviewer(),
    SpecificationReviewer specification = const SpecificationReviewer(),
    CapabilityReviewer capability = const CapabilityReviewer(),
    SecurityReviewer security = const SecurityReviewer(),
    IntegrityReviewer integrity = const IntegrityReviewer(),
    AccessibilityReviewer accessibility = const AccessibilityReviewer(),
    PerformanceReviewer performance = const PerformanceReviewer(),
    MaintainabilityReviewer maintainability = const MaintainabilityReviewer(),
    OfflineReviewer offline = const OfflineReviewer(),
    RuntimeReviewer runtime = const RuntimeReviewer(),
    MigrationReviewer migration = const MigrationReviewer(),
    ModificationReviewer modification = const ModificationReviewer(),
    ConsistencyReviewer consistency = const ConsistencyReviewer(),
  }) : _architecture = architecture,
       _dependency = dependency,
       _engineering = engineering,
       _specification = specification,
       _capability = capability,
       _security = security,
       _integrity = integrity,
       _accessibility = accessibility,
       _performance = performance,
       _maintainability = maintainability,
       _offline = offline,
       _runtime = runtime,
       _migration = migration,
       _modification = modification,
       _consistency = consistency;

  ReviewIteration review(ReviewContext context, {required int iteration}) {
    final issues = <ReviewIssue>[
      ..._architecture.review(context),
      ..._dependency.review(context),
      ..._engineering.review(context),
      ..._specification.review(context),
      ..._capability.review(context),
      ..._security.review(context),
      ..._integrity.review(context),
      ..._accessibility.review(context),
      ..._performance.review(context),
      ..._offline.review(context),
      ..._runtime.review(context),
      ..._migration.review(context),
      ..._modification.review(context),
      ..._consistency.review(context),
    ];
    issues.addAll(_maintainability.review(context, otherIssueCount: issues.length));

    return ReviewIteration(index: iteration, issues: issues);
  }
}
