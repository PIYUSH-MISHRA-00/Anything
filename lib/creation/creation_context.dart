/// Creation Context — contains everything the CreationEngine needs.
library;

import '../application_engineering/engineering_plan.dart';
import '../core/contracts/intent.dart';
import '../kernel/specification/experience_spec.dart';
import '../kernel/planning/execution_plan.dart';
import '../knowledge/knowledge_bundle.dart';
import '../capabilities/registry/capability_descriptor.dart';
import '../synthesis/app_blueprint.dart';

/// Platform context for creation.
class PlatformContext {
  final String platform;
  final int sdkVersion;
  final bool isDebug;

  const PlatformContext({
    required this.platform,
    required this.sdkVersion,
    this.isDebug = false,
  });
}

/// Security policy for creation.
class CreationSecurityPolicy {
  final List<String> allowedBehaviorNodeTypes;
  final List<String> allowedCapabilityIds;
  final int maxScreens;
  final int maxUiNodes;
  final int maxBehaviorNodes;
  final int maxStateVariables;
  final int maxAssetSizeBytes;
  final int maxTotalPackageSizeBytes;

  const CreationSecurityPolicy({
    this.allowedBehaviorNodeTypes = const [
      'event',
      'condition',
      'stateRead',
      'stateWrite',
      'calculation',
      'validation',
      'transform',
      'branch',
      'capabilityInvocation',
      'serviceInvocation',
      'navigation',
      'dataQuery',
      'dataMutation',
      'errorHandling',
      'return',
    ],
    this.allowedCapabilityIds = const [],
    this.maxScreens = 20,
    this.maxUiNodes = 500,
    this.maxBehaviorNodes = 200,
    this.maxStateVariables = 50,
    this.maxAssetSizeBytes = 5 * 1024 * 1024, // 5MB
    this.maxTotalPackageSizeBytes = 20 * 1024 * 1024, // 20MB
  });
}

/// The complete context for creating an Experience.
class CreationContext {
  final Intent intent;
  final ExperienceSpec specification;
  final ExecutionPlan plan;
  final AppBlueprint? blueprint;

  /// The Application Engineering Engine's output for this creation, if
  /// the Kernel produced one (Vision Milestone V3). When null, behavior/
  /// state are built purely from [blueprint], exactly as before this
  /// milestone — every existing caller that doesn't know about this field
  /// gets identical output to before.
  final EngineeringPlan? engineeringPlan;

  final KnowledgeBundle? knowledgeBundle;
  final List<CapabilityDescriptor> availableCapabilities;
  final PlatformContext platformContext;
  final CreationSecurityPolicy securityPolicy;
  final bool isOffline;
  final Map<String, dynamic> generationMetadata;

  const CreationContext({
    required this.intent,
    required this.specification,
    required this.plan,
    this.blueprint,
    this.engineeringPlan,
    this.knowledgeBundle,
    this.availableCapabilities = const [],
    required this.platformContext,
    required this.securityPolicy,
    // IS-P09: default online. The previous default of `true` rejected every
    // `externalApi` / network experience before generation could run, which
    // surfaced as "Unable to create this type of app" for open-world
    // reference apps. Callers that are genuinely offline pass `true`.
    this.isOffline = false,
    this.generationMetadata = const {},
  });
}
